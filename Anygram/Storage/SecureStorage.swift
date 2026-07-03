import Foundation

/// Secure storage backed by Keychain for sensitive proxy credentials.
public final class KeychainStorage: @unchecked Sendable {
    public static let shared = KeychainStorage()
    private let service = "com.anygram.app"

    private init() {}

    public func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StorageError.keychainWriteFailed(status)
        }
    }

    public func load(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    public func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// UserDefaults wrapper for non-sensitive app preferences.
public final class PreferencesStorage: @unchecked Sendable {
    public static let shared = PreferencesStorage()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let hasLaunchedBefore = "anygram.hasLaunchedBefore"
        static let settings = "anygram.settings"
        static let proxyList = "anygram.proxyList"
        static let activeProxyID = "anygram.activeProxyID"
    }

    private init() {}

    public var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
    }

    public func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: Keys.settings)
    }

    public func loadSettings() -> AppSettings? {
        guard let data = defaults.data(forKey: Keys.settings) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    public func saveProxyIDs(_ ids: [UUID]) {
        defaults.set(ids.map(\.uuidString), forKey: Keys.proxyList)
    }

    public func loadProxyIDs() -> [UUID] {
        guard let strings = defaults.stringArray(forKey: Keys.proxyList) else { return [] }
        return strings.compactMap(UUID.init(uuidString:))
    }

    public var activeProxyID: UUID? {
        get {
            guard let str = defaults.string(forKey: Keys.activeProxyID) else { return nil }
            return UUID(uuidString: str)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: Keys.activeProxyID)
        }
    }
}

/// Storage operation errors.
public enum StorageError: Error, LocalizedError {
    case keychainWriteFailed(OSStatus)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .keychainWriteFailed(let status):
            return "Keychain write failed with status \(status)"
        case .encodingFailed:
            return "Failed to encode data"
        }
    }
}
