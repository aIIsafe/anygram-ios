import Foundation

/// Call direction relative to the current user.
public enum CallDirection: String, Codable, Hashable, Sendable {
    case incoming
    case outgoing
    case missed
}

/// Call media type.
public enum CallMediaType: String, Codable, Hashable, Sendable {
    case voice
    case video
}

/// Represents a call history entry.
public struct Call: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let userID: UUID
    public var userName: String
    public var avatarColorHex: String
    public var direction: CallDirection
    public var mediaType: CallMediaType
    public var date: Date
    public var duration: TimeInterval

    public init(
        id: UUID = UUID(),
        userID: UUID,
        userName: String,
        avatarColorHex: String,
        direction: CallDirection,
        mediaType: CallMediaType,
        date: Date,
        duration: TimeInterval
    ) {
        self.id = id
        self.userID = userID
        self.userName = userName
        self.avatarColorHex = avatarColorHex
        self.direction = direction
        self.mediaType = mediaType
        self.date = date
        self.duration = duration
    }
}
