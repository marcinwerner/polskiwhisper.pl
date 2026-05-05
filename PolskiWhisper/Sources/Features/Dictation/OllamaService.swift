//
//  OllamaService.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation
import Observation

/// HTTP client do lokalnego Ollama daemon (`http://localhost:11434`).
///
/// **Zero połączeń sieciowych poza localhost** - hardcoded URL, audytowalne.
///
/// Ollama jest instalowana przez użytkownika osobno (https://ollama.com/download/mac),
/// nie bundlowana z aplikacją. Aplikacja tylko komunikuje się przez HTTP API.
@MainActor
@Observable
final class OllamaService {

    // MARK: - Errors

    enum OllamaError: LocalizedError {
        case ollamaNotRunning
        case modelNotInstalled(String)
        case requestFailed(String)
        case invalidResponse
        case timeout

        var errorDescription: String? {
            switch self {
            case .ollamaNotRunning:
                return "Ollama nie jest uruchomiona. Otwórz aplikację Ollama lub zainstaluj z https://ollama.com/download/mac"
            case .modelNotInstalled(let name):
                return "Model \(name) nie jest zainstalowany. Pobierz przez `ollama pull \(name)` w Terminalu."
            case .requestFailed(let msg):
                return "Błąd żądania do Ollama: \(msg)"
            case .invalidResponse:
                return "Nieprawidłowa odpowiedź z Ollama."
            case .timeout:
                return "Timeout - Ollama nie odpowiada (model może być za duży na M1 16GB?)"
            }
        }
    }

    // MARK: - Constants (hardcoded - audytowalne)

    private static let baseURL = "http://localhost:11434"
    private static let healthCheckTimeout: TimeInterval = 2.0
    private static let generateTimeout: TimeInterval = 120.0  // duże LLM mogą być wolne na M1

    // MARK: - State (observable)

    private(set) var isRunning: Bool = false
    private(set) var availableModels: [String] = []
    private(set) var lastHealthCheckAt: Date?

    // MARK: - Public API

    /// Sprawdza czy Ollama daemon odpowiada.
    /// Aktualizuje `isRunning` i (jeśli running) `availableModels`.
    func healthCheck() async -> Bool {
        guard let url = URL(string: "\(Self.baseURL)/api/tags") else {
            isRunning = false
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.healthCheckTimeout
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                isRunning = false
                Log.ollama.warning("Ollama health check failed - non-200 response")
                return false
            }

            // Parse models list
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                availableModels = models.compactMap { $0["name"] as? String }
                Log.ollama.info("Ollama running, \(self.availableModels.count, privacy: .public) models installed")
            }

            isRunning = true
            lastHealthCheckAt = Date()
            return true
        } catch {
            isRunning = false
            Log.ollama.info("Ollama not running (\(error.localizedDescription, privacy: .public))")
            return false
        }
    }

    /// Wywołuje `/api/generate` z system promptem + user promptem.
    /// Zwraca oczyszczony tekst.
    ///
    /// - Parameters:
    ///   - model: nazwa modelu (np. "SpeakLeash/bielik-11b-v2.3-instruct:Q4_K_M")
    ///   - systemPrompt: instrukcja dla LLM (defensywna, anti-prompt-injection)
    ///   - userPrompt: tekst do oczyszczenia (transkrypcja Whisper)
    ///   - temperature: 0.0 dla deterministic output (cleanup nie wymaga creativity)
    func generate(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        temperature: Double = 0.0
    ) async throws -> String {
        guard let url = URL(string: "\(Self.baseURL)/api/generate") else {
            throw OllamaError.requestFailed("Invalid URL")
        }

        // Połączony prompt (Ollama /api/generate akceptuje system + prompt)
        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "prompt": userPrompt,
            "stream": false,
            "options": [
                "temperature": temperature,
                "num_predict": 2048  // limit response length
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.generateTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let startTime = Date()
        Log.ollama.info("Generating with model \(model, privacy: .public)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }

            if http.statusCode == 404 {
                throw OllamaError.modelNotInstalled(model)
            }
            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw OllamaError.requestFailed("HTTP \(http.statusCode): \(body)")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseText = json["response"] as? String else {
                throw OllamaError.invalidResponse
            }

            let duration = Date().timeIntervalSince(startTime)
            let trimmed = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            Log.ollama.info("""
                Generated \(trimmed.count, privacy: .public) chars in \(duration, privacy: .public)s
                """)

            return trimmed
        } catch let error as OllamaError {
            throw error
        } catch {
            // URLError -1004 = "Could not connect" - Ollama nie running
            if let urlError = error as? URLError, urlError.code == .cannotConnectToHost {
                isRunning = false
                throw OllamaError.ollamaNotRunning
            }
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw OllamaError.timeout
            }
            throw OllamaError.requestFailed(error.localizedDescription)
        }
    }

    /// Sprawdza czy konkretny model jest zainstalowany (przez `availableModels` z health check).
    func isModelInstalled(_ model: String) -> Bool {
        availableModels.contains(where: { $0 == model || $0.hasPrefix("\(model):") })
    }
}
