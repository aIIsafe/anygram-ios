import Combine
import Foundation

/// Initializes TDLib with proxy configuration from `ProxyServiceProtocol`.
public final class TelegramNetworkService: @unchecked Sendable {
    private let proxyService: ProxyServiceProtocol
    private let authService: AuthServiceProtocol

    public init(proxyService: ProxyServiceProtocol, authService: AuthServiceProtocol) {
        self.proxyService = proxyService
        self.authService = authService
    }

    public func bootstrapForLogin() async throws {
        await proxyService.initializeOnFirstLaunch()
        try await authService.initialize()
        try await applyActiveProxy()
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
