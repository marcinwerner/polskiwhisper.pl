// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.IO;
using System.Media;
using Microsoft.Extensions.Logging;
using PolskiWhisperWin.Core.Models;

namespace PolskiWhisperWin.Features.UI;

/// <summary>
/// Odtwarzacz dźwięków systemowych (start/finish nagrywania).
/// Mapping z macOS <c>SoundService</c> - 9 dźwięków, osobno start/finish.
/// </summary>
/// <remarks>
/// Dźwięki są bundled w <c>Assets/Sounds/*.wav</c>. Używamy <see cref="SoundPlayer"/>
/// z System.Media (cross-platform .NET, wystarczające dla krótkich efektów).
/// </remarks>
public sealed class SoundService
{
    private readonly ILogger<SoundService> _logger;

    public SoundService(ILogger<SoundService> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Odtwórz dźwięk asynchronicznie (nie blokuje calling thread).
    /// </summary>
    public void Play(SoundChoice choice)
    {
        if (choice == SoundChoice.None) return;

        var fileName = choice.ToFileName();
        if (fileName is null) return;

        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Assets", "Sounds", fileName);
            if (!File.Exists(path))
            {
                _logger.LogDebug("Plik dźwięku {Path} nie istnieje.", path);
                return;
            }

            using var player = new SoundPlayer(path);
            player.Play();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Nie udało się odtworzyć dźwięku {Choice}.", choice);
        }
    }
}
