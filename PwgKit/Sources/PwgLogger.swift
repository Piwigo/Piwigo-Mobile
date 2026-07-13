//
//  PwgLogger.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 13/07/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import os

// MARK: - Log Entry
/// Entry of a log file stored in the Logs directory of the AppGroup container
public struct PwgLogEntry: Sendable {
    public let date: Date
    public let level: String
    public let category: String
    public let message: String
}


// MARK: - Logger
/// Logs messages with the unified logging system and appends them to a file
/// stored in the Logs directory of the AppGroup container so that:
/// - logs can be presented quickly in the Troubleshooting view of the app,
///   i.e. without enumerating the OSLogStore which is far too slow,
/// - logs produced by the extensions can be presented by the app,
///   which the OSLogStore does not allow (process-scoped on iOS).
public final class PwgLogger: @unchecked Sendable {

    /// Log files are rotated when they exceed this size (one "-old" generation is kept)
    private static let maxFileSize = UInt64(1_000_000)
    static let fileExtension = "log"
    static let oldSuffix = "-old"

    /// Date formatter of the log file entries
    nonisolated(unsafe) static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let osLogger: Logger
    private let category: String
    private let fileURL: URL
    private let queue: DispatchQueue           // Serialises writes of this logger
    private var fileHandle: FileHandle?        // Only accessed from the above queue

    public init(subsystem: String, category: String) {
        self.osLogger = Logger(subsystem: subsystem, category: category)
        self.category = category
        // One file per subsystem and process (e.g. "org.piwigo.uploadKit@piwigo.log")
        // so that the app and the extensions never write to the same file.
        let processName = ProcessInfo.processInfo.processName
        self.fileURL = DataDirectories.appLogsDirectory
            .appendingPathComponent(subsystem + "@" + processName)
            .appendingPathExtension(PwgLogger.fileExtension)
        self.queue = DispatchQueue(label: subsystem + "." + category + ".logger", qos: .utility)
    }


    // MARK: - Logging
    /// Debug messages are neither logged nor stored in release builds
    public func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        let msg = message()
        osLogger.debug("\(msg, privacy: .public)")
        append(level: "debug", message: msg)
        #endif
    }

    public func notice(_ message: String) {
        osLogger.notice("\(message, privacy: .public)")
        append(level: "notice", message: message)
    }

    public func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        append(level: "error", message: message)
    }

    public func fault(_ message: String) {
        osLogger.fault("\(message, privacy: .public)")
        append(level: "fault", message: message)
    }


    // MARK: - Log File Writing
    private func append(level: String, message: String) {
        let date = Date()
        queue.async { [self] in
            // Compose the log file line (newlines are escaped to keep one line per entry)
            let escapedMsg = message.replacingOccurrences(of: "\n", with: "\\n")
            let line = [PwgLogger.dateFormatter.string(from: date), level, category, escapedMsg]
                .joined(separator: "\t") + "\n"
            guard let data = line.data(using: .utf8) else { return }

            // Open the log file if not already done
            /// O_APPEND so that each write is atomically performed at the end of the file
            if fileHandle == nil {
                let fd = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
                guard fd >= 0 else { return }
                fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            }

            // Append the entry to the log file
            guard let fileHandle = fileHandle,
                  let _ = try? fileHandle.write(contentsOf: data)
            else { return }

            // Rotate the log file when it exceeds the maximum size
            /// With O_APPEND, the offset corresponds to the file size after a write.
            if let fileSize = try? fileHandle.offset(), fileSize > PwgLogger.maxFileSize {
                try? fileHandle.close()
                self.fileHandle = nil
                let oldFileURL = fileURL.deletingPathExtension()
                    .appendingPathExtension(PwgLogger.oldSuffix + "." + PwgLogger.fileExtension)
                try? FileManager.default.removeItem(at: oldFileURL)
                try? FileManager.default.moveItem(at: fileURL, to: oldFileURL)
            }
        }
    }


    // MARK: - Log File Reading
    /// Returns the entries of all log files stored in the AppGroup container, ignoring
    /// entries older than the given date, grouped by category in chronological order.
    public static func logEntries(since cutoffDate: Date) -> [String: [PwgLogEntry]] {
        // Get the list of log files
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: DataDirectories.appLogsDirectory,
                                                      includingPropertiesForKeys: nil,
                                                      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        else { return [:] }

        // Collect the entries of all log files
        var logsByCategory = [String: [PwgLogEntry]]()
        for file in files where file.pathExtension == PwgLogger.fileExtension {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n") {
                let fields = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
                guard fields.count == 4,
                      let date = PwgLogger.dateFormatter.date(from: String(fields[0])),
                      date >= cutoffDate
                else { continue }
                let message = String(fields[3]).replacingOccurrences(of: "\\n", with: "\n")
                let entry = PwgLogEntry(date: date, level: String(fields[1]),
                                        category: String(fields[2]), message: message)
                logsByCategory[entry.category, default: []].append(entry)
            }
        }

        // Sort entries by date (a category may originate from several processes/files)
        return logsByCategory.mapValues { $0.sorted(by: { $0.date < $1.date }) }
    }

    /// Deletes all log files stored in the AppGroup container
    public static func deleteLogFiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: DataDirectories.appLogsDirectory,
                                                      includingPropertiesForKeys: nil,
                                                      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        else { return }
        for file in files where file.pathExtension == PwgLogger.fileExtension {
            try? fm.removeItem(at: file)
        }
    }
}
