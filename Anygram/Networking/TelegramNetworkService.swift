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
        AppDebugLogger.shared.log("bootstrapForLogin start", category: .NETWORK)
        // TDLib handles proxy itself — only load config for TDLibProxyBridge, skip mock connect loop.
        let proxies = try await proxyService.fetchProxies()
        AppDebugLogger.shared.log("fetchProxies: \(proxies.count) proxy(ies)", category: .NETWORK)
        let settings = PreferencesStorage.shared.loadSettings()
        let active = proxies.first(where: { $0.id == settings?.activeProxyID && $0.isEnabled })
            ?? proxies.first(where: \.isEnabled)
            ?? proxies.first
            ?? Proxy.builtInDefault
        await TDLibProxyBridge.shared.configure(proxy: active)
        AppDebugLogger.shared.log("active proxy: \(active.server):\(active.port)", category: .NETWORK)

        lock.lock()
        let alreadyPrepared = loginSessionPrepared
        lock.unlock()

        #if canImport(TDLibKit)
        let parametersReady = TDLibAccessGate.shared.areParametersApplied && TDLibSession.shared.isReady
        #else
        let parametersReady = true
        #endif

        if alreadyPrepared && parametersReady {
            AppDebugLogger.shared.log("bootstrapForLogin: session already prepared, parameters verified", category: .NETWORK)
            return
        }

        if alreadyPrepared && !parametersReady {
            AppDebugLogger.shared.log("bootstrapForLogin: session prepared but TDLib params missing — re-initialize", category: .NETWORK)
        } else {
            AppDebugLogger.shared.log("bootstrapForLogin: authService.initialize()", category: .AUTH)
        }

        try await authService.initialize()

        #if canImport(TDLibKit)
        guard TDLibAccessGate.shared.areParametersApplied else {
            AppDebugLogger.shared.log("bootstrapForLogin: initialize finished without setTdlibParameters", category: .ERROR)
            throw AuthError.stillStarting
        }
        #endif

        lock.lock()
        loginSessionPrepared = true
        lock.unlock()
        AppDebugLogger.shared.log("bootstrapForLogin complete", category: .NETWORK)
    }

    public func resetLoginBootstrap() async {
        lock.lock()
        loginSessionPrepared = false
        lock.unlock()
        AppDebugLogger.shared.log("resetLoginBootstrap + resetClientSafely", category: .NETWORK)
        #if canImport(TDLibKit)
        TDLibProxyApplier.resetAppliedProxy()
        await TDLibSession.shared.resetClientSafely()
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
