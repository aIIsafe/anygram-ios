import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Routes TDLib updates to registered handlers (BetterTG-style centralized dispatch).
final class TDLibUpdateRouter: @unchecked Sendable {
    static let shared = TDLibUpdateRouter()

    typealias UpdateHandler = @Sendable (Update) -> Void

    private let lock = NSLock()
    private var handlers: [UUID: UpdateHandler] = [:]

    private init() {}

    @discardableResult
    func addHandler(_ handler: @escaping UpdateHandler) -> UUID {
        let id = UUID()
        lock.lock()
        handlers[id] = handler
        lock.unlock()
        return id
    }

    func removeHandler(_ id: UUID) {
        lock.lock()
        handlers.removeValue(forKey: id)
        lock.unlock()
    }

    func route(data: Data, client: TDLibClient) {
        guard let update = try? client.decoder.decode(Update.self, from: data) else { return }
        lock.lock()
        let snapshot = handlers.values
        lock.unlock()
        for handler in snapshot {
            handler(update)
        }
    }
}
#endif
