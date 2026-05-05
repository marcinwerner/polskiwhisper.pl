//
//  VocabularySettingsTab.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct VocabularySettingsTab: View {

    @State private var store = VocabularyStore.shared
    @State private var selectedSection: Section = .customWords
    @State private var importReplace: Bool = false
    @State private var importStatus: String?

    enum Section: String, CaseIterable, Identifiable {
        case customWords = "Słowa własne"
        case findReplace = "Znajdź i zamień"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .customWords:
                return "Słowa wstrzykiwane do Whisper jako kontekst (lepsze rozpoznawanie nazw własnych)."
            case .findReplace:
                return "Reguły zamiany aplikowane do tekstu po transkrypcji."
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sekcja", selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Text(selectedSection.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Divider()

            switch selectedSection {
            case .customWords:
                CustomWordsView()
            case .findReplace:
                FindReplaceView()
            }

            Divider()

            // Backup / przywracanie
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button("Eksportuj słownik do JSON...") {
                        exportToJSON()
                    }
                    .controlSize(.small)
                    Button("Importuj z JSON...") {
                        importFromJSON()
                    }
                    .controlSize(.small)
                    Toggle("Zastąp istniejące", isOn: $importReplace)
                        .controlSize(.small)
                    Spacer()
                    Button("Pokaż folder danych") {
                        showDataFolder()
                    }
                    .controlSize(.small)
                }

                if let importStatus {
                    Text(importStatus)
                        .font(.caption)
                        .foregroundStyle(importStatus.hasPrefix("Błąd") ? .red : .green)
                }

                Text("Słownik jest zapisany w `~/Library/Application Support/PolskiWhisper/vocabulary.db` - zachowywany między restartami i aktualizacjami aplikacji. Eksport JSON to dodatkowa kopia zapasowa.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }

    private func exportToJSON() {
        do {
            let data = try store.exportToJSON()
            let panel = NSSavePanel()
            panel.title = "Eksportuj słownik"
            panel.nameFieldStringValue = "polskiwhisper-vocabulary-\(Self.dateString()).json"
            panel.allowedContentTypes = [.json]
            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url)
                importStatus = "Wyeksportowano do \(url.lastPathComponent)"
            }
        } catch {
            importStatus = "Błąd eksportu: \(error.localizedDescription)"
        }
    }

    private func importFromJSON() {
        let panel = NSOpenPanel()
        panel.title = "Importuj słownik"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                try store.importFromJSON(data, replace: importReplace)
                let mode = importReplace ? "zastąpiono" : "dodano"
                importStatus = "Zaimportowano (\(mode)) z \(url.lastPathComponent)"
            } catch {
                importStatus = "Błąd importu: \(error.localizedDescription)"
            }
        }
    }

    private func showDataFolder() {
        if let url = VocabularyStore.dataFolderURL() {
            NSWorkspace.shared.open(url)
        }
    }

    private static func dateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - Custom Words

private struct CustomWordsView: View {
    @State private var store = VocabularyStore.shared
    @State private var newWord: String = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Dodaj słowo (np. Anthropic, Claude Code)", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { add() }
                Button("Dodaj", action: add)
                    .keyboardShortcut(.return)
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            List {
                ForEach(store.customWords) { word in
                    HStack {
                        Text(word.word)
                        Spacer()
                        Button {
                            delete(id: word.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Text("\(store.customWords.count) słów")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func add() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try store.addCustomWord(trimmed)
            newWord = ""
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(id: Int64?) {
        guard let id else { return }
        try? store.deleteCustomWord(id: id)
    }
}

// MARK: - Find & Replace

private struct FindReplaceView: View {
    @State private var store = VocabularyStore.shared
    @State private var findText: String = ""
    @State private var replaceWith: String = ""
    @State private var isRegex: Bool = false
    @State private var caseSensitive: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    TextField("Znajdź...", text: $findText)
                        .textFieldStyle(.roundedBorder)
                    TextField("Zamień na...", text: $replaceWith)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Toggle("Regex", isOn: $isRegex)
                    Toggle("Case sensitive", isOn: $caseSensitive)
                    Spacer()
                    Button("Dodaj regułę", action: add)
                        .disabled(findText.isEmpty)
                }
            }
            .padding()

            List {
                ForEach(store.findReplaceRules) { rule in
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(rule.findText)
                                    .font(.system(.body, design: .monospaced))
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(rule.replaceWith)
                                    .font(.system(.body, design: .monospaced))
                            }
                            HStack(spacing: 4) {
                                if rule.isRegex {
                                    Text("regex")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .background(Color.orange.opacity(0.3))
                                        .cornerRadius(3)
                                }
                                if rule.caseSensitive {
                                    Text("Aa")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .background(Color.blue.opacity(0.3))
                                        .cornerRadius(3)
                                }
                            }
                        }
                        Spacer()
                        Button {
                            delete(id: rule.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                Text("\(store.findReplaceRules.count) reguł")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func add() {
        try? store.addFindReplaceRule(
            find: findText,
            replace: replaceWith,
            isRegex: isRegex,
            caseSensitive: caseSensitive
        )
        findText = ""
        replaceWith = ""
        isRegex = false
        caseSensitive = false
    }

    private func delete(id: Int64?) {
        guard let id else { return }
        try? store.deleteFindReplaceRule(id: id)
    }
}

