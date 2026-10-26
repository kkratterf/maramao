import Foundation
import MaramaoCore
import os

/// Logs to the system log (`os.Logger`) and keeps the last lines in memory for
/// "Segnala un problema". Nothing is written to disk.
///
/// Only pass fixed messages and numbers: the lines end up in a bug report the user
/// may publish, so never log names, paths or anything the user typed.
final class DiagnosticLog: @unchecked Sendable {
    static let shared = DiagnosticLog()

    /// Break lifecycle: watchdog, emergency exit, stray windows.
    static let breaks = Channel(category: "breaks")
    /// Pomodoro phases and previews.
    static let engine = Channel(category: "engine")

    private let lock = NSLock()
    private var ring = LogRing()
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// The in-memory lines, oldest first.
    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return ring.lines
    }

    fileprivate func record(_ level: String, _ category: String, _ message: String) {
        lock.lock()
        defer { lock.unlock() }
        ring.append("\(formatter.string(from: Date())) [\(category)] \(level)\(message)")
    }

    /// One `os.Logger` category that also feeds the in-memory log.
    struct Channel {
        let category: String
        private let logger: Logger

        init(category: String) {
            self.category = category
            self.logger = Logger(subsystem: "com.kkratterf.maramao", category: category)
        }

        func notice(_ message: String) {
            logger.notice("\(message, privacy: .public)")
            DiagnosticLog.shared.record("", category, message)
        }

        func error(_ message: String) {
            logger.error("\(message, privacy: .public)")
            DiagnosticLog.shared.record("error: ", category, message)
        }
    }
}
