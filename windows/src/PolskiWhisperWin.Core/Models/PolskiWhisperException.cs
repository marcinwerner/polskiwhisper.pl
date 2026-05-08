// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

namespace PolskiWhisperWin.Core.Models;

/// <summary>
/// Bazowa klasa wyjątków aplikacji - łatwo łapać <c>catch (PolskiWhisperException)</c>
/// zamiast generic Exception.
/// </summary>
public abstract class PolskiWhisperException : Exception
{
    protected PolskiWhisperException(string message) : base(message) { }
    protected PolskiWhisperException(string message, Exception innerException) : base(message, innerException) { }
}

/// <summary>Whisper nie zdążył w 30 sekund - timeout dla transkrypcji.</summary>
public sealed class TranscriptionTimeoutException : PolskiWhisperException
{
    public int TimeoutSeconds { get; }

    public TranscriptionTimeoutException(int timeoutSeconds)
        : base($"Transkrypcja przekroczyła limit czasu {timeoutSeconds} sekund.")
    {
        TimeoutSeconds = timeoutSeconds;
    }
}

/// <summary>Whisper zwrócił pusty wynik mimo że audio nie było ciszą.</summary>
public sealed class EmptyTranscriptionException : PolskiWhisperException
{
    public EmptyTranscriptionException()
        : base("Whisper zwrócił pusty wynik. Możliwe że audio jest niewyraźne lub bardzo krótkie.")
    {
    }
}

/// <summary>Plik modelu Whisper nie istnieje na dysku.</summary>
public sealed class WhisperModelNotFoundException : PolskiWhisperException
{
    public string ExpectedPath { get; }

    public WhisperModelNotFoundException(string expectedPath)
        : base($"Model Whisper nie został znaleziony pod ścieżką: {expectedPath}")
    {
        ExpectedPath = expectedPath;
    }
}

/// <summary>Audio jest "ciszą" - maxRMS poniżej progu, transkrypcja pominięta.</summary>
public sealed class SilentRecordingException : PolskiWhisperException
{
    public double MaxRms { get; }

    public SilentRecordingException(double maxRms)
        : base($"Nagranie jest zbyt ciche (maxRMS={maxRms:F4}). Pomijam transkrypcję.")
    {
        MaxRms = maxRms;
    }
}

/// <summary>Konflikt audio - inna aplikacja używa mikrofonu lub urządzenie odłączone.</summary>
public sealed class AudioCaptureException : PolskiWhisperException
{
    public AudioCaptureException(string message) : base(message) { }
    public AudioCaptureException(string message, Exception inner) : base(message, inner) { }
}
