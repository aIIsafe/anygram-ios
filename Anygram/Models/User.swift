import Foundation

/// Represents a messenger user profile.
public struct User: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var username: String
    public var avatarColorHex: String
    public var lastSeen: Date?
    public var phone: String
    public var bio: String
    public var status: String
    public var isOnline: Bool
    public var isPremium: Bool
    public var isVerified: Bool
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        username: String,
        avatarColorHex: String,
        lastSeen: Date? = nil,
        phone: String,
        bio: String = "",
        status: String = "",
        isOnline: Bool = false,
        isPremium: Bool = false,
        isVerified: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.avatarColorHex = avatarColorHex
        self.lastSeen = lastSeen
        self.phone = phone
        self.bio = bio
        self.status = status
        self.isOnline = isOnline
        self.isPremium = isPremium
        self.isVerified = isVerified
        self.isPinned = isPinned
    }
}
