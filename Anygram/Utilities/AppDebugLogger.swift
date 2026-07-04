import Combine
import Foundation

/// File-backed debug logger with a tiny in-memory ring buffer for crash context.
final class AppDebugLogger: ObservableObject {
    static let shared = AppDebugLogger()

    static let ringBufferLineLimit = 100
    private static let maxLogFileBytes = 2 * 1024 * 1024
    private static let logFileName = "anygram-debug.log"

    enum Category: String, Sendable, CaseIterable {
        case PROXY
        case TDLIB
        case AUTH
        case NETWORK
        case CHAT
        case UI
        case ERROR
    }

    @Published private(set) var revision: UInt64 = 0

    private let lock = NSLock()
    private var ringBuffer: [String] = []
    private var pendingFileLines: [String] = []
    private var flushWorkItem: DispatchWorkItem?
    private let fileQueue = DispatchQueue(label: "com.anygram.debuglog.file", qos: .utility)
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {}

    func log(_ message: String, category: Category) {
        let stamp = formatter.string(from: Date())
        let line = "\(stamp) [\(category.rawValue)] \(message)"

        lock.lock()
        ringBuffer.append(line)
        if ringBuffer.count > Self.ringBufferLineLimit {
            ringBuffer.removeFirst(ringBuffer.count - Self.ringBufferLineLimit)
        }
        pendingFileLines.append(line)
        lock.unlock()

        scheduleFileFlush()
        scheduleRevisionUpdate()
    }

    func recentLines(_ count: Int = 3) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(ringBuffer.suffix(count))
    }

    func recentErrors(_ count: Int = 8) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(
            ringBuffer.filter {
                $0.contains("[ERROR]")
                    || $0.localizedCaseInsensitiveContains("failed")
                    || $0.localizedCaseInsensitiveContains("timeout")
            }
            .suffix(count)
        )
    }

    func logFileURL() -> URL {
        documentsDirectory().appendingPathComponent(Self.logFileName)
    }

    func logFileByteCount() -> Int {
        let url = logFileURL()
        return (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    }

    /// Forces any buffered lines to disk before sharing the log file.
    func flushNow() {
        flushPendingLinesToFile()
    }

    func clear() {
        lock.lock()
        ringBuffer.removeAll(keepingCapacity: true)
        pendingFileLines.removeAll(keepingCapacity: true)
        lock.unlock()

        fileQueue.async {
            let url = self.logFileURL()
            try? Data().write(to: url, options: .atomic)
        }
        scheduleRevisionUpdate(immediate: true)
    }

    // MARK: - Private

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func scheduleFileFlush() {
        fileQueue.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let shouldSchedule = self.flushWorkItem == nil
            if shouldSchedule {
                let work = DispatchWorkItem { [weak self] in
                    self?.flushPendingLinesToFile()
                }
                self.flushWorkItem = work
                self.lock.unlock()
                self.fileQueue.asyncAfter(deadline: .now() + 0.25, execute: work)
            } else {
                self.lock.unlock()
            }
        }
    }

    private func flushPendingLinesToFile() {
        lock.lock()
        let lines = pendingFileLines
        pendingFileLines.removeAll(keepingCapacity: true)
        flushWorkItem = nil
        lock.unlock()

        guard !lines.isEmpty else { return }

        let payload = lines.joined(separator: "\n") + "\n"
        guard let data = payload.data(using: .utf8) else { return }

        let url = logFileURL()
        fileQueue.async {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: url, options: .atomic)
            }
            self.truncateLogFileIfNeeded(at: url)
        }
    }

    private func truncateLogFileIfNeeded(at url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int,
              size > Self.maxLogFileBytes,
              let handle = try? FileHandle(forReadingFrom: url) else { return }

        defer { try? handle.close() }
        let keepBytes = Self.maxLogFileBytes / 2
        try? handle.seek(toOffset: UInt64(size - keepBytes))
        let tail = handle.readDataToEndOfFile()
        try? tail.write(to: url, options: .atomic)
    }

    private func scheduleRevisionUpdate(immediate: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if immediate {
                self.revision &+= 1
                return
            }
            self.revision &+= 1
        }
    }
}

#if canImport(TDLibKit)
import TDLibKit

/// Routes only TDLibKit errors into `AppDebugLogger` to avoid log floods.
final class AppTDLibLogger: TDLibLogger, @unchecked Sendable {
    static let shared = AppTDLibLogger()

    private init() {}

    func log(_ message: String, type: LoggerMessageType?) {
        guard type == .error || type == .fatal else { return }
        let prefix = type.map { "[\($0.description)] " } ?? ""
        AppDebugLogger.shared.log("\(prefix)\(message)", category: .TDLIB)
    }
}
#endif
