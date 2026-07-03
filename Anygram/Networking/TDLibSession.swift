import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Shared TDLib client used by auth, user, and future chat services.
public final class TDLibSession: @unchecked Sendable {
    public static let shared = TDLibSession()

    private let lock = NSLock()
    private var manager: TDLibClientManager?
    private var client: TDLibClient?
    private var updateHandler: ((Data, TDLibClient) -> Void)?

    private init() {}

    public var tdClient: TDLibClient? {
        lock.lock()
        defer { lock.unlock() }
        return client
    }

    @discardableResult
    public func ensureClient(updateHandler: @escaping (Data, TDLibClient) -> Void) -> TDLibClient {
        lock.lock()
        defer { lock.unlock() }
        self.updateHandler = updateHandler
        if manager == nil {
            manager = TDLibClientManager()
        }
        if client == nil, let manager {
            client = manager.createClient { [weak self] data, tdClient in
                self?.updateHandler?(data, tdClient)
            }
        }
        guard let client else {
            fatalError("TDLib client failed to initialize")
        }
        return client
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        manager?.closeClients()
        client = nil
        manager = nil
        updateHandler = nil
    }
}
#endif
