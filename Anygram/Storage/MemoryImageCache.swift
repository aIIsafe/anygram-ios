import Foundation

/// In-memory image cache with LRU eviction placeholder for production disk layer.
public final class MemoryImageCache: ImageCacheProtocol, @unchecked Sendable {
    private var cache: [String: Data] = [:]
    private let lock = NSLock()
    private let maxEntries = 200

    public init() {}

    public func image(for key: String) async -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    public func store(_ data: Data, for key: String) async {
        lock.lock()
        defer { lock.unlock() }
        if cache.count >= maxEntries, let firstKey = cache.keys.first {
            cache.removeValue(forKey: firstKey)
        }
        cache[key] = data
    }

    public func remove(for key: String) async {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }

    public func clearAll() async {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}
