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
    @State private var loadingMessages = LoadingMessages.shared
    @State private var selectedModel: WhisperService.Model = .default
    @State private var isChangingModel: Bool = false
    @State private var loadError: String?

    /// Dialog potwierdzenia usunięcia poprzedniego modelu po udanej zmianie.
    @State private var modelToCleanup: WhisperService.Model?
    @State private var modelToCleanupSize: Int64 = 0

    /// Dialog potwierdzenia pobierania niepobranego modelu po wyborze w pickerze.
    /// Auto-load TYLKO dla pobranych modeli - duże downloadowanie wymaga zgody.
    @State private var modelToDownloadConfirm: WhisperService.Model?

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
                            // Kolorowe strzałki: zielona w prawo dla pobranych (gotowe do wyboru),
                            // szara w dół dla niepobranych (pobierze przy wyborze).
                            if WhisperService.isModelDownloaded(model) {
                                Image(systemName: "arrow.right.circle.fill")
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

                // Progress bar gdy pobieranie/ładowanie trwa.
                // Rozróżniamy 2 fazy: download (rzeczywisty progress 0-100%) vs
                // loadingToRAM (indeterminate spinner, brak callback z WhisperKit).
                if let service = whisperService, service.isLoading || isChangingModel {
                    VStack(alignment: .leading, spacing: 6) {
                        switch service.loadPhase {
                        case .downloading(let progress):
                            HStack {
                                Text(loadingMessages.currentMessage)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                Spacer()
                                Text("\(Int(progress * 100))%")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: progress)
                                .progressViewStyle(.linear)

                        case .loadingToRAM:
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text(loadingMessages.currentMessage)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                            }

                        case .ready, .idle:
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Przygotowanie...")
                                    .font(.callout)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let error = loadError {
                    Text("Błąd: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("""
                    Wybranie modelu z listy automatycznie go ładuje. Modele pobrane (zielona strzałka) \
                    aktywują się natychmiast. Modele niepobrane (szara strzałka) wymagają potwierdzenia \
                    pobierania - aplikacja zapyta przed downloadem.
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
        .onChange(of: selectedModel) { _, newValue in
            // Auto-load po wyborze modelu (Wave 2).
            // Niepobrane modele wymagają confirm (download MB-GB).
            guard !isChangingModel else { return }
            guard newValue != whisperService?.loadedModel else { return }

            if WhisperService.isModelDownloaded(newValue) {
                Task { await changeModel() }
            } else {
                modelToDownloadConfirm = newValue
            }
        }
        .alert(
            "Pobrać model?",
            isPresented: Binding(
                get: { modelToDownloadConfirm != nil },
                set: { if !$0 { modelToDownloadConfirm = nil } }
            ),
            presenting: modelToDownloadConfirm
        ) { model in
            Button("Pobierz \(formatBytes(model.approximateBytes))") {
                modelToDownloadConfirm = nil
                Task { await changeModel() }
            }
            Button("Anuluj", role: .cancel) {
                modelToDownloadConfirm = nil
                // Revert selection do aktualnie załadowanego modelu
                if let loaded = whisperService?.loadedModel {
                    selectedModel = loaded
                }
            }
        } message: { model in
            Text("""
                Model \(model.displayName) nie jest jeszcze pobrany.

                Pobranie zajmuje około \(formatBytes(model.approximateBytes)) i wymaga połączenia z internetem. Po pobraniu zostanie automatycznie aktywowany.
                """)
        }
        .alert(
            "Usunąć poprzedni model?",
            isPresented: Binding(
                get: { modelToCleanup != nil },
                set: { if !$0 { modelToCleanup = nil } }
            ),
            presenting: modelToCleanup
        ) { oldModel in
            Button("Usuń (\(formatBytes(modelToCleanupSize)))") {
                WhisperService.deleteModel(oldModel)
                modelToCleanup = nil
            }
            Button("Zostaw", role: .cancel) {
                modelToCleanup = nil
            }
        } message: { oldModel in
            Text("""
                Pomyślnie zmieniono model na \(selectedModel.displayName).

                Poprzedni model \(oldModel.displayName) zajmuje \(formatBytes(modelToCleanupSize)) na dysku w `~/Documents/huggingface/`. Nie jest już używany - usunąć żeby zwolnić miejsce?
                """)
        }
    }

    private func changeModel() async {
        guard let service = whisperService else { return }
        let previousModel = service.loadedModel
        isChangingModel = true
        loadError = nil
        defer { isChangingModel = false }

        do {
            try await service.loadModel(selectedModel)
            UserDefaults.standard.set(selectedModel.rawValue, forKey: AppCoordinator.Keys.selectedWhisperModel)

            // Po pomyślnej zmianie - jeśli poprzedni model jest na dysku i to nie aktualnie
            // wybrany model, zaproponuj cleanup. User decyduje (Tak/Nie).
            if let prev = previousModel,
               prev != selectedModel,
               WhisperService.isModelDownloaded(prev),
               let size = WhisperService.actualModelSize(for: prev) {
                modelToCleanupSize = size
                modelToCleanup = prev
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
