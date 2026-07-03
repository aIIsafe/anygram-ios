import Foundation

/// Chat type classification.
public enum ChatType: String, Codable, Hashable, Sendable {
    case privateChat
    case group
    case channel
    case savedMessages
}

/// Delivery state for the last message preview.
public enum MessageDeliveryState: String, Codable, Hashable, Sendable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

/// Represents a conversation in the chat list.
public struct Chat: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var type: ChatType
    public var participantIDs: [UUID]
    public var lastMessage: String
    public var lastMessageDate: Date
    public var unreadCount: Int
    public var isPinned: Bool
    public var isMuted: Bool
    public var isArchived: Bool
    public var isVerified: Bool
    public var isPremium: Bool
    public var avatarColorHex: String
    public var deliveryState: MessageDeliveryState
    public var isTyping: Bool
    public var folderID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        type: ChatType,
        participantIDs: [UUID],
        lastMessage: String,
        lastMessageDate: Date,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false,
        isArchived: Bool = false,
        isVerified: Bool = false,
        isPremium: Bool = false,
        avatarColorHex: String,
        deliveryState: MessageDeliveryState = .read,
        isTyping: Bool = false,
        folderID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.participantIDs = participantIDs
        self.lastMessage = lastMessage
        self.lastMessageDate = lastMessageDate
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isArchived = isArchived
        self.isVerified = isVerified
        self.isPremium = isPremium
        self.avatarColorHex = avatarColorHex
        self.deliveryState = deliveryState
        self.isTyping = isTyping
        self.folderID = folderID
    }
}
