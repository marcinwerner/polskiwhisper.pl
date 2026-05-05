//
//  WhisperSettingsTab.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import SwiftUI

struct WhisperSettingsTab: View {

    @State private var coordinator = AppCoordinator.shared
    @State private var selectedModel: WhisperService.Model = .default
    @State private var isChangingModel: Bool = false
    @State private var loadError: String?

    private var whisperService: WhisperService? {
        coordinator.dictationEngine?.whisperService
    }

    var body: some View {
        Form {
            Section("Status") {
                if let service = whisperService {
                    HStack {
                        Text("Aktualny model:")
                        Spacer()
                        if let loaded = service.loadedModel {
                            Label(loaded.displayName, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if service.isLoading {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.6)
                                Text("Ładowanie...")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Nie załadowany")
                                .foregroundStyle(.red)
                        }
                    }

                    HStack {
                        Text("Język:")
                        Spacer()
                        Text("Polski (wymuszony)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("DictationEngine nie zainicjalizowany")
                        .foregroundStyle(.red)
                }
            }

            Section("Wybierz model") {
                Picker("Model:", selection: $selectedModel) {
                    ForEach(WhisperService.Model.allCases) { model in
                        HStack {
                            // Symbol stanu pobrania
                            if WhisperService.isModelDownloaded(model) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(.secondary)
                            }
                            Text(model.displayName)
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isChangingModel)

                // Lista wszystkich modeli z statusem (poniżej pickera dla jasności)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(WhisperService.Model.allCases) { model in
                        HStack(spacing: 6) {
                            if WhisperService.isModelDownloaded(model) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("Pobrany")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text("Nie pobrany")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("·")
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                            Text(model.displayName)
                                .font(.caption2)
                                .foregroundStyle(model == selectedModel ? .primary : .secondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Progress bar gdy pobieranie/ładowanie trwa
                if let service = whisperService, service.isLoading || isChangingModel {
                    let progress = service.loadProgress
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(progressLabel(for: progress))
                                .font(.callout)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    Task { await changeModel() }
                } label: {
                    if isChangingModel {
                        HStack {
                            ProgressView().scaleEffect(0.6)
                            Text("Pobieranie/ładowanie...")
                        }
                    } else if WhisperService.isModelDownloaded(selectedModel) && selectedModel != whisperService?.loadedModel {
                        Text("Załaduj wybrany model")
                    } else if !WhisperService.isModelDownloaded(selectedModel) {
                        Text("Pobierz i załaduj wybrany model")
                    } else {
                        Text("Wybrany model jest już aktywny")
                    }
                }
                .disabled(isChangingModel || selectedModel == whisperService?.loadedModel)

                if let error = loadError {
                    Text("Błąd: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("""
                    Modele są pobierane z Hugging Face przy pierwszym wyborze i zapisywane w \
                    `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`. \
                    Każdy model można usunąć ręcznie z tego folderu aby zwolnić miejsce.
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            if let loaded = whisperService?.loadedModel {
                selectedModel = loaded
            }
        }
    }

    private func progressLabel(for progress: Double) -> String {
        if progress < 0.9 {
            return "Pobieranie modelu..."
        } else if progress < 1.0 {
            return "Ładowanie do pamięci..."
        } else {
            return "Gotowy"
        }
    }

    private func changeModel() async {
        guard let service = whisperService else { return }
        isChangingModel = true
        loadError = nil
        defer { isChangingModel = false }

        do {
            try await service.loadModel(selectedModel)
            UserDefaults.standard.set(selectedModel.rawValue, forKey: AppCoordinator.Keys.selectedWhisperModel)
        } catch {
            loadError = error.localizedDescription
        }
    }
}
