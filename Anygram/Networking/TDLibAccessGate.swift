import Foundation

#if canImport(TDLibKit)

/// Gates TDLib API calls and chat update processing until auth bootstrap completes.
final class TDLibAccessGate: @unchecked Sendable {
    static let shared = TDLibAccessGate()

    private let lock = NSLock()
    private var parametersApplied = false
    private var isAuthorized = false

    private init() {}

    var canCallAuthenticatedAPI: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isAuthorized
    }

    var canProcessChatUpdates: Bool {
        areParametersApplied
    }

    var areParametersApplied: Bool {
        lock.lock()
        defer { lock.unlock() }
        return parametersApplied
    }

    func markParametersApplied() {
        lock.lock()
        parametersApplied = true
        lock.unlock()
        AppDebugLogger.shared.log("TDLibAccessGate: parametersApplied=true", category: .TDLIB)
    }

    func markAuthorized() {
        lock.lock()
        parametersApplied = true
        isAuthorized = true
        lock.unlock()
        AppDebugLogger.shared.log("TDLibAccessGate: authorized=true", category: .TDLIB)
    }

    func reset() {
        lock.lock()
        parametersApplied = false
        isAuthorized = false
        lock.unlock()
        AppDebugLogger.shared.log("TDLibAccessGate: reset", category: .TDLIB)
    }
}
#endif
