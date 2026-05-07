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
    @State private var importReplace: Bool = false
    @State private var importStatus: String?

    var body: some View {
        VStack(spacing: 0) {
            Text("Reguły zamiany tekstu po transkrypcji - przydatne gdy Whisper rozpoznaje słowo, ale zapisuje je inaczej niż chcesz (np. nazwy firm, imiona).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            Divider()

            FindReplaceView()

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

// MARK: - Custom Words (LEGACY - usunięte z UI w v0.1.2)
//
// 2026-05-06: Marcin zdecydował wyrzucić zakładkę "Słowa własne" z UI po test sesji.
// Custom Words wstrzykiwane jako Whisper `promptTokens` powodowały decoder hell + empty
// output dla rzadkich nazw (np. "Ofertica" → 108s decoding lub instant empty).
// j1 retry path wprowadzony tego samego dnia chroni paste, ale Custom Words są de facto
// martwe - zawsze idziemy do retry bez nich.
//
// **Ten kod zostaje** (DB schema, API, view) na wypadek gdyby kiedyś okazało się że dla
// typowych słów (nazwiska, terminy) boost jest realny - łatwy comeback bez migracji.
// Na razie - niepodpięty pod UI. Tab "Słownik" → tylko Find & Replace.

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
    @State private var showAdvanced: Bool = false

    /// Edit mode - jeśli != nil, formularz na górze edytuje regułę zamiast dodawać nową.
    @State private var editingRuleID: Int64?

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
                    Toggle("Rozróżniaj wielkie/małe litery", isOn: $caseSensitive)
                        .help("Włączone: 'tekst' znajdzie tylko 'tekst'. Wyłączone: znajdzie też 'Tekst', 'TEKST'. Zwykle zostaw wyłączone.")

                    DisclosureGroup(isExpanded: $showAdvanced) {
                        Toggle("Wzorzec zaawansowany (regex)", isOn: $isRegex)
                            .help("Wyrażenia regularne - tylko dla programistów. 99% userów nie potrzebuje. Włącz tylko jeśli wiesz co to jest.")
                    } label: {
                        Text("Zaawansowane")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if editingRuleID != nil {
                        Button("Anuluj") {
                            cancelEdit()
                        }
                        Button("Zapisz zmiany", action: saveEdit)
                            .disabled(findText.isEmpty)
                            .keyboardShortcut(.return)
                    } else {
                        Button("Dodaj regułę", action: add)
                            .disabled(findText.isEmpty)
                            .keyboardShortcut(.return)
                    }
                }
            }
            .padding()

            // Lista reguł z drag-and-drop reorderem (`.onMove`).
            // Klik na regułę = edit mode (formularz na górze ładuje wartości).
            List {
                ForEach(store.findReplaceRules) { rule in
                    ruleRow(rule)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            startEdit(rule)
                        }
                }
                .onMove(perform: moveRules)
            }

            HStack(spacing: 12) {
                Text("\(store.findReplaceRules.count) reguł")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.findReplaceRules.count > 1 {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Klik = edycja, przeciągnij = zmień kolejność")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func ruleRow(_ rule: VocabularyStore.FindReplaceRule) -> some View {
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
                        Text("wzorzec")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .background(Color.orange.opacity(0.3))
                            .cornerRadius(3)
                            .help("Reguła używa wzorca zaawansowanego (regex)")
                    }
                    if rule.caseSensitive {
                        Text("Aa")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(3)
                            .help("Reguła rozróżnia wielkie i małe litery")
                    }
                    if editingRuleID == rule.id {
                        Text("EDYTOWANA")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .background(Color.yellow.opacity(0.3))
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

    // MARK: - Actions

    private func add() {
        try? store.addFindReplaceRule(
            find: findText,
            replace: replaceWith,
            isRegex: isRegex,
            caseSensitive: caseSensitive
        )
        clearForm()
    }

    private func delete(id: Int64?) {
        guard let id else { return }
        // Jeśli kasujemy regułę którą edytujemy, anuluj edit
        if editingRuleID == id {
            cancelEdit()
        }
        try? store.deleteFindReplaceRule(id: id)
    }

    private func startEdit(_ rule: VocabularyStore.FindReplaceRule) {
        editingRuleID = rule.id
        findText = rule.findText
        replaceWith = rule.replaceWith
        isRegex = rule.isRegex
        caseSensitive = rule.caseSensitive
        // Auto-expand "Zaawansowane" jeśli reguła używa regex
        if rule.isRegex {
            showAdvanced = true
        }
    }

    private func saveEdit() {
        guard let id = editingRuleID else { return }
        try? store.updateFindReplaceRule(
            id: id,
            find: findText,
            replace: replaceWith,
            isRegex: isRegex,
            caseSensitive: caseSensitive
        )
        clearForm()
    }

    private func cancelEdit() {
        clearForm()
    }

    private func clearForm() {
        editingRuleID = nil
        findText = ""
        replaceWith = ""
        isRegex = false
        caseSensitive = false
        showAdvanced = false
    }

    private func moveRules(from source: IndexSet, to destination: Int) {
        var rules = store.findReplaceRules
        rules.move(fromOffsets: source, toOffset: destination)
        let orderedIDs = rules.compactMap { $0.id }
        try? store.reorderFindReplaceRules(orderedIDs: orderedIDs)
    }
}

