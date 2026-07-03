import Foundation

/// Contract for media and image caching operations.
public protocol MediaServiceProtocol: Sendable {
    func fetchSharedMedia(for userID: UUID) async throws -> [Media]
    func fetchSharedMedia(forChat chatID: UUID) async throws -> [Media]
    func cacheImage(key: String, data: Data) async
    func cachedImage(for key: String) async -> Data?
}
