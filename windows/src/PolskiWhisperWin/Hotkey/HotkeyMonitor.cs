// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using SharpHook;
using SharpHook.Native;

namespace PolskiWhisperWin.Hotkey;

/// <summary>
/// Globalny monitor klawiatury - emituje event-y dla hotkey + ESC.
/// Używa SharpHook (low-level keyboard hook, działa nawet gdy aplikacja nie ma fokusa).
/// </summary>
/// <remarks>
/// <para>Wykrywa "tap" (krótki press &lt; 250ms) vs "hold". Mapping z macOS <c>ModifierKeyMonitor</c>
/// dla Left Option toggle.</para>
/// <para>ESC jest emitowany tylko podczas .Recording phase - inaczej ignorowany.</para>
/// </remarks>
public sealed class HotkeyMonitor : IDisposable
{
    /// <summary>Maksymalny czas dla "tap" detection - dłuższy press = "hold".</summary>
    private static readonly TimeSpan TapMaxDuration = TimeSpan.FromMilliseconds(250);

    private readonly ILogger<HotkeyMonitor> _logger;
    private readonly object _stateLock = new();

    private TaskPoolGlobalHook? _hook;
    private int _hotkeyVirtualKeyCode = 0xA3; // Right Ctrl default.
    private DateTimeOffset? _hotkeyPressedAt;
    private bool _hotkeyHoldEmitted;
    private CancellationTokenSource? _runCts;

    /// <summary>Czy hotkey nasłuch jest aktywny (po StartAsync).</summary>
    public bool IsRunning { get; private set; }

    /// <summary>Event: krótki tap hotkey (toggle mode).</summary>
    public event EventHandler? HotkeyTapped;

    /// <summary>Event: hotkey trzymany - rozpocznij nagrywanie (push-to-talk).</summary>
    public event EventHandler? HotkeyHoldStart;

    /// <summary>Event: hotkey puszczony po hold - zakończ nagrywanie (push-to-talk).</summary>
    public event EventHandler? HotkeyHoldEnd;

    /// <summary>Event: ESC. Subscriberzy decydują czy reagować (zwykle: tylko .Recording).</summary>
    public event EventHandler? EscapePressed;

    public HotkeyMonitor(ILogger<HotkeyMonitor> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Rozpocznij nasłuchiwanie. <paramref name="virtualKeyCode"/> to Win32 VK code (np. 0xA3 dla Right Ctrl).
    /// </summary>
    public async Task StartAsync(int virtualKeyCode)
    {
        lock (_stateLock)
        {
            if (IsRunning)
            {
                _logger.LogWarning("HotkeyMonitor.StartAsync wywołane gdy już running. Restart.");
                StopInternal();
            }

            _hotkeyVirtualKeyCode = virtualKeyCode;
            _runCts = new CancellationTokenSource();
            _hook = new TaskPoolGlobalHook();
            _hook.KeyPressed += OnKeyPressed;
            _hook.KeyReleased += OnKeyReleased;

            IsRunning = true;
            _logger.LogInformation("HotkeyMonitor wystartowany (VK 0x{VkCode:X2}).", virtualKeyCode);
        }

        try
        {
            await _hook!.RunAsync().ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "HotkeyMonitor.RunAsync zakończony błędem.");
        }
    }

    /// <summary>
    /// Zmień hotkey w runtime (po user save w Settings).
    /// </summary>
    public void ChangeHotkey(int newVirtualKeyCode)
    {
        lock (_stateLock)
        {
            _hotkeyVirtualKeyCode = newVirtualKeyCode;
            _logger.LogInformation("Hotkey zmieniony na VK 0x{VkCode:X2}.", newVirtualKeyCode);
        }
    }

    /// <summary>
    /// Stop hotkey monitor. Idempotent.
    /// </summary>
    public void Stop()
    {
        lock (_stateLock)
        {
            StopInternal();
        }
    }

    private void StopInternal()
    {
        if (!IsRunning) return;

        try
        {
            _runCts?.Cancel();
            _hook?.Dispose();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Błąd podczas stop HotkeyMonitor.");
        }
        finally
        {
            _hook = null;
            _runCts?.Dispose();
            _runCts = null;
            IsRunning = false;
        }
    }

    private void OnKeyPressed(object? sender, KeyboardHookEventArgs e)
    {
        // ESC
        if (e.Data.KeyCode == KeyCode.VcEscape)
        {
            EscapePressed?.Invoke(this, EventArgs.Empty);
            return;
        }

        // Hotkey down.
        if (MatchesHotkey(e.Data.KeyCode))
        {
            // Drugi raz pressed (autorepeat) - ignoruj.
            if (_hotkeyPressedAt is not null) return;

            _hotkeyPressedAt = DateTimeOffset.UtcNow;
            _hotkeyHoldEmitted = false;

            // Po 250ms (jeśli klawisz wciąż wciśnięty), emituj HoldStart.
            // Detekcja przez timer.
            _ = Task.Delay(TapMaxDuration).ContinueWith(_ =>
            {
                if (_hotkeyPressedAt is not null && !_hotkeyHoldEmitted)
                {
                    _hotkeyHoldEmitted = true;
                    HotkeyHoldStart?.Invoke(this, EventArgs.Empty);
                }
            }, TaskScheduler.Default);
        }
    }

    private void OnKeyReleased(object? sender, KeyboardHookEventArgs e)
    {
        if (!MatchesHotkey(e.Data.KeyCode)) return;

        var pressedAt = _hotkeyPressedAt;
        _hotkeyPressedAt = null;

        if (pressedAt is null) return;

        var heldFor = DateTimeOffset.UtcNow - pressedAt.Value;

        if (_hotkeyHoldEmitted)
        {
            HotkeyHoldEnd?.Invoke(this, EventArgs.Empty);
        }
        else if (heldFor <= TapMaxDuration)
        {
            HotkeyTapped?.Invoke(this, EventArgs.Empty);
        }

        _hotkeyHoldEmitted = false;
    }

    /// <summary>
    /// Sprawdza czy SharpHook KeyCode dopasowuje VK code.
    /// SharpHook ma swoje enum-y, mapping przez <see cref="MapVkToSharpHookKeyCode"/>.
    /// </summary>
    private bool MatchesHotkey(KeyCode pressed)
    {
        return pressed == MapVkToSharpHookKeyCode(_hotkeyVirtualKeyCode);
    }

    /// <summary>
    /// Mapowanie Win32 VK → SharpHook KeyCode dla popularnych klawiszy.
    /// </summary>
    private static KeyCode MapVkToSharpHookKeyCode(int vk) => vk switch
    {
        0xA0 => KeyCode.VcLeftShift,        // VK_LSHIFT
        0xA1 => KeyCode.VcRightShift,       // VK_RSHIFT
        0xA2 => KeyCode.VcLeftControl,      // VK_LCONTROL
        0xA3 => KeyCode.VcRightControl,     // VK_RCONTROL (default)
        0xA4 => KeyCode.VcLeftAlt,          // VK_LMENU
        0xA5 => KeyCode.VcRightAlt,         // VK_RMENU
        0x14 => KeyCode.VcCapsLock,         // VK_CAPITAL
        0x90 => KeyCode.VcNumLock,          // VK_NUMLOCK
        0x91 => KeyCode.VcScrollLock,       // VK_SCROLL
        0x70 => KeyCode.VcF1,               // VK_F1
        0x71 => KeyCode.VcF2,
        0x72 => KeyCode.VcF3,
        0x73 => KeyCode.VcF4,
        0x74 => KeyCode.VcF5,
        0x75 => KeyCode.VcF6,
        0x76 => KeyCode.VcF7,
        0x77 => KeyCode.VcF8,
        0x78 => KeyCode.VcF9,
        0x79 => KeyCode.VcF10,
        0x7A => KeyCode.VcF11,
        0x7B => KeyCode.VcF12,
        _ => KeyCode.VcRightControl
    };

    public void Dispose() => Stop();
}
