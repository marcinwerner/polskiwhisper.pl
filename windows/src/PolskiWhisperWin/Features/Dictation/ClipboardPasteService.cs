// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using PolskiWhisperWin.Core.Services;
using TextCopy;
using WindowsInput;
using WindowsInput.Native;

namespace PolskiWhisperWin.Features.Dictation;

/// <summary>
/// Implementacja <see cref="IPasteService"/> używająca TextCopy (clipboard) + InputSimulator (Ctrl+V).
/// </summary>
public sealed class ClipboardPasteService : IPasteService
{
    private readonly ILogger<ClipboardPasteService> _logger;
    private readonly IInputSimulator _inputSimulator;

    public ClipboardPasteService(ILogger<ClipboardPasteService> logger)
    {
        _logger = logger;
        _inputSimulator = new InputSimulator();
    }

    /// <inheritdoc/>
    public async Task PasteAsync(string text, bool simulateKeystroke = true)
    {
        if (string.IsNullOrEmpty(text))
        {
            _logger.LogDebug("PasteAsync: pusty tekst, pomijam.");
            return;
        }

        try
        {
            // 1) Set clipboard (TextCopy używa Win32 OpenClipboard / SetClipboardData).
            await ClipboardService.SetTextAsync(text).ConfigureAwait(false);
            _logger.LogDebug("Clipboard ustawiony ({Length} znaków).", text.Length);

            if (!simulateKeystroke)
            {
                _logger.LogDebug("simulateKeystroke == false, kończę bez Ctrl+V.");
                return;
            }

            // 2) Symuluj Ctrl+V.
            // Małe opóźnienie aby system zdążył przetworzyć clipboard set.
            await Task.Delay(40).ConfigureAwait(false);
            _inputSimulator.Keyboard.ModifiedKeyStroke(VirtualKeyCode.CONTROL, VirtualKeyCode.VK_V);

            _logger.LogInformation("Wklejono {Length} znaków do aktywnego okna.", text.Length);
        }
        catch (System.Exception ex)
        {
            _logger.LogError(ex, "PasteAsync nieudane.");
            throw;
        }
    }
}
