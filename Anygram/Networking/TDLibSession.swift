import Foundation

#if canImport(TDLibKit)
import TDLibKit

/*
 AUTH INIT ORDER (matches BetterTG):
 1. createClient + register auth update handler
 2. setLogStream (bootstrap task, non-blocking)
 3. on authorizationStateWaitTdlibParameters → setTdlibParameters
 4. after setTdlibParameters OK → addProxy (never before — blocks queryQueue)
 5. on authorizationStateWaitPhoneNumber → bootstrapComplete
 BetterTG avoids blocking login on proxy; addProxy failures are non-fatal.
*/

/// Shared TDLib client lifecycle — mirrors BetterTG `TDLib.swift` bootstrap.
public final class TDLibSession: @unchecked Sendable {
    public static let shared = TDLibSession()

    static let sessionResetNotification = Notification.Name("anygram.tdlib.sessionReset")

    private let lock = NSLock()
    private var manager: TDLibClientManager?
    private var client: TDLibClient?
    /// Single auth handler — registered once from TDLibAuthBackend.init.
    private var primaryUpdateHandler: ((Data, TDLibClient) -> Void)?
    private var bootstrapStarted = false
    private var bootstrapTask: Task<Void, Never>?
    private var bootstrapComplete = false
    private var bootstrapWaiters: [CheckedContinuation<Void, Never>] = []

    private init() {}

    public var tdClient: TDLibClient? {
        lock.lock()
        defer { lock.unlock() }
        return client
    }

    /// True after TDLib reaches authorizationStateWaitPhoneNumber (safe to submit phone / call gated APIs).
    public var isReady: Bool {
        lock.withLock { bootstrapComplete }
    }

    /// Register the auth update handler once — must run before chat/user services init (TDLibAuthBackend.init).
    public func registerAuthUpdateHandler(_ handler: @escaping (Data, TDLibClient) -> Void) {
        lock.lock()
        primaryUpdateHandler = handler
        lock.unlock()
        AppDebugLogger.shared.log("registerAuthUpdateHandler", category: .TDLIB)
    }

    /// Create TDLib client using the previously registered auth handler.
    @discardableResult
    public func ensureClient() -> TDLibClient {
        lock.lock()
        let handler = primaryUpdateHandler
        lock.unlock()
        guard let handler else {
            AppDebugLogger.shared.log("FATAL: ensureClient() without registerAuthUpdateHandler", category: .ERROR)
            fatalError("Call registerAuthUpdateHandler before ensureClient()")
        }
        return ensureClient(updateHandler: handler)
    }

    /// BetterTG: create client + register update handler before any TDLib calls.
    @discardableResult
    public func ensureClient(updateHandler: @escaping (Data, TDLibClient) -> Void) -> TDLibClient {
        TelegramAPIConfiguration.performStorageMigrationIfNeeded()

        lock.lock()
        if primaryUpdateHandler == nil {
            primaryUpdateHandler = updateHandler
        }

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
        bootstrapComplete = false
        let waiters = bootstrapWaiters
        bootstrapWaiters = []
        let activeClient = client
        lock.unlock()

        for waiter in waiters {
            waiter.resume()
        }

        TDLibProxyApplier.resetAppliedProxy()
        TDLibAccessGate.shared.reset()
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
        bootstrapComplete = false
        bootstrapWaiters = []
        lock.unlock()
        TDLibProxyApplier.resetAppliedProxy()
        TDLibAccessGate.shared.reset()
    }

    private func dispatchUpdate(data: Data, client: TDLibClient) {
        lock.lock()
        let handler = primaryUpdateHandler
        lock.unlock()
        handler?(data, client)
        TDLibUpdateRouter.shared.route(data: data, client: client)
    }

    /// BetterTG: setLogStream only — addProxy runs after setTdlibParameters in auth backend.
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
            AppDebugLogger.shared.log("bootstrap: setLogStream phase done", category: .TDLIB)
        }
    }

    func markBootstrapComplete() {
        lock.lock()
        guard !bootstrapComplete else {
            lock.unlock()
            return
        }
        bootstrapComplete = true
        let waiters = bootstrapWaiters
        bootstrapWaiters = []
        lock.unlock()
        AppDebugLogger.shared.log("bootstrapComplete=true (waitPhoneNumber)", category: .TDLIB)
        for waiter in waiters {
            waiter.resume()
        }
    }

    public func awaitBootstrap(timeout: TimeInterval = 8) async throws {
        if isReady {
            AppDebugLogger.shared.log("awaitBootstrap: already complete", category: .TDLIB)
            return
        }

        let logStreamTask = lock.withLock { bootstrapTask }
        if let logStreamTask {
            AppDebugLogger.shared.log("awaitBootstrap: waiting for setLogStream task", category: .TDLIB)
            try? await AsyncTimeout.withTimeout(seconds: 3, error: AuthError.stillStarting) {
                await logStreamTask.value
            }
        }

        if isReady {
            AppDebugLogger.shared.log("awaitBootstrap: done (ready during setLogStream)", category: .TDLIB)
            return
        }

        AppDebugLogger.shared.log("awaitBootstrap: waiting up to \(Int(timeout))s for waitPhoneNumber", category: .TDLIB)
        try await AsyncTimeout.withTimeout(seconds: timeout, error: AuthError.stillStarting) {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                self.lock.lock()
                if self.bootstrapComplete {
                    self.lock.unlock()
                    continuation.resume()
                    return
                }
                self.bootstrapWaiters.append(continuation)
                self.lock.unlock()
            }
        }
        guard isReady else {
            throw AuthError.stillStarting
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
