import Foundation

/// Networking layer configuration integrated with proxy state.
public struct NetworkConfiguration: Sendable {
    public var proxyEnabled: Bool
    public var activeProxy: Proxy?
    public var connectionState: ProxyConnectionState

    public init(
        proxyEnabled: Bool = false,
        activeProxy: Proxy? = nil,
        connectionState: ProxyConnectionState = .disconnected
    ) {
        self.proxyEnabled = proxyEnabled
        self.activeProxy = activeProxy
        self.connectionState = connectionState
    }
}

/// Provides network configuration derived from proxy service state.
public final class NetworkConfigurationProvider: @unchecked Sendable {
    private let proxyService: ProxyServiceProtocol

    public init(proxyService: ProxyServiceProtocol) {
        self.proxyService = proxyService
    }

    public func currentConfiguration() async -> NetworkConfiguration {
        let proxies = (try? await proxyService.fetchProxies()) ?? []
        let settings = PreferencesStorage.shared.loadSettings()
        let activeID = settings?.activeProxyID
        let activeProxy = proxies.first { $0.id == activeID }
        return NetworkConfiguration(
            proxyEnabled: settings?.proxyEnabled ?? false,
            activeProxy: activeProxy,
            connectionState: proxyService.currentConnectionState()
        )
    }
}
