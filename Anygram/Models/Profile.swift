import Foundation

/// Extended user profile with privacy and notification preferences.
public struct Profile: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var user: User
    public var sharedMediaCount: Int
    public var isMuted: Bool
    public var isBlocked: Bool
    public var notificationEnabled: Bool
    public var encryptionEnabled: Bool

    public init(
        id: UUID = UUID(),
        user: User,
        sharedMediaCount: Int = 0,
        isMuted: Bool = false,
        isBlocked: Bool = false,
        notificationEnabled: Bool = true,
        encryptionEnabled: Bool = true
    ) {
        self.id = id
        self.user = user
        self.sharedMediaCount = sharedMediaCount
        self.isMuted = isMuted
        self.isBlocked = isBlocked
        self.notificationEnabled = notificationEnabled
        self.encryptionEnabled = encryptionEnabled
    }
}
