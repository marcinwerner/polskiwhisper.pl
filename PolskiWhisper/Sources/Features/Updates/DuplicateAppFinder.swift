//
//  DuplicateAppFinder.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import Foundation
import Observation

/// Wykrywa duplikaty PolskiWhisper.app w typowych lokalizacjach (Downloads, Desktop,
/// /Applications, ~/Applications). Pomaga user'owi sprzątnąć starsze wersje pobrane
/// z DMG i nie usunięte ręcznie - klasyczny problem przy update flow bez Sparkle.
///
/// **Idempotent**: można wywoływać wielokrotnie, każdy scan jest świeży.
/// **Bezpieczne**: NIE usuwa nic automatycznie - tylko pokazuje listę, user decyduje.
@MainActor
@Observable
final class DuplicateAppFinder {

    static let shared = DuplicateAppFinder()

    /// Lista znalezionych duplikatów (poza aktualnie uruchomioną aplikacją).
    private(set) var duplicates: [DuplicateApp] = []

    private init() {}

    struct DuplicateApp: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let version: String?
        let modifiedAt: Date?
        let location: String  // "Pobrane", "Pulpit", "/Applications", etc.

        var sizeFormatted: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return formatter.string(fromByteCount: size)
        }
    }

    /// Skanuje typowe lokalizacje, populuje `duplicates`. Pomija aktualnie uruchomioną aplikację.
    func scan() {
        Log.app.info("DuplicateAppFinder: scanning typical locations")

        let runningPath = Bundle.main.bundleURL.standardizedFileURL.path
        var found: [DuplicateApp] = []

        for location in Self.searchLocations() {
            let appURL = location.url.appendingPathComponent("PolskiWhisper.app")
            guard FileManager.default.fileExists(atPath: appURL.path) else { continue }

            // Pomiń aktualnie uruchomioną aplikację
            if appURL.standardizedFileURL.path == runningPath {
                continue
            }

            let version = readVersion(from: appURL)
            let mtime = (try? FileManager.default.attributesOfItem(atPath: appURL.path)[.modificationDate]) as? Date

            found.append(DuplicateApp(
                url: appURL,
                version: version,
                modifiedAt: mtime,
                location: location.label
            ))
        }

        duplicates = found
        Log.app.info("DuplicateAppFinder: found \(found.count, privacy: .public) duplicate(s)")
    }

    /// Usuwa wybrane duplikaty (przenosi do Kosza, nie hard delete - safety).
    func removeToTrash(_ duplicate: DuplicateApp) {
        do {
            var resultURL: NSURL?
            try FileManager.default.trashItem(at: duplicate.url, resultingItemURL: &resultURL)
            Log.app.info("DuplicateAppFinder: moved to trash \(duplicate.url.path, privacy: .public)")
            // Re-scan żeby odświeżyć listę
            scan()
        } catch {
            Log.app.error("DuplicateAppFinder: trash failed - \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Usuwa wszystkie duplikaty na raz (bulk action).
    func removeAllToTrash() {
        for duplicate in duplicates {
            do {
                var resultURL: NSURL?
                try FileManager.default.trashItem(at: duplicate.url, resultingItemURL: &resultURL)
            } catch {
                Log.app.error("DuplicateAppFinder: bulk trash failed for \(duplicate.url.path, privacy: .public)")
            }
        }
        scan()
    }

    // MARK: - Private

    private struct SearchLocation {
        let url: URL
        let label: String
    }

    /// Typowe lokalizacje gdzie ludzie zostawiają stare kopie .app po pobraniu DMG.
    private static func searchLocations() -> [SearchLocation] {
        let fm = FileManager.default
        var locations: [SearchLocation] = []

        // /Applications - main install location
        locations.append(SearchLocation(
            url: URL(fileURLWithPath: "/Applications"),
            label: "/Applications"
        ))

        // ~/Applications
        if let home = fm.homeDirectoryForCurrentUser as URL? {
            locations.append(SearchLocation(
                url: home.appendingPathComponent("Applications"),
                label: "~/Applications"
            ))

            // ~/Downloads
            locations.append(SearchLocation(
                url: home.appendingPathComponent("Downloads"),
                label: "Pobrane"
            ))

            // ~/Desktop
            locations.append(SearchLocation(
                url: home.appendingPathComponent("Desktop"),
                label: "Pulpit"
            ))

            // ~/Documents
            locations.append(SearchLocation(
                url: home.appendingPathComponent("Documents"),
                label: "Dokumenty"
            ))
        }

        return locations
    }

    private func readVersion(from appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist["CFBundleShortVersionString"] as? String
    }
}
