import Combine
import Foundation

/// Contract for MTProto proxy management and connection.
public protocol ProxyServiceProtocol: Sendable {
    func fetchProxies() async throws -> [Proxy]
    func addProxy(_ proxy: Proxy) async throws -> [Proxy]
    func removeProxy(id: UUID) async throws -> [Proxy]
    func setEnabled(_ enabled: Bool, for proxyID: UUID) async throws -> [Proxy]
    func setActiveProxy(id: UUID?) async throws
    func connectionStatePublisher() -> AnyPublisher<ProxyConnectionState, Never>
    func currentConnectionState() -> ProxyConnectionState
    func reconnect() async
    func initializeOnFirstLaunch() async
}
