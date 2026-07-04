import Combine
import Foundation

/// Thread-safe in-memory debug log ring buffer (temporary auth diagnostics).
final class AppDebugLogger: ObservableObject {
    static let shared = AppDebugLogger()

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
    private var lines: [String] = []
    private let maxLines = 5000
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
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.revision &+= 1
        }
    }

    func recentLines(_ count: Int = 3) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(lines.suffix(count))
    }

    func allLines() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }

    func exportText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }

    func lines(for category: Category) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let tag = "[\(category.rawValue)]"
        return lines.filter { $0.contains(tag) }
    }

    func recentErrors(_ count: Int = 20) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(
            lines.filter { $0.contains("[ERROR]") || $0.contains("FAILED") || $0.contains("failed") }
                .suffix(count)
        )
    }

    func clear() {
        lock.lock()
        lines.removeAll(keepingCapacity: true)
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.revision &+= 1
        }
    }
}

#if canImport(TDLibKit)
import TDLibKit

/// Routes TDLibKit transport logs into `AppDebugLogger`.
final class AppTDLibLogger: TDLibLogger, @unchecked Sendable {
    static let shared = AppTDLibLogger()

    private init() {}

    func log(_ message: String, type: LoggerMessageType?) {
        let prefix = type.map { "[\($0.description)] " } ?? ""
        AppDebugLogger.shared.log("\(prefix)\(message)", category: .TDLIB)
    }
}
#endif
