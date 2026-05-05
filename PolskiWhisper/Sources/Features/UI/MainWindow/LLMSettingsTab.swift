//
//  LLMSettingsTab.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import SwiftUI

struct LLMSettingsTab: View {

    @State private var coordinator = AppCoordinator.shared
    @State private var llmEnabled: Bool = AppCoordinator.shared.llmEnabled
    @State private var selectedModel: String = AppCoordinator.shared.selectedLLMModel
    @State private var customPrompt: String = AppCoordinator.shared.customLLMSystemPrompt
    @State private var isChecking: Bool = false

    private var ollamaService: OllamaService? {
        coordinator.dictationEngine?.ollamaService
    }

    private static let recommendedModels: [(name: String, description: String)] = [
        ("SpeakLeash/bielik-11b-v2.3-instruct:Q4_K_M", "Bielik 11B Q4 (rekomendowany dla polskiego, ~7 GB RAM, wolny na M1)"),
        ("SpeakLeash/bielik-11b-v2.3-instruct:Q5_K_M", "Bielik 11B Q5 (lepsza jakość, ~9 GB RAM)"),
        ("llama3.2:3b-instruct-q4_K_M", "Llama 3.2 3B Q4 (~2 GB RAM, szybki, słabszy polski)"),
        ("phi3.5:3.8b", "Phi 3.5 3.8B (~2 GB RAM, szybki, słabszy polski)"),
        ("qwen2.5:14b-instruct-q4_K_M", "Qwen 2.5 14B (~10 GB RAM, najlepsza jakość, bardzo wolny na M1)")
    ]

    var body: some View {
        Form {
            Section("Oczyszczanie tekstu przez AI") {
                Toggle("Włącz oczyszczanie tekstu przez model AI", isOn: $llmEnabled)
                    .onChange(of: llmEnabled) { _, newValue in
                        AppCoordinator.shared.llmEnabled = newValue
                    }

                Text("""
                    Włączenie spowoduje że po transkrypcji Whisper tekst zostanie wysłany do \
                    lokalnego modelu AI (Ollama) który: usunie wahania (eee, yyy), poprawi \
                    interpunkcję i kapitalizację. Działa offline, dane nie opuszczają komputera.
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("⚠️ Na MacBook M1 16GB Bielik 11B dodaje 15-30 sekund do każdego dyktowania.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Section("Status Ollama") {
                if let service = ollamaService {
                    HStack {
                        Text("Daemon (localhost:11434):")
                        Spacer()
                        if service.isRunning {
                            Label("Działa", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Nie wykryto", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    Button {
                        Task {
                            isChecking = true
                            _ = await service.healthCheck()
                            isChecking = false
                        }
                    } label: {
                        if isChecking {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Text("Sprawdź ponownie")
                        }
                    }
                    .disabled(isChecking)

                    if !service.isRunning {
                        Button("Pobierz Ollama") {
                            if let url = URL(string: "https://ollama.com/download/mac") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }

                    if !service.availableModels.isEmpty {
                        Text("Zainstalowane modele: \(service.availableModels.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Wybór modelu") {
                Picker("Model:", selection: $selectedModel) {
                    ForEach(Self.recommendedModels, id: \.name) { model in
                        Text(model.description).tag(model.name)
                    }
                    if !Self.recommendedModels.contains(where: { $0.name == selectedModel }) {
                        Text(selectedModel).tag(selectedModel)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedModel) { _, newValue in
                    AppCoordinator.shared.selectedLLMModel = newValue
                }

                if let service = ollamaService, !selectedModel.isEmpty {
                    if service.isModelInstalled(selectedModel) {
                        Label("Model zainstalowany", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Model NIE zainstalowany", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Aby zainstalować, otwórz Terminal i wpisz:")
                                .font(.caption)
                            Text("ollama pull \(selectedModel)")
                                .font(.system(.caption, design: .monospaced))
                                .padding(6)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(4)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Section("Instrukcja systemowa (zaawansowane)") {
                Text("Pozostaw puste aby użyć domyślnej instrukcji z zabezpieczeniem przed manipulacją.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $customPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .border(Color.gray.opacity(0.3))
                    .onChange(of: customPrompt) { _, newValue in
                        AppCoordinator.shared.customLLMSystemPrompt = newValue
                    }

                Button("Reset do domyślnego") {
                    customPrompt = ""
                    AppCoordinator.shared.customLLMSystemPrompt = ""
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            // Sprawdź Ollama przy otwarciu zakładki
            _ = await ollamaService?.healthCheck()
        }
    }
}
