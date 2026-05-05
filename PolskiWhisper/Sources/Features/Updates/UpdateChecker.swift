//
//  UpdateChecker.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation
import Observation

/// Sprawdzanie dostępności nowych wersji aplikacji przez GitHub Releases API.
///
/// Brak Apple Developer ID = brak Sparkle = brak true auto-install. Aplikacja
/// może tylko **powiadomić** usera że jest dostępna nowa wersja - user pobiera
/// DMG ręcznie. Auto-detekcja podmiany DMG w `/Applications/` jest w `SelfUpdateDetector`.
///
/// **Zero personal data** - tylko publiczny GitHub API endpoint, brak autentykacji.
@MainActor
@Observable
final class UpdateChecker {

    // MARK: - Singleton

    static let shared = UpdateChecker()

    // MARK: - Constants

    /// Endpoint GitHub Releases API - zwraca najnowszy non-prerelease.
    private static let releaseAPI = URL(string: "https://api.github.com/repos/marcinwerner/polskiwhisper.pl/releases/latest")!

    /// Minimalny odstęp między automatycznymi check'ami (24h).
    private static let checkInterval: TimeInterval = 86400

    /// Klucz UserDefaults - timestamp ostatniego sprawdzenia.
    private static let lastCheckKey = "lastUpdateCheck"

    /// Klucz UserDefaults - ostatnio widziana wersja (żeby nie pokazywać ten sam update wielokrotnie).
    private static let lastSeenVersionKey = "lastSeenUpdateVersion"

    // MARK: - Models

    struct UpdateInfo: Equatable {
        let version: String          // np. "0.1.2"
        let downloadURL: URL?        // DMG asset URL
        let releaseNotesURL: URL     // strona release na GitHub
        let releaseNotes: String     // body z release
        let publishedAt: Date
    }

    // MARK: - State (observable - SwiftUI views obserwują)

    /// Dostępna nowa wersja (jeśli istnieje). UI binduje się do tej property.
    private(set) var availableUpdate: UpdateInfo?

    /// Czy aktualnie trwa sprawdzanie (do UI loading state, jeśli kiedyś dodamy "sprawdź teraz").
    private(set) var isChecking: Bool = false

    /// Timestamp ostatniego sprawdzenia (do UI "Ostatnio sprawdzono...").
    private(set) var lastCheckedAt: Date?

    private init() {
        // Wczytaj ostatni check z persistencji
        if let date = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date {
            self.lastCheckedAt = date
        }
    }

    // MARK: - Public API

    /// Sprawdza czy minęły 24h od ostatniego check - jeśli tak, wykonuje check.
    /// Wywoływane przy starcie aplikacji + okresowo (np. raz na minutę kontrola czasu,
    /// realny network call max raz na 24h).
    func checkIfDue() async {
        if let last = lastCheckedAt, Date().timeIntervalSince(last) < Self.checkInterval {
            return  // jeszcze za wcześnie
        }
        await performCheck()
    }

    /// Force check teraz - obecnie nieużywane (no manual button per Marcin), ale zostawiam
    /// public dla testów/debug.
    func forceCheck() async {
        await performCheck()
    }

    // MARK: - Internal

    private func performCheck() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        Log.app.info("UpdateChecker: sprawdzanie GitHub Releases API")

        do {
            var request = URLRequest(url: Self.releaseAPI)
            request.timeoutInterval = 10
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                Log.app.warning("UpdateChecker: brak HTTPURLResponse")
                return
            }
            guard http.statusCode == 200 else {
                Log.app.warning("UpdateChecker: HTTP \(http.statusCode, privacy: .public)")
                return
            }

            guard let info = parseReleaseJSON(data) else {
                Log.app.warning("UpdateChecker: nie udało się sparsować JSON")
                return
            }

            // Persist timestamp
            let now = Date()
            UserDefaults.standard.set(now, forKey: Self.lastCheckKey)
            lastCheckedAt = now

            // Czy jest nowsza niż aktualna?
            let currentVersion = Bundle.main.appVersion
            if isNewer(remote: info.version, current: currentVersion) {
                Log.app.info("UpdateChecker: znaleziono nowszą wersję \(info.version, privacy: .public) (aktualna: \(currentVersion, privacy: .public))")
                availableUpdate = info
            } else {
                Log.app.info("UpdateChecker: brak nowej wersji (remote=\(info.version, privacy: .public), current=\(currentVersion, privacy: .public))")
                availableUpdate = nil
            }
        } catch {
            Log.app.warning("UpdateChecker: błąd sieci - \(error.localizedDescription, privacy: .public)")
        }
    }

    private func parseReleaseJSON(_ data: Data) -> UpdateInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let tagName = (json["tag_name"] as? String) ?? ""
        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        guard !version.isEmpty else { return nil }

        let body = (json["body"] as? String) ?? ""
        let htmlURLString = (json["html_url"] as? String) ?? "https://github.com/marcinwerner/polskiwhisper.pl/releases"
        let htmlURL = URL(string: htmlURLString) ?? URL(string: "https://github.com/marcinwerner/polskiwhisper.pl/releases")!

        // Find DMG asset
        var dmgURL: URL?
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let name = asset["name"] as? String,
                   name.hasSuffix(".dmg"),
                   let urlString = asset["browser_download_url"] as? String,
                   let url = URL(string: urlString) {
                    dmgURL = url
                    break
                }
            }
        }

        // Published date
        var publishedAt = Date()
        if let dateString = json["published_at"] as? String {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                publishedAt = date
            }
        }

        return UpdateInfo(
            version: version,
            downloadURL: dmgURL,
            releaseNotesURL: htmlURL,
            releaseNotes: body,
            publishedAt: publishedAt
        )
    }

    /// Porównanie semver - czy `remote` jest nowsze od `current`.
    /// Bardzo proste lexicographic comparison po komponentach numerycznych.
    private func isNewer(remote: String, current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let count = max(remoteParts.count, currentParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}

// MARK: - Bundle helper

extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }
}
