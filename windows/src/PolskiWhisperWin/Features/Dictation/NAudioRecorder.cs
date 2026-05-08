// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using NAudio.CoreAudioApi;
using NAudio.Wave;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;
using PolskiWhisperWin.Core.Utilities;

namespace PolskiWhisperWin.Features.Dictation;

/// <summary>
/// Implementacja <see cref="IAudioRecorder"/> używająca NAudio + WASAPI.
/// Nagrywa 16kHz mono PCM (format wymagany przez Whisper).
/// </summary>
public sealed class NAudioRecorder : IAudioRecorder
{
    /// <summary>Whisper wymaga 16 kHz mono PCM.</summary>
    private const int SampleRate = 16_000;
    private const int Channels = 1;
    private const int BitsPerSample = 16;

    private readonly IAppPaths _paths;
    private readonly ILogger<NAudioRecorder> _logger;
    private readonly object _stateLock = new();

    private WaveInEvent? _waveIn;
    private WaveFileWriter? _writer;
    private string? _currentWavPath;
    private DateTimeOffset _recordingStartedAt;
    private double _maxRms;
    private double _currentRms;

    public NAudioRecorder(IAppPaths paths, ILogger<NAudioRecorder> logger)
    {
        _paths = paths;
        _logger = logger;
    }

    /// <inheritdoc/>
    public bool IsRecording { get; private set; }

    /// <inheritdoc/>
    public double CurrentRms => _currentRms;

    /// <inheritdoc/>
    public event EventHandler<double>? RmsLevelChanged;

    /// <inheritdoc/>
    public Task StartRecordingAsync(CancellationToken cancellationToken = default)
    {
        lock (_stateLock)
        {
            if (IsRecording)
            {
                _logger.LogWarning("StartRecordingAsync wywołane gdy IsRecording == true. Pomijam.");
                return Task.CompletedTask;
            }

            try
            {
                _paths.EnsureDirectoriesExist();
                var wavName = $"rec-{DateTime.UtcNow:yyyyMMdd-HHmmss-fff}.wav";
                _currentWavPath = Path.Combine(_paths.TempAudioDirectory, wavName);

                _waveIn = new WaveInEvent
                {
                    WaveFormat = new WaveFormat(SampleRate, BitsPerSample, Channels),
                    BufferMilliseconds = 50,
                    DeviceNumber = 0  // Default device.
                };

                _writer = new WaveFileWriter(_currentWavPath, _waveIn.WaveFormat);
                _waveIn.DataAvailable += OnDataAvailable;
                _waveIn.RecordingStopped += OnRecordingStopped;

                _maxRms = 0;
                _currentRms = 0;
                _recordingStartedAt = DateTimeOffset.UtcNow;
                _waveIn.StartRecording();

                IsRecording = true;
                _logger.LogInformation("Rozpoczęto nagrywanie do {Path}.", _currentWavPath);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się rozpocząć nagrywania.");
                CleanupResources();
                throw new AudioCaptureException("Nie udało się uzyskać dostępu do mikrofonu. Sprawdź uprawnienia w Ustawieniach Windows.", ex);
            }
        }

        return Task.CompletedTask;
    }

    /// <inheritdoc/>
    public Task<AudioRecordingResult?> StopRecordingAsync(CancellationToken cancellationToken = default)
    {
        WaveInEvent? localWaveIn;
        WaveFileWriter? localWriter;
        string? localPath;
        double maxRms;
        DateTimeOffset startedAt;

        lock (_stateLock)
        {
            if (!IsRecording || _waveIn is null || _writer is null || _currentWavPath is null)
            {
                _logger.LogDebug("StopRecordingAsync wywołane gdy IsRecording == false. Zwracam null.");
                return Task.FromResult<AudioRecordingResult?>(null);
            }

            localWaveIn = _waveIn;
            localWriter = _writer;
            localPath = _currentWavPath;
            maxRms = _maxRms;
            startedAt = _recordingStartedAt;

            IsRecording = false;
            _waveIn = null;
            _writer = null;
            _currentWavPath = null;
        }

        try
        {
            localWaveIn.StopRecording();
            localWaveIn.Dispose();
            localWriter.Dispose();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Wyjątek podczas stop recording (kontynuuję).");
        }

        var duration = (DateTimeOffset.UtcNow - startedAt).TotalSeconds;
        var result = new AudioRecordingResult(localPath, duration, maxRms);
        _logger.LogInformation("Zakończono nagrywanie. Długość: {Duration}s, MaxRMS: {MaxRms:F4}.", duration, maxRms);

        return Task.FromResult<AudioRecordingResult?>(result);
    }

    /// <inheritdoc/>
    public void CleanupRecording(string wavFilePath)
    {
        try
        {
            if (File.Exists(wavFilePath))
            {
                File.Delete(wavFilePath);
                _logger.LogDebug("Usunięto temp audio {Path}.", wavFilePath);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Nie udało się usunąć temp audio {Path}.", wavFilePath);
        }
    }

    /// <inheritdoc/>
    public IReadOnlyList<AudioDeviceInfo> GetAvailableMicrophones()
    {
        var devices = new List<AudioDeviceInfo>();

        try
        {
            // Default device id.
            using var enumerator = new MMDeviceEnumerator();
            string? defaultDeviceId = null;

            try
            {
                var defaultDevice = enumerator.GetDefaultAudioEndpoint(DataFlow.Capture, Role.Communications);
                defaultDeviceId = defaultDevice?.ID;
            }
            catch
            {
                // No default device - acceptable.
            }

            for (int i = 0; i < WaveInEvent.DeviceCount; i++)
            {
                var caps = WaveInEvent.GetCapabilities(i);
                devices.Add(new AudioDeviceInfo(
                    Id: i.ToString(),
                    DisplayName: caps.ProductName,
                    IsDefault: i == 0));
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Nie udało się odczytać listy mikrofonów.");
        }

        return devices;
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs e)
    {
        try
        {
            _writer?.Write(e.Buffer, 0, e.BytesRecorded);

            // RMS calculation - dla waveform UI + silence detection.
            var rms = CalculateRms(e.Buffer, e.BytesRecorded);
            _currentRms = rms;
            if (rms > _maxRms) _maxRms = rms;

            RmsLevelChanged?.Invoke(this, rms);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Błąd w OnDataAvailable.");
        }
    }

    private void OnRecordingStopped(object? sender, StoppedEventArgs e)
    {
        if (e.Exception is not null)
        {
            _logger.LogError(e.Exception, "Recording stopped due to exception.");
        }
    }

    /// <summary>
    /// RMS dla 16-bit PCM. Zwraca wartość 0..1.
    /// </summary>
    private static double CalculateRms(byte[] buffer, int bytesRecorded)
    {
        if (bytesRecorded < 2) return 0;

        long sumSquares = 0;
        int sampleCount = 0;

        // 16-bit PCM = 2 bajty per sample, little-endian.
        for (int i = 0; i + 1 < bytesRecorded; i += 2)
        {
            var sample = (short)(buffer[i] | (buffer[i + 1] << 8));
            sumSquares += sample * sample;
            sampleCount++;
        }

        if (sampleCount == 0) return 0;
        var meanSquare = (double)sumSquares / sampleCount;
        var rms = Math.Sqrt(meanSquare);

        // Normalizacja 0..1 (max short value = 32767).
        return rms / 32767.0;
    }

    private void CleanupResources()
    {
        _waveIn?.Dispose();
        _waveIn = null;
        _writer?.Dispose();
        _writer = null;
        _currentWavPath = null;
        IsRecording = false;
    }

    public void Dispose()
    {
        lock (_stateLock)
        {
            if (IsRecording)
            {
                try { _waveIn?.StopRecording(); } catch { /* ignore */ }
            }
            CleanupResources();
        }
    }
}
