//
//  PolskiWhisperApp.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import SwiftUI

/// Główny entry point aplikacji.
///
/// Aplikacja jest typu menu bar (LSUIElement w Info.plist), więc nie ma "Window" w klasycznym
/// sensie SwiftUI. Główna scena to `Settings` (otwiera się przez Cmd+, lub menu bar).
/// Floating dictation window jest zarządzany ręcznie przez NSPanel (poza SwiftUI App lifecycle).
///
/// Coordinator i wszystkie kluczowe serwisy są inicjalizowane w `AppDelegate.applicationDidFinishLaunching`.
@main
struct PolskiWhisperApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings są zarządzane przez SettingsWindowController (manual NSWindow)
        // żeby ominąć macOS 14+ ostrzeżenie 'Please use SettingsLink' dla menu bar apps.
        // Cała logika UI w SettingsView, otwieranie przez menu bar → "Otwórz Ustawienia"
        // lub Cmd+, (zarejestrowane w MenuBarController menu item).
        //
        // SwiftUI App musi mieć ALE-jakąś scene (compiler wymaga). Używamy ukrytego
        // WindowGroup który nigdy się nie pokazuje - rzeczywiste okna tworzone manualnie.
        WindowGroup(id: "hidden-placeholder") {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
    }
}
