import Foundation

#if canImport(TDLibKit)
import TDLibKit

/*
 AUTH HANG ANALYSIS — await points that can block indefinitely without timeout:
 1. client.setLogStream — bootstrapped with 8s timeout in startBootstrap
 2. client.addProxy (TDLibProxyApplier) — 5s timeout per candidate
 3. client.setTdlibParameters — 10s timeout in TDLibAuthBackend.applyTdlibParameters
 4. client.getAuthorizationState — 5s timeout at each call site in auth backend
 5. client.setAuthenticationPhoneNumber — 12s timeout inside 15s submit flow
 6. waitForPhoneNumberState poll loop — capped at 12s (was 30s, caused login hang)
 7. awaitBootstrap — 8s timeout
 BetterTG avoids (6) entirely: TDLib starts at app launch; login only calls getAuthorizationState + setAuthenticationPhoneNumber.
 TDLibKit serializes sends on per-client queryQueue; updates on updateHandlerQueue — no extra queue needed if we don't block MainActor.
*/

/// Shared TDLib client lifecycle — mirrors BetterTG `TDLib.swift` bootstrap.
public final class TDLibSession: @unchecked Sendable {
    public static let shared = TDLibSession()

    static let sessionResetNotification = Notification.Name("anygram.tdlib.sessionReset")

    private let lock = NSLock()
    private var manager: TDLibClientManager?
    private var client: TDLibClient?
    /// Single auth handler — BetterTG registers one update handler at client creation.
    private var primaryUpdateHandler: ((Data, TDLibClient) -> Void)?
    private var bootstrapStarted = false
    private var bootstrapTask: Task<Void, Never>?
    private var bootstrapError: AuthError?

    private init() {}

    public var tdClient: TDLibClient? {
        lock.lock()
        defer { lock.unlock() }
        return client
    }

    /// BetterTG: create client + register update handler before any TDLib calls.
    @discardableResult
    public func ensureClient(updateHandler: @escaping (Data, TDLibClient) -> Void) -> TDLibClient {
        lock.lock()
        primaryUpdateHandler = updateHandler

        if manager == nil {
            AppDebugLogger.shared.log("TDLibClientManager create", category: .TDLIB)
            manager = TDLibClientManager(logger: AppTDLibLogger.shared)
        }
        if client == nil, let manager {
            AppDebugLogger.shared.log("createClient + register updateHandler", category: .TDLIB)
            client = manager.createClient { [weak self] data, tdClient in
                self?.dispatchUpdate(data: data, client: tdClient)
            }
        }
        let activeClient = client
        let shouldBootstrap = client != nil && !bootstrapStarted
        if shouldBootstrap {
            bootstrapStarted = true
        }
        lock.unlock()

        if shouldBootstrap, let activeClient {
            startBootstrap(client: activeClient)
        }

        guard let activeClient else {
            AppDebugLogger.shared.log("FATAL: TDLib client nil after ensureClient", category: .ERROR)
            fatalError("TDLib client failed to initialize")
        }
        return activeClient
    }

    /// BetterTG starts TDLib in app init — warm up early so auth is not blocked on first tap.
    public func warmUp(updateHandler: @escaping (Data, TDLibClient) -> Void) {
        AppDebugLogger.shared.log("warmUp: ensureClient", category: .TDLIB)
        _ = ensureClient(updateHandler: updateHandler)
    }

    /// Destroy and recreate client when auth is stuck (stale client from failed attempt).
    public func resetClient() {
        lock.lock()
        AppDebugLogger.shared.log("resetClient: closeClients + recreate", category: .TDLIB)
        manager?.closeClients()
        manager = TDLibClientManager(logger: AppTDLibLogger.shared)
        client = manager?.createClient { [weak self] data, tdClient in
            self?.dispatchUpdate(data: data, client: tdClient)
        }
        bootstrapStarted = false
        bootstrapTask = nil
        bootstrapError = nil
        let activeClient = client
        lock.unlock()

        TDLibProxyApplier.resetAppliedProxy()
        NotificationCenter.default.post(name: Self.sessionResetNotification, object: nil)

        if let activeClient {
            lock.lock()
            bootstrapStarted = true
            lock.unlock()
            startBootstrap(client: activeClient)
        }
    }

    public func close() {
        lock.lock()
        AppDebugLogger.shared.log("close: shutting down TDLib", category: .TDLIB)
        manager?.closeClients()
        client = nil
        manager = nil
        primaryUpdateHandler = nil
        bootstrapStarted = false
        bootstrapTask = nil
        bootstrapError = nil
        lock.unlock()
        TDLibProxyApplier.resetAppliedProxy()
    }

    private func dispatchUpdate(data: Data, client: TDLibClient) {
        lock.lock()
        let handler = primaryUpdateHandler
        lock.unlock()
        handler?(data, client)
        TDLibUpdateRouter.shared.route(data: data, client: client)
    }

    /// BetterTG: setLogStream + addProxy once at startup — never block login on proxy ping.
    private func startBootstrap(client: TDLibClient) {
        bootstrapTask = Task {
            let start = Date()
            AppDebugLogger.shared.log("bootstrap start: setLogStream", category: .TDLIB)
            do {
                try await AsyncTimeout.withTimeout(seconds: 8, error: AuthError.stillStarting) {
                    try await client.setLogStream(logStream: .logStreamEmpty) { _ in }
                }
                AppDebugLogger.shared.log("setLogStream OK (\(Int(Date().timeIntervalSince(start) * 1000))ms)", category: .TDLIB)
                _ = try? await client.setLogVerbosityLevel(newVerbosityLevel: 1)
            } catch {
                AppDebugLogger.shared.log("setLogStream FAILED: \(error.localizedDescription)", category: .ERROR)
            }

            let proxyStart = Date()
            AppDebugLogger.shared.log("bootstrap: addProxy", category: .PROXY)
            await TDLibProxyApplier.applyDefaultProxy(client: client)
            AppDebugLogger.shared.log("bootstrap complete (\(Int(Date().timeIntervalSince(proxyStart) * 1000))ms proxy phase)", category: .TDLIB)
        }
    }

    public func awaitBootstrap(timeout: TimeInterval = 8) async throws {
        let task = lock.withLock { bootstrapTask }
        guard let task else {
            AppDebugLogger.shared.log("awaitBootstrap: no bootstrap task (already done or not started)", category: .TDLIB)
            return
        }
        AppDebugLogger.shared.log("awaitBootstrap: waiting up to \(Int(timeout))s", category: .TDLIB)
        try await AsyncTimeout.withTimeout(seconds: timeout, error: AuthError.stillStarting) {
            await task.value
        }
        if let bootstrapError = lock.withLock({ bootstrapError }) {
            throw bootstrapError
        }
        AppDebugLogger.shared.log("awaitBootstrap: done", category: .TDLIB)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
#endif
