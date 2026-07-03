import Combine
import Foundation

/// Repository mediating proxy configuration between ViewModels and services.
@MainActor
public final class ProxyRepository: ObservableObject {
    private let proxyService: ProxyServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var connectionState: ProxyConnectionState = .disconnected

    public init(proxyService: ProxyServiceProtocol) {
        self.proxyService = proxyService
        proxyService.connectionStatePublisher()
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
    }

    public func fetchProxies() async throws -> [Proxy] {
        try await proxyService.fetchProxies()
    }

    public func addProxy(_ proxy: Proxy) async throws -> [Proxy] {
        try await proxyService.addProxy(proxy)
    }

    public func removeProxy(id: UUID) async throws -> [Proxy] {
        try await proxyService.removeProxy(id: id)
    }

    public func setEnabled(_ enabled: Bool, for proxyID: UUID) async throws -> [Proxy] {
        try await proxyService.setEnabled(enabled, for: proxyID)
    }

    public func setActiveProxy(id: UUID?) async throws {
        try await proxyService.setActiveProxy(id: id)
    }

    public func reconnect() async {
        await proxyService.reconnect()
    }

    public func initializeOnFirstLaunch() async {
        await proxyService.initializeOnFirstLaunch()
    }
}
