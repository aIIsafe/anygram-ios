import Foundation

/// In-memory mock implementation of media operations.
public final class MockMediaService: MediaServiceProtocol, @unchecked Sendable {
    private let cache: ImageCacheProtocol

    public init(cache: ImageCacheProtocol) {
        self.cache = cache
    }

    public func fetchSharedMedia(for userID: UUID) async throws -> [Media] {
        MockDataGenerator.generateMedia(for: userID)
    }

    public func fetchSharedMedia(forChat chatID: UUID) async throws -> [Media] {
        MockDataGenerator.generateMedia(for: chatID, count: 8)
    }

    public func cacheImage(key: String, data: Data) async {
        await cache.store(data, for: key)
    }

    public func cachedImage(for key: String) async -> Data? {
        await cache.image(for: key)
    }
}
