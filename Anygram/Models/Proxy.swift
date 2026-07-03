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

    /// Previous built-in proxy kept for migration matching.
    public static let previousBuiltInServer = "78.17.154.32"
    public static let previousBuiltInPort = 443
    public static let previousBuiltInSecret =
        "ee012c78136de96da97a3b0c9b5dc635fd6966636f6e6669672e6d65"

    /// Built-in default MTProto proxy for first launch.
    public static let builtInDefault = Proxy(
        id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890") ?? UUID(),
        server: "213.219.212.17",
        port: 8443,
        secret: "7p4d3g3gKi58ItEOL_-EEBN0Z25uLmxpdmU",
        isEnabled: true,
        isDefault: true,
        label: "Default Proxy"
    )

    /// Secondary fallback if the primary built-in proxy is unreachable.
    public static let builtInFallback = Proxy(
        id: UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F1234567891") ?? UUID(),
        server: previousBuiltInServer,
        port: previousBuiltInPort,
        secret: previousBuiltInSecret,
        isEnabled: false,
        isDefault: false,
        label: "Fallback Proxy"
    )

    public static let builtInFallbacks: [Proxy] = [builtInFallback]
}
