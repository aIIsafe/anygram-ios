import Foundation

/// Contract for in-memory and disk image caching.
public protocol ImageCacheProtocol: Sendable {
    func image(for key: String) async -> Data?
    func store(_ data: Data, for key: String) async
    func remove(for key: String) async
    func clearAll() async
}
