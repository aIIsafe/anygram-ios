import Combine
import Foundation

/// Default MTProto proxy service with secure storage and auto-reconnect.
public final class DefaultProxyService: ProxyServiceProtocol, @unchecked Sendable {
    private let preferences: PreferencesStorage
    private let keychain: KeychainStorage
    private let connectionStateSubject = CurrentValueSubject<ProxyConnectionState, Never>(.disconnected)
    private var reconnectTask: Task<Void, Never>?
    private var proxies: [Proxy] = []
    private let lock = NSLock()

    public init(
        preferences: PreferencesStorage = .shared,
        keychain: KeychainStorage = .shared
    ) {
        self.preferences = preferences
        self.keychain = keychain
    }

    public func initializeOnFirstLaunch() async {
        migrateBuiltInProxy()
        if !preferences.hasLaunchedBefore {
            preferences.hasLaunchedBefore = true
            let defaultProxy = Proxy.builtInDefault
            try? storeProxySecret(defaultProxy)
            proxies = [defaultProxy]
            preferences.saveProxyIDs([defaultProxy.id])
            preferences.activeProxyID = defaultProxy.id
            var settings = preferences.loadSettings() ?? AppSettings()
            settings.proxyEnabled = true
            settings.activeProxyID = defaultProxy.id
            try? preferences.saveSettings(settings)
            await connectActiveProxy()
        } else {
            await loadProxiesFromStorage()
            if preferences.loadSettings()?.proxyEnabled == true {
                await connectActiveProxy()
            }
        }
    }

    public func fetchProxies() async throws -> [Proxy] {
        lock.lock()
        let isEmpty = proxies.isEmpty
        lock.unlock()
        if isEmpty {
            await loadProxiesFromStorage()
        }
        lock.lock()
        defer { lock.unlock() }
        return proxies
    }

    public func addProxy(_ proxy: Proxy) async throws -> [Proxy] {
        lock.lock()
        proxies.append(proxy)
        try storeProxySecret(proxy)
        preferences.saveProxyIDs(proxies.map(\.id))
        let result = proxies
        lock.unlock()
        return result
    }

    public func removeProxy(id: UUID) async throws -> [Proxy] {
        lock.lock()
        proxies.removeAll { $0.id == id }
        keychain.delete(for: proxySecretKey(id))
        preferences.saveProxyIDs(proxies.map(\.id))
        if preferences.activeProxyID == id {
            preferences.activeProxyID = proxies.first?.id
        }
        let result = proxies
        lock.unlock()
        return result
    }

    public func setEnabled(_ enabled: Bool, for proxyID: UUID) async throws -> [Proxy] {
        lock.lock()
        if let index = proxies.firstIndex(where: { $0.id == proxyID }) {
            proxies[index].isEnabled = enabled
        }
        let result = proxies
        lock.unlock()
        if enabled {
            preferences.activeProxyID = proxyID
            await connectActiveProxy()
        }
        return result
    }

    public func setActiveProxy(id: UUID?) async throws {
        preferences.activeProxyID = id
        if id != nil {
            await connectActiveProxy()
        } else {
            connectionStateSubject.send(.disconnected)
        }
    }

    public func connectionStatePublisher() -> AnyPublisher<ProxyConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    public func currentConnectionState() -> ProxyConnectionState {
        connectionStateSubject.value
    }

    public func reconnect() async {
        await connectActiveProxy()
    }

    // MARK: - Private

    private static let builtInProxyMigrationKey = "anygram.proxyMigration.v2"

    /// Replaces stored built-in proxy with the current default for existing installs.
    private func migrateBuiltInProxy() {
        guard !preferences.hasMigrationFlag(Self.builtInProxyMigrationKey) else { return }

        try? storeProxySecret(Proxy.builtInDefault)

        let activeID = preferences.activeProxyID
        let storedIDs = preferences.loadProxyIDs()
        let usesBuiltInID = storedIDs.contains(Proxy.builtInDefault.id)
            || activeID == Proxy.builtInDefault.id

        if usesBuiltInID || activeID == nil {
            preferences.activeProxyID = Proxy.builtInDefault.id
            preferences.saveProxyIDs([Proxy.builtInDefault.id])
            var settings = preferences.loadSettings() ?? AppSettings()
            settings.proxyEnabled = true
            settings.activeProxyID = Proxy.builtInDefault.id
            try? preferences.saveSettings(settings)
        }

        lock.lock()
        if proxies.isEmpty || proxies.contains(where: { $0.id == Proxy.builtInDefault.id }) {
            proxies = [Proxy.builtInDefault]
            preferences.saveProxyIDs([Proxy.builtInDefault.id])
        }
        lock.unlock()

        preferences.setMigrationFlag(Self.builtInProxyMigrationKey)
    }

    private func loadProxiesFromStorage() async {
        lock.lock()
        let ids = preferences.loadProxyIDs()
        if ids.isEmpty {
            proxies = [Proxy.builtInDefault]
            preferences.saveProxyIDs(proxies.map(\.id))
        } else {
            proxies = ids.compactMap { id in
                guard let secretData = keychain.load(for: proxySecretKey(id)),
                      let secret = String(data: secretData, encoding: .utf8) else { return nil }
                let isActive = preferences.activeProxyID == id
                if id == Proxy.builtInDefault.id {
                    return Proxy.builtInDefault
                }
                return Proxy(
                    id: id,
                    server: "proxy.example.com",
                    port: 443,
                    secret: secret,
                    isEnabled: isActive,
                    label: "Custom Proxy"
                )
            }
            if proxies.isEmpty {
                proxies = [Proxy.builtInDefault]
            }
        }
        lock.unlock()
    }

    private func connectActiveProxy() async {
        connectionStateSubject.send(.connecting)
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.connectionStateSubject.send(.connected)
            }
        }
    }

    private func storeProxySecret(_ proxy: Proxy) throws {
        guard let data = proxy.secret.data(using: .utf8) else {
            throw StorageError.encodingFailed
        }
        try keychain.save(data, for: proxySecretKey(proxy.id))
    }

    private func proxySecretKey(_ id: UUID) -> String {
        "proxy.secret.\(id.uuidString)"
    }
}

/// Future remote proxy list fetcher placeholder for MTProto integration.
public final class FutureRemoteProxyService: ProxyServiceProtocol, @unchecked Sendable {
    private let localService: DefaultProxyService

    public init(localService: DefaultProxyService) {
        self.localService = localService
    }

    public func fetchProxies() async throws -> [Proxy] {
        try await localService.fetchProxies()
    }

    public func addProxy(_ proxy: Proxy) async throws -> [Proxy] {
        try await localService.addProxy(proxy)
    }

    public func removeProxy(id: UUID) async throws -> [Proxy] {
        try await localService.removeProxy(id: id)
    }

    public func setEnabled(_ enabled: Bool, for proxyID: UUID) async throws -> [Proxy] {
        try await localService.setEnabled(enabled, for: proxyID)
    }

    public func setActiveProxy(id: UUID?) async throws {
        try await localService.setActiveProxy(id: id)
    }

    public func connectionStatePublisher() -> AnyPublisher<ProxyConnectionState, Never> {
        localService.connectionStatePublisher()
    }

    public func currentConnectionState() -> ProxyConnectionState {
        localService.currentConnectionState()
    }

    public func reconnect() async {
        await localService.reconnect()
    }

    public func initializeOnFirstLaunch() async {
        await localService.initializeOnFirstLaunch()
    }
}
