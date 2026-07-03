import Foundation

/// MTProto proxy connection state.
public enum ProxyConnectionState: String, Codable, Hashable, Sendable {
    case connected
    case connecting
    case disconnected
}

/// MTProto proxy configuration.
public struct Proxy: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var server: String
    public var port: Int
    public var secret: String
    public var isEnabled: Bool
    public var isDefault: Bool
    public var label: String

    public var link: String {
        "tg://proxy?server=\(server)&port=\(port)&secret=\(secret)"
    }

    public init(
        id: UUID = UUID(),
        server: String,
        port: Int,
        secret: String,
        isEnabled: Bool = false,
        isDefault: Bool = false,
        label: String = ""
    ) {
        self.id = id
        self.server = server
        self.port = port
        self.secret = secret
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.label = label.isEmpty ? "\(server):\(port)" : label
    }

    /// Built-in default MTProto proxy for first launch.
    public static let builtInDefault = Proxy(
        id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890") ?? UUID(),
        server: "78.17.154.32",
        port: 443,
        secret: "ee012c78136de96da97a3b0c9b5dc635fd6966636f6e6669672e6d65",
        isEnabled: true,
        isDefault: true,
        label: "Default Proxy"
    )
}
