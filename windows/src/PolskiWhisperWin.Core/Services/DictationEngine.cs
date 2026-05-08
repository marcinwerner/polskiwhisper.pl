// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using Microsoft.Extensions.Logging;
using PolskiWhisperWin.Core.Models;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// Centralny orchestrator flow nagrywania i transkrypcji.
/// Mapping 1:1 do macOS <c>DictationEngine</c>.
/// </summary>
/// <remarks>
/// <para>Stany przepływu:</para>
/// <list type="number">
///   <item>Idle → user naciska hotkey → StartDictationAsync</item>
///   <item>Idle → Recording (AudioRecorder.StartRecordingAsync)</item>
///   <item>Recording → user naciska hotkey ponownie → StopDictationAsync</item>
///   <item>Recording → Processing (Whisper.TranscribeAsync z timeout 30s)</item>
///   <item>Processing → Pasting (VocabularyProcessor + auto-spacing + PasteService)</item>
///   <item>Pasting → Completed (600ms widget) → Idle</item>
/// </list>
/// <para>Auto-spacing: jeśli ostatnie wklejenie zakończyło się na <c>.!?</c>
/// w oknie 60s, kolejny tekst dostaje wiodącą spację. Mapping z macOS v0.1.2.</para>
/// <para>Cisza detection: jeśli <see cref="AudioRecordingResult.MaxRms"/> &lt; 0.01,
/// transkrypcja jest pomijana (rzucamy <see cref="SilentRecordingException"/>).</para>
/// </remarks>
public sealed class DictationEngine
{
    /// <summary>Próg RMS dla wykrycia ciszy (mapping z macOS v0.1.1).</summary>
    public const double SilenceRmsThreshold = 0.01;

    /// <summary>Hard timeout transkrypcji (mapping z macOS v0.1.5 ADR-028).</summary>
    public static readonly TimeSpan TranscriptionTimeout = TimeSpan.FromSeconds(30);

    /// <summary>Okno czasu (sekundy) dla auto-spacing po terminator (.?!).</summary>
    public static readonly TimeSpan AutoSpacingWindow = TimeSpan.FromSeconds(60);

    /// <summary>Znaki uznawane za zakończenie zdania (auto-spacing trigger).</summary>
    private static readonly char[] SentenceTerminators = ['.', '!', '?'];

    private readonly IAudioRecorder _audioRecorder;
    private readonly IWhisperService _whisperService;
    private readonly IPasteService _pasteService;
    private readonly IVocabularyStore _vocabularyStore;
    private readonly VocabularyProcessor _vocabularyProcessor;
    private readonly WhisperHallucinationFilter _hallucinationFilter;
    private readonly ILogger<DictationEngine> _logger;

    private DateTimeOffset? _lastPasteAt;
    private bool _lastPasteEndedWithTerminator;
    private CancellationTokenSource? _activeCts;
    private readonly SemaphoreSlim _stateLock = new(1, 1);

    /// <summary>Aktualna faza aplikacji - subscribed by FloatingDictationWindow + tray icon.</summary>
    public AppPhase Phase { get; private set; } = AppPhase.Idle;

    /// <summary>Event - faza zmieniona. Subscribed by UI views.</summary>
    public event EventHandler<AppPhase>? PhaseChanged;

    /// <summary>Event - błąd podczas dictation flow. Subscribed by UI views (toast).</summary>
    public event EventHandler<string>? ErrorOccurred;

    public DictationEngine(
        IAudioRecorder audioRecorder,
        IWhisperService whisperService,
        IPasteService pasteService,
        IVocabularyStore vocabularyStore,
        VocabularyProcessor vocabularyProcessor,
        WhisperHallucinationFilter hallucinationFilter,
        ILogger<DictationEngine> logger)
    {
        _audioRecorder = audioRecorder;
        _whisperService = whisperService;
        _pasteService = pasteService;
        _vocabularyStore = vocabularyStore;
        _vocabularyProcessor = vocabularyProcessor;
        _hallucinationFilter = hallucinationFilter;
        _logger = logger;
    }

    /// <summary>
    /// Rozpocznij nagrywanie. Idempotent: jeśli już nagrywamy, no-op.
    /// </summary>
    public async Task StartDictationAsync(CancellationToken cancellationToken = default)
    {
        await _stateLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (Phase is AppPhase.Recording or AppPhase.Processing or AppPhase.Pasting)
            {
                _logger.LogDebug("StartDictationAsync ignorowane - aktualna faza {Phase}.", Phase);
                return;
            }

            _activeCts?.Dispose();
            _activeCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);

            await _audioRecorder.StartRecordingAsync(_activeCts.Token).ConfigureAwait(false);
            SetPhase(AppPhase.Recording);
        }
        finally
        {
            _stateLock.Release();
        }
    }

    /// <summary>
    /// Zatrzymaj nagrywanie i wykonaj transkrypcję. Idempotent.
    /// </summary>
    public async Task StopDictationAsync(CancellationToken cancellationToken = default)
    {
        AudioRecordingResult? recording;

        await _stateLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (Phase != AppPhase.Recording) return;

            recording = await _audioRecorder.StopRecordingAsync(cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _stateLock.Release();
        }

        if (recording is null)
        {
            SetPhase(AppPhase.Idle);
            return;
        }

        try
        {
            await ProcessRecordingAsync(recording, cancellationToken).ConfigureAwait(false);
        }
        catch (SilentRecordingException ex)
        {
            _logger.LogInformation("Pominięto transkrypcję - cisza ({MaxRms}).", ex.MaxRms);
            _audioRecorder.CleanupRecording(recording.WavFilePath);
            SetPhase(AppPhase.Idle);
        }
        catch (TranscriptionTimeoutException ex)
        {
            _logger.LogWarning(ex, "Whisper przekroczył timeout.");
            ErrorOccurred?.Invoke(this, "Transkrypcja przekroczyła limit 30 sekund. Spróbuj krótszego nagrania.");
            _audioRecorder.CleanupRecording(recording.WavFilePath);
            SetPhase(AppPhase.Error);
            await Task.Delay(2000, cancellationToken).ConfigureAwait(false);
            SetPhase(AppPhase.Idle);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Błąd podczas dictation flow.");
            ErrorOccurred?.Invoke(this, $"Coś poszło nie tak: {ex.Message}");
            _audioRecorder.CleanupRecording(recording.WavFilePath);
            SetPhase(AppPhase.Error);
            await Task.Delay(2000, cancellationToken).ConfigureAwait(false);
            SetPhase(AppPhase.Idle);
        }
    }

    /// <summary>
    /// Anuluj aktualne nagrywanie (ESC). Nic nie wkleja, czyści temp WAV.
    /// </summary>
    public async Task CancelDictationAsync()
    {
        await _stateLock.WaitAsync().ConfigureAwait(false);
        try
        {
            if (Phase != AppPhase.Recording) return;

            var result = await _audioRecorder.StopRecordingAsync().ConfigureAwait(false);
            if (result is not null) _audioRecorder.CleanupRecording(result.WavFilePath);

            _activeCts?.Cancel();
            SetPhase(AppPhase.Idle);
            _logger.LogInformation("Nagrywanie anulowane przez user (ESC).");
        }
        finally
        {
            _stateLock.Release();
        }
    }

    private async Task ProcessRecordingAsync(AudioRecordingResult recording, CancellationToken cancellationToken)
    {
        // Cisza detection - jeśli maxRMS < 0.01, pomijamy transkrypcję.
        if (recording.MaxRms < SilenceRmsThreshold)
        {
            throw new SilentRecordingException(recording.MaxRms);
        }

        SetPhase(AppPhase.Processing);

        // Whisper transcribe (z timeout 30s).
        var rawText = await _whisperService.TranscribeAsync(
            recording.WavFilePath,
            TranscriptionTimeout,
            cancellationToken).ConfigureAwait(false);

        // Hallucination filter.
        if (_hallucinationFilter.IsLikelyHallucination(rawText))
        {
            _logger.LogInformation("Hallucination filter odrzucił tekst: '{Text}'.", rawText);
            _audioRecorder.CleanupRecording(recording.WavFilePath);
            SetPhase(AppPhase.Idle);
            return;
        }

        // Vocabulary processing (Find & Replace).
        var rules = await _vocabularyStore.GetAllRulesAsync(cancellationToken).ConfigureAwait(false);
        var processedText = _vocabularyProcessor.Apply(rawText, rules);

        // Auto-spacing: jeśli ostatnie wklejenie kończyło się na .!? w oknie 60s.
        processedText = ApplyAutoSpacing(processedText);

        if (string.IsNullOrWhiteSpace(processedText))
        {
            _logger.LogWarning("Po vocabulary processing tekst jest pusty. Pomijam wklejanie.");
            _audioRecorder.CleanupRecording(recording.WavFilePath);
            SetPhase(AppPhase.Idle);
            return;
        }

        // Paste.
        SetPhase(AppPhase.Pasting);
        await _pasteService.PasteAsync(processedText, simulateKeystroke: true).ConfigureAwait(false);

        UpdatePasteState(processedText);
        _audioRecorder.CleanupRecording(recording.WavFilePath);

        SetPhase(AppPhase.Completed);
        await Task.Delay(600, cancellationToken).ConfigureAwait(false);
        SetPhase(AppPhase.Idle);
    }

    /// <summary>
    /// Auto-spacing logic: jeśli ostatnie wklejenie zakończyło się na .!? w oknie 60s,
    /// dopisz spację z przodu. Mapping z macOS v0.1.2.
    /// </summary>
    internal string ApplyAutoSpacing(string input)
    {
        if (string.IsNullOrEmpty(input)) return input;

        if (_lastPasteAt is null) return input;
        if (DateTimeOffset.UtcNow - _lastPasteAt.Value > AutoSpacingWindow) return input;
        if (!_lastPasteEndedWithTerminator) return input;
        if (char.IsWhiteSpace(input[0])) return input;

        return " " + input;
    }

    private void UpdatePasteState(string pastedText)
    {
        _lastPasteAt = DateTimeOffset.UtcNow;
        var trimmed = pastedText.TrimEnd();
        _lastPasteEndedWithTerminator = trimmed.Length > 0
            && SentenceTerminators.Contains(trimmed[^1]);
    }

    private void SetPhase(AppPhase newPhase)
    {
        if (Phase == newPhase) return;

        var previousPhase = Phase;
        Phase = newPhase;
        _logger.LogDebug("Faza zmieniona: {Previous} → {New}.", previousPhase, newPhase);
        PhaseChanged?.Invoke(this, newPhase);
    }
}
