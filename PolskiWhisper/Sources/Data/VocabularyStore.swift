//
//  VocabularyStore.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation
import GRDB
import Observation

/// Persistencja słownika użytkownika w SQLite (GRDB).
///
/// Trzy warstwy słownika (zgodnie z ADR i INITIAL_PROMPT):
/// 1. **Custom Words** - lista słów wstrzykiwanych do Whisper jako `initialPrompt`,
///    żeby model preferował te terminy w transkrypcji (np. "Anthropic", "Claude Code")
/// 2. **Find & Replace** - reguły zamiany aplikowane do tekstu PO transkrypcji
///    (text lub regex), np. "klałd kod" → "Claude Code"
/// 3. **AI Vocabulary** - terminy wstrzykiwane do system promptu LLM (Bielik), aby zachować
///    ich pisownię podczas post-processingu
///
/// Lokalizacja: `~/Library/Application Support/PolskiWhisper/vocabulary.db`
@MainActor
@Observable
final class VocabularyStore {

    // MARK: - Models

    struct CustomWord: Identifiable, Codable, Equatable, Hashable {
        var id: Int64?
        var word: String
        var notes: String?
        var createdAt: Date
    }

    struct FindReplaceRule: Identifiable, Codable, Equatable, Hashable {
        var id: Int64?
        var findText: String
        var replaceWith: String
        var isRegex: Bool
        var caseSensitive: Bool
        var orderIndex: Int
        var createdAt: Date
    }

    struct AIVocabularyTerm: Identifiable, Codable, Equatable, Hashable {
        var id: Int64?
        var term: String
        var notes: String?
        var createdAt: Date
    }

    // MARK: - State (observable)

    private(set) var customWords: [CustomWord] = []
    private(set) var findReplaceRules: [FindReplaceRule] = []
    private(set) var aiVocabularyTerms: [AIVocabularyTerm] = []

    // MARK: - Private

    private let dbQueue: DatabaseQueue

    // MARK: - Init

    /// Singleton - prosty access z DictationEngine i Settings UI.
    static let shared: VocabularyStore = {
        do {
            return try VocabularyStore()
        } catch {
            fatalError("Failed to initialize VocabularyStore: \(error)")
        }
    }()

    private init() throws {
        let dbPath = try Self.databaseFileURL().path
        Log.storage.info("Opening vocabulary database at \(dbPath, privacy: .public)")

        var config = Configuration()
        config.label = "vocabulary"
        self.dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

        try migrator.migrate(dbQueue)
        try reload()
        Log.storage.info("""
            Vocabulary loaded: \(self.customWords.count, privacy: .public) custom words, \
            \(self.findReplaceRules.count, privacy: .public) find&replace rules, \
            \(self.aiVocabularyTerms.count, privacy: .public) AI vocab terms
            """)
    }

    // MARK: - Migrations

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_tables") { db in
            try db.create(table: "custom_word") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("word", .text).notNull()
                t.column("notes", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "find_replace_rule") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("findText", .text).notNull()
                t.column("replaceWith", .text).notNull()
                t.column("isRegex", .boolean).notNull().defaults(to: false)
                t.column("caseSensitive", .boolean).notNull().defaults(to: false)
                t.column("orderIndex", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "ai_vocabulary_term") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("term", .text).notNull()
                t.column("notes", .text)
                t.column("createdAt", .datetime).notNull()
            }
        }

        return migrator
    }

    // MARK: - Reload

    /// Reload all in-memory state from database. Call after any mutation.
    func reload() throws {
        try dbQueue.read { db in
            customWords = try CustomWord.fetchAll(db, sql: "SELECT * FROM custom_word ORDER BY word ASC")
            findReplaceRules = try FindReplaceRule.fetchAll(db, sql: "SELECT * FROM find_replace_rule ORDER BY orderIndex ASC, id ASC")
            aiVocabularyTerms = try AIVocabularyTerm.fetchAll(db, sql: "SELECT * FROM ai_vocabulary_term ORDER BY term ASC")
        }
    }

    // MARK: - Custom Words

    func addCustomWord(_ word: String, notes: String? = nil) throws {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO custom_word (word, notes, createdAt) VALUES (?, ?, ?)",
                arguments: [trimmed, notes, Date()]
            )
        }
        try reload()
        // Loguj tylko fakt - treść słownika prywatna
        Log.vocabulary.info("Added custom word (\(trimmed.count, privacy: .public) chars)")
    }

    func deleteCustomWord(id: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM custom_word WHERE id = ?", arguments: [id])
        }
        try reload()
    }

    // MARK: - Find & Replace

    func addFindReplaceRule(
        find: String,
        replace: String,
        isRegex: Bool = false,
        caseSensitive: Bool = false
    ) throws {
        guard !find.isEmpty else { return }
        let nextIndex = (findReplaceRules.last?.orderIndex ?? -1) + 1
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO find_replace_rule (findText, replaceWith, isRegex, caseSensitive, orderIndex, createdAt)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [find, replace, isRegex, caseSensitive, nextIndex, Date()]
            )
        }
        try reload()
        Log.vocabulary.info("Added find&replace rule (find=\(find.count, privacy: .public) chars, replace=\(replace.count, privacy: .public) chars, regex=\(isRegex, privacy: .public))")
    }

    func deleteFindReplaceRule(id: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM find_replace_rule WHERE id = ?", arguments: [id])
        }
        try reload()
    }

    // MARK: - AI Vocabulary

    func addAIVocabularyTerm(_ term: String, notes: String? = nil) throws {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO ai_vocabulary_term (term, notes, createdAt) VALUES (?, ?, ?)",
                arguments: [trimmed, notes, Date()]
            )
        }
        try reload()
        Log.vocabulary.info("Added AI vocab term (\(trimmed.count, privacy: .public) chars)")
    }

    func deleteAIVocabularyTerm(id: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM ai_vocabulary_term WHERE id = ?", arguments: [id])
        }
        try reload()
    }

    // MARK: - Eksport / Import (backup + sync między urządzeniami)

    /// Eksport całego słownika do JSON.
    /// Format: { customWords: [...], findReplaceRules: [...], aiVocabularyTerms: [...] }
    func exportToJSON() throws -> Data {
        let snapshot = VocabularySnapshot(
            version: 1,
            exportedAt: Date(),
            customWords: customWords,
            findReplaceRules: findReplaceRules,
            aiVocabularyTerms: aiVocabularyTerms
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    /// Import z JSON. Tryb append - **dodaje** do istniejącego słownika.
    /// Jeśli `replace == true` - czyści tabele przed importem.
    func importFromJSON(_ data: Data, replace: Bool = false) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(VocabularySnapshot.self, from: data)

        try dbQueue.write { db in
            if replace {
                try db.execute(sql: "DELETE FROM custom_word")
                try db.execute(sql: "DELETE FROM find_replace_rule")
                try db.execute(sql: "DELETE FROM ai_vocabulary_term")
            }

            for word in snapshot.customWords {
                try db.execute(
                    sql: "INSERT INTO custom_word (word, notes, createdAt) VALUES (?, ?, ?)",
                    arguments: [word.word, word.notes, word.createdAt]
                )
            }
            for rule in snapshot.findReplaceRules {
                try db.execute(
                    sql: """
                    INSERT INTO find_replace_rule (findText, replaceWith, isRegex, caseSensitive, orderIndex, createdAt)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [rule.findText, rule.replaceWith, rule.isRegex, rule.caseSensitive, rule.orderIndex, rule.createdAt]
                )
            }
            for term in snapshot.aiVocabularyTerms {
                try db.execute(
                    sql: "INSERT INTO ai_vocabulary_term (term, notes, createdAt) VALUES (?, ?, ?)",
                    arguments: [term.term, term.notes, term.createdAt]
                )
            }
        }
        try reload()
        Log.vocabulary.info("""
            Imported: \(snapshot.customWords.count, privacy: .public) words, \
            \(snapshot.findReplaceRules.count, privacy: .public) rules, \
            \(snapshot.aiVocabularyTerms.count, privacy: .public) AI terms (replace=\(replace, privacy: .public))
            """)
    }

    /// Zwraca URL folderu z danymi aplikacji (vocabulary.db i inne).
    static func dataFolderURL() -> URL? {
        try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("PolskiWhisper", isDirectory: true)
    }

    // MARK: - Helpers

    private static func databaseFileURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = support.appendingPathComponent("PolskiWhisper", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vocabulary.db")
    }
}

// MARK: - Snapshot (eksport/import format)

private struct VocabularySnapshot: Codable {
    let version: Int
    let exportedAt: Date
    let customWords: [VocabularyStore.CustomWord]
    let findReplaceRules: [VocabularyStore.FindReplaceRule]
    let aiVocabularyTerms: [VocabularyStore.AIVocabularyTerm]
}

// MARK: - GRDB protocol conformances

extension VocabularyStore.CustomWord: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String { "custom_word" }
}

extension VocabularyStore.FindReplaceRule: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String { "find_replace_rule" }
}

extension VocabularyStore.AIVocabularyTerm: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String { "ai_vocabulary_term" }
}
