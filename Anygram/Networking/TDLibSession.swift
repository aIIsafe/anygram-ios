import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Shared TDLib client lifecycle — mirrors BetterTG `TDLib.swift` bootstrap.
public final class TDLibSession: @unchecked Sendable {
    public static let shared = TDLibSession()

    private let lock = NSLock()
    private var manager: TDLibClientManager?
    private var client: TDLibClient?
    private var updateHandlers: [(Data, TDLibClient) -> Void] = []
    private var bootstrapStarted = false

    private init() {}

    public var tdClient: TDLibClient? {
        lock.lock()
        defer { lock.unlock() }
        return client
    }

    @discardableResult
    public func ensureClient(updateHandler: @escaping (Data, TDLibClient) -> Void) -> TDLibClient {
        lock.lock()
        updateHandlers.append(updateHandler)
        if manager == nil {
            manager = TDLibClientManager()
        }
        if client == nil, let manager {
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
            fatalError("TDLib client failed to initialize")
        }
        return activeClient
    }

    public func close() {
        lock.lock()
        manager?.closeClients()
        client = nil
        manager = nil
        updateHandlers.removeAll()
        bootstrapStarted = false
        bootstrapTask = nil
        lock.unlock()
    }

    private func dispatchUpdate(data: Data, client: TDLibClient) {
        lock.lock()
        let handlers = updateHandlers
        lock.unlock()
        for handler in handlers {
            handler(data, client)
        }
        TDLibUpdateRouter.shared.route(data: data, client: client)
    }

    /// BetterTG applies proxy and silences logs before auth parameters.
    private var bootstrapTask: Task<Void, Never>?

    private func startBootstrap(client: TDLibClient) {
        bootstrapTask = Task {
            try? await client.setLogStream(logStream: .logStreamEmpty) { _ in }
            await TDLibProxyApplier.applyForcedProxy(client: client)
        }
    }

    public func awaitBootstrap() async {
        await bootstrapTask?.value
    }
}
#endif
