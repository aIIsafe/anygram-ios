import Foundation

/// Registered device session.
public struct Device: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var platform: String
    public var location: String
    public var lastActive: Date
    public var isCurrent: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        platform: String,
        location: String,
        lastActive: Date,
        isCurrent: Bool = false
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.location = location
        self.lastActive = lastActive
        self.isCurrent = isCurrent
    }
}
