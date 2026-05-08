// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using Microsoft.Extensions.Logging;
using Microsoft.Toolkit.Uwp.Notifications;
using PolskiWhisperWin.Core.Models;

namespace PolskiWhisperWin.Features.Updates;

/// <summary>
/// Wysyła Toast notifications. Mapping z macOS <c>NotificationDispatcher</c> (UNUserNotificationCenter).
/// Używa Microsoft.Toolkit.Uwp.Notifications - działa w unpackaged WinUI 3 apps.
/// </summary>
public sealed class NotificationDispatcher
{
    private readonly ILogger<NotificationDispatcher> _logger;

    public NotificationDispatcher(ILogger<NotificationDispatcher> logger)
    {
        _logger = logger;
        ToastNotificationManagerCompat.OnActivated += OnToastActivated;
    }

    /// <summary>
    /// Toast "Dostępna jest nowa wersja PolskiWhisper" + przycisk "Pokaż w aplikacji".
    /// </summary>
    public void ShowUpdateAvailable(UpdateInfo updateInfo)
    {
        try
        {
            new ToastContentBuilder()
                .AddText("PolskiWhisper - nowa wersja")
                .AddText($"Dostępna jest wersja {updateInfo.LatestVersion}. Aktualnie używasz {updateInfo.CurrentVersion}.")
                .AddButton(new ToastButton()
                    .SetContent("Otwórz Ustawienia")
                    .AddArgument("action", "open-settings"))
                .AddButton(new ToastButton()
                    .SetContent("Później")
                    .AddArgument("action", "dismiss"))
                .Show();

            _logger.LogInformation("Toast notification: nowa wersja {Version}.", updateInfo.LatestVersion);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Nie udało się wyświetlić toast notification.");
        }
    }

    /// <summary>
    /// Generic info toast (np. "Aktualizacja zainstalowana", "Nagrywanie anulowane").
    /// </summary>
    public void ShowInfo(string title, string message)
    {
        try
        {
            new ToastContentBuilder()
                .AddText(title)
                .AddText(message)
                .Show();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Toast nieudany.");
        }
    }

    private void OnToastActivated(ToastNotificationActivatedEventArgsCompat e)
    {
        try
        {
            var args = ToastArguments.Parse(e.Argument);
            var action = args.Get("action");
            _logger.LogDebug("Toast clicked: action={Action}.", action);

            if (action == "open-settings")
            {
                // UI thread switch.
                if (Microsoft.UI.Xaml.Application.Current is App app)
                {
                    app.ShowSettingsWindow();
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Toast activation handler nieudane.");
        }
    }
}
