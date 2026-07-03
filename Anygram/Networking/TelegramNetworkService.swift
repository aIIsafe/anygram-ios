import Combine
import Foundation

/// Initializes TDLib with proxy configuration from `ProxyServiceProtocol`.
public final class TelegramNetworkService: @unchecked Sendable {
    private let proxyService: ProxyServiceProtocol
    private let authService: AuthServiceProtocol
    private let lock = NSLock()
    private var loginSessionPrepared = false

    public init(proxyService: ProxyServiceProtocol, authService: AuthServiceProtocol) {
        self.proxyService = proxyService
        self.authService = authService
    }

    public func bootstrapForLogin() async throws {
        // TDLib handles proxy itself — only load config for TDLibProxyBridge, skip mock connect loop.
        let proxies = try await proxyService.fetchProxies()
        let settings = PreferencesStorage.shared.loadSettings()
        let active = proxies.first(where: { $0.id == settings?.activeProxyID && $0.isEnabled })
            ?? proxies.first(where: \.isEnabled)
            ?? proxies.first
            ?? Proxy.builtInDefault
        await TDLibProxyBridge.shared.configure(proxy: active)

        lock.lock()
        let alreadyPrepared = loginSessionPrepared
        lock.unlock()
        guard !alreadyPrepared else { return }

        try await authService.initialize()

        lock.lock()
        loginSessionPrepared = true
        lock.unlock()
    }

    public func resetLoginBootstrap() {
        lock.lock()
        loginSessionPrepared = false
        lock.unlock()
        #if canImport(TDLibKit)
        TDLibProxyApplier.resetAppliedProxy()
        #endif
    }

    public func applyActiveProxy() async throws {
        let proxies = try await proxyService.fetchProxies()
        guard let active = proxies.first(where: { $0.isEnabled }) ?? proxies.first else { return }
        await TDLibProxyBridge.shared.configure(proxy: active)
    }
}

/// Shared proxy bridge consumed by TDLib auth backend.
public actor TDLibProxyBridge {
    public static let shared = TDLibProxyBridge()
    private(set) var activeProxy: Proxy?

    public func configure(proxy: Proxy) {
        activeProxy = proxy
    }
}
