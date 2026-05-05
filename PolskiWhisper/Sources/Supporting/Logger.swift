//
//  Logger.swift
//  PolskiWhisper
//
//  Copyright © 2026 Marcin Werner. Licensed under the MIT License.
//  See LICENSE in the repository root.
//

import Foundation
import os

/// Centralized logging facade. Use instead of `print()`.
///
/// Usage:
/// ```swift
/// Log.dictation.info("Started recording")
/// Log.whisper.error("Model load failed: \(error.localizedDescription, privacy: .public)")
/// ```
///
/// All loggers share the subsystem `pl.polskiwhisper.app`. Filter by subsystem in Console.app
/// to see all PolskiWhisper logs.
///
/// Privacy guarantee: logs use `os.Logger` which is system-managed. Treść transkrypcji NIE jest
/// nigdy logowana - tylko metadane (długość audio, model name, error categories).
enum Log {
    private static let subsystem = "pl.polskiwhisper.app"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let coordinator = Logger(subsystem: subsystem, category: "Coordinator")
    static let menuBar = Logger(subsystem: subsystem, category: "MenuBar")
    static let hotkey = Logger(subsystem: subsystem, category: "Hotkey")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let whisper = Logger(subsystem: subsystem, category: "Whisper")
    static let ollama = Logger(subsystem: subsystem, category: "Ollama")
    static let vocabulary = Logger(subsystem: subsystem, category: "Vocabulary")
    static let paste = Logger(subsystem: subsystem, category: "Paste")
    static let permissions = Logger(subsystem: subsystem, category: "Permissions")
    static let dictation = Logger(subsystem: subsystem, category: "Dictation")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
}
