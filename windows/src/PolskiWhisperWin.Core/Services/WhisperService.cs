// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using Microsoft.Extensions.Logging;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Utilities;
using Whisper.net;
using Whisper.net.Ggml;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Implementacja <see cref="IWhisperService"/> używająca Whisper.net (binding do whisper.cpp).
/// </summary>
/// <remarks>
/// <para>Krytyczny punkt: timeout pattern. Mapping z macOS ADR-028: stary kod używał
/// <c>withThrowingTaskGroup</c> który czekał na cancelled child task → app hangował.
/// W C# odpowiednik to <c>Task.WhenAny</c> ale TEŻ czeka na background task aby się skończył,
/// chyba że odsiniemy się przez <c>CancellationTokenSource</c> z <c>CancelAfter</c>.</para>
/// <para>Nasz pattern: <c>CancellationTokenSource.CreateLinkedTokenSource(token, timeoutToken)</c>
/// + Whisper.net używa <see cref="CancellationToken"/> aby przerwać dekodowanie. Jeśli to nie
/// zadziała (whisper.cpp czasem ignoruje cancel), <c>Task.WhenAny</c> z <c>Task.Delay</c> daje
/// pierwszy wynik (timeout) i background task continues w tle - akceptujemy to (file handle
/// jest disposed osobno).</para>
/// </remarks>
public sealed class WhisperService : IWhisperService
{
    private readonly IAppPaths _paths;
    private readonly ILogger<WhisperService> _logger;
    private readonly HttpClient _httpClient;

    private WhisperFactory? _factory;
    private WhisperProcessor? _processor;
    private string? _loadedModelId;
    private readonly SemaphoreSlim _stateLock = new(1, 1);

    public WhisperLoadStatus LoadStatus { get; private set; } = WhisperLoadStatus.NotLoaded;

    public WhisperService(IAppPaths paths, ILogger<WhisperService> logger, HttpClient? httpClient = null)
    {
        _paths = paths;
        _logger = logger;
        _httpClient = httpClient ?? new HttpClient();
        _httpClient.Timeout = TimeSpan.FromMinutes(20); // duże modele 1.5-3 GB
    }

    /// <inheritdoc/>
    public async Task LoadModelAsync(
        string modelIdentifier,
        IProgress<WhisperLoadProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        await _stateLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_loadedModelId == modelIdentifier && LoadStatus == WhisperLoadStatus.Ready)
            {
                _logger.LogDebug("Model {ModelId} jest już załadowany.", modelIdentifier);
                return;
            }

            await UnloadInternalAsync().ConfigureAwait(false);

            var modelInfo = WhisperModelInfo.FindOrDefault(modelIdentifier);
            var modelPath = Path.Combine(_paths.ModelsDirectory, $"{modelInfo.Identifier}.bin");

            // Faza 1: Download (jeśli plik nie istnieje).
            if (!File.Exists(modelPath))
            {
                LoadStatus = WhisperLoadStatus.Downloading;
                progress?.Report(new WhisperLoadProgress(0.0, 0, modelInfo.ApproximateSizeBytes,
                    $"Pobieram model {modelInfo.DisplayName}..."));

                await DownloadModelAsync(modelInfo, modelPath, progress, cancellationToken).ConfigureAwait(false);
            }
            else
            {
                _logger.LogInformation("Model {ModelId} już istnieje na dysku.", modelIdentifier);
            }

            // Faza 2: Load do RAM.
            LoadStatus = WhisperLoadStatus.LoadingToMemory;
            progress?.Report(new WhisperLoadProgress(0.95, modelInfo.ApproximateSizeBytes, modelInfo.ApproximateSizeBytes,
                "Ładuję model do pamięci..."));

            _factory = WhisperFactory.FromPath(modelPath);
            _processor = _factory.CreateBuilder()
                .WithLanguage("pl")
                .WithThreads(Math.Min(Environment.ProcessorCount, 8))
                .Build();

            _loadedModelId = modelIdentifier;
            LoadStatus = WhisperLoadStatus.Ready;

            progress?.Report(new WhisperLoadProgress(1.0, modelInfo.ApproximateSizeBytes, modelInfo.ApproximateSizeBytes,
                "Model gotowy."));

            _logger.LogInformation("Model {ModelId} załadowany pomyślnie.", modelIdentifier);
        }
        catch (Exception ex)
        {
            LoadStatus = WhisperLoadStatus.Failed;
            _logger.LogError(ex, "Nie udało się załadować modelu {ModelId}.", modelIdentifier);
            throw;
        }
        finally
        {
            _stateLock.Release();
        }
    }

    /// <inheritdoc/>
    public async Task<string> TranscribeAsync(
        string wavFilePath,
        TimeSpan timeout,
        CancellationToken cancellationToken = default)
    {
        if (_processor is null)
            throw new InvalidOperationException("WhisperService nie jest załadowany. Wywołaj LoadModelAsync najpierw.");

        if (!File.Exists(wavFilePath))
            throw new FileNotFoundException("Nagrane WAV nie istnieje.", wavFilePath);

        // Linked token: user cancellation + timeout. Pozwala Whisper.net wyjść early.
        using var timeoutCts = new CancellationTokenSource(timeout);
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeoutCts.Token);

        try
        {
            var transcribeTask = TranscribeInternalAsync(wavFilePath, linkedCts.Token);
            var timeoutTask = Task.Delay(timeout, cancellationToken);

            // First-wins: jeśli timeout wygra, rzucamy TranscriptionTimeoutException
            // i NIE czekamy na cancelled task (background continues but is detached).
            var winner = await Task.WhenAny(transcribeTask, timeoutTask).ConfigureAwait(false);

            if (winner == timeoutTask && !transcribeTask.IsCompleted)
            {
                _logger.LogWarning("Whisper transkrypcja przekroczyła {TimeoutSec}s. Rzucam timeout.", timeout.TotalSeconds);

                // Ulepsza: timeoutCts.Cancel() już został wywołany. Detach task aby uniknąć GC pressure.
                _ = transcribeTask.ContinueWith(t =>
                {
                    if (t.IsFaulted)
                        _logger.LogDebug(t.Exception, "Background transcribe task failed po timeout (oczekiwane).");
                }, TaskScheduler.Default);

                throw new TranscriptionTimeoutException((int)timeout.TotalSeconds);
            }

            return await transcribeTask.ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)
        {
            throw new TranscriptionTimeoutException((int)timeout.TotalSeconds);
        }
    }

    private async Task<string> TranscribeInternalAsync(string wavFilePath, CancellationToken cancellationToken)
    {
        if (_processor is null)
            throw new InvalidOperationException("Processor null - load failed.");

        await using var fileStream = File.OpenRead(wavFilePath);
        var segments = new List<string>();

        await foreach (var segment in _processor.ProcessAsync(fileStream, cancellationToken).ConfigureAwait(false))
        {
            segments.Add(segment.Text.Trim());
        }

        return string.Join(" ", segments).Trim();
    }

    private async Task DownloadModelAsync(
        WhisperModelInfo modelInfo,
        string targetPath,
        IProgress<WhisperLoadProgress>? progress,
        CancellationToken cancellationToken)
    {
        // Whisper.net ma helper do pobrania ggml modeli, ale używa swoich URL-i.
        // Robimy własny download dla większej kontroli nad progress.

        var tempPath = targetPath + ".part";
        if (File.Exists(tempPath)) File.Delete(tempPath);

        using var response = await _httpClient.GetAsync(modelInfo.DownloadUrl, HttpCompletionOption.ResponseHeadersRead, cancellationToken)
            .ConfigureAwait(false);
        response.EnsureSuccessStatusCode();

        var totalBytes = response.Content.Headers.ContentLength ?? modelInfo.ApproximateSizeBytes;

        await using (var contentStream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false))
        await using (var fileStream = File.Create(tempPath))
        {
            const int bufferSize = 81920;
            var buffer = new byte[bufferSize];
            long totalRead = 0;
            int read;
            var lastReportedAt = DateTimeOffset.UtcNow;

            while ((read = await contentStream.ReadAsync(buffer.AsMemory(0, bufferSize), cancellationToken).ConfigureAwait(false)) > 0)
            {
                await fileStream.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
                totalRead += read;

                if (DateTimeOffset.UtcNow - lastReportedAt > TimeSpan.FromMilliseconds(250))
                {
                    var progressFraction = totalBytes > 0 ? (double)totalRead / totalBytes : 0;
                    // Reserve last 5% dla loading do RAM.
                    var loadProgress = Math.Min(0.95, progressFraction * 0.95);
                    progress?.Report(new WhisperLoadProgress(
                        loadProgress,
                        totalRead,
                        totalBytes,
                        $"Pobieram model {modelInfo.DisplayName}... {(loadProgress * 100):F0}%"));
                    lastReportedAt = DateTimeOffset.UtcNow;
                }
            }
        }

        File.Move(tempPath, targetPath, overwrite: true);
        _logger.LogInformation("Model {ModelId} pobrany do {Path}.", modelInfo.Identifier, targetPath);
    }

    /// <inheritdoc/>
    public async Task UnloadAsync()
    {
        await _stateLock.WaitAsync().ConfigureAwait(false);
        try
        {
            await UnloadInternalAsync().ConfigureAwait(false);
        }
        finally
        {
            _stateLock.Release();
        }
    }

    private async Task UnloadInternalAsync()
    {
        if (_processor is not null)
        {
            await _processor.DisposeAsync().ConfigureAwait(false);
            _processor = null;
        }

        _factory?.Dispose();
        _factory = null;
        _loadedModelId = null;
        LoadStatus = WhisperLoadStatus.NotLoaded;
    }

    public async ValueTask DisposeAsync()
    {
        await UnloadAsync().ConfigureAwait(false);
        _httpClient.Dispose();
        _stateLock.Dispose();
    }
}
