import Combine
import Foundation

/// Thread-safe in-memory debug log ring buffer (temporary auth diagnostics).
final class AppDebugLogger: ObservableObject {
    static let shared = AppDebugLogger()

    static let displayLineLimit = 200
    static let displayCategoryLineLimit = 100

    enum Category: String, Sendable, CaseIterable {
        case PROXY
        case TDLIB
        case AUTH
        case NETWORK
        case CHAT
        case UI
        case ERROR
    }

    struct Snapshot: Sendable {
        let linesByCategory: [Category: [String]]
        let exportText: String
        let recentErrors: [String]
        let totalLineCount: Int
    }

    @Published private(set) var revision: UInt64 = 0

    private let lock = NSLock()
    private var lines: [String] = []
    private let maxLines = 5000
    private var revisionWorkItem: DispatchWorkItem?
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
        scheduleRevisionUpdate()
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
        return exportTextLocked(maxLines: lines.count)
    }

    func lines(for category: Category) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return filteredLines(for: category, maxLines: lines.count)
    }

    func recentErrors(_ count: Int = 20) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return recentErrorsLocked(count)
    }

    func makeSnapshot(
        maxPerCategory: Int = displayCategoryLineLimit,
        maxExportLines: Int = displayLineLimit,
        recentErrorCount: Int = 8
    ) -> Snapshot {
        lock.lock()
        defer { lock.unlock() }

        var linesByCategory: [Category: [String]] = [:]
        for category in Category.allCases {
            linesByCategory[category] = filteredLines(for: category, maxLines: maxPerCategory)
        }

        return Snapshot(
            linesByCategory: linesByCategory,
            exportText: exportTextLocked(maxLines: maxExportLines),
            recentErrors: recentErrorsLocked(recentErrorCount),
            totalLineCount: lines.count
        )
    }

    func clear() {
        lock.lock()
        lines.removeAll(keepingCapacity: true)
        lock.unlock()
        scheduleRevisionUpdate(immediate: true)
    }

    // MARK: - Private

    private func scheduleRevisionUpdate(immediate: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.revisionWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.revision &+= 1
            }
            self.revisionWorkItem = work
            if immediate {
                work.perform()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
            }
        }
    }

    private func filteredLines(for category: Category, maxLines: Int) -> [String] {
        let tag = "[\(category.rawValue)]"
        return Array(lines.filter { $0.contains(tag) }.suffix(maxLines))
    }

    private func exportTextLocked(maxLines: Int) -> String {
        Array(lines.suffix(maxLines)).joined(separator: "\n")
    }

    private func recentErrorsLocked(_ count: Int) -> [String] {
        Array(
            lines.filter { $0.contains("[ERROR]") || $0.contains("FAILED") || $0.contains("failed") }
                .suffix(count)
        )
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
