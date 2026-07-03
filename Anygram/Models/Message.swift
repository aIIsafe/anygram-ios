import Foundation

/// Message content type.
public enum MessageContentType: String, Codable, Hashable, Sendable {
    case text
    case image
    case voice
    case video
    case file
    case sticker
}

/// Represents a single chat message.
public struct Message: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let chatID: UUID
    public let senderID: UUID
    public var text: String
    public var contentType: MessageContentType
    public var timestamp: Date
    public var isOutgoing: Bool
    public var isEdited: Bool
    public var isForwarded: Bool
    public var forwardedFrom: String?
    public var replyToMessageID: UUID?
    public var reactions: [Reaction]
    public var attachment: Attachment?
    public var deliveryState: MessageDeliveryState
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        chatID: UUID,
        senderID: UUID,
        text: String,
        contentType: MessageContentType = .text,
        timestamp: Date,
        isOutgoing: Bool,
        isEdited: Bool = false,
        isForwarded: Bool = false,
        forwardedFrom: String? = nil,
        replyToMessageID: UUID? = nil,
        reactions: [Reaction] = [],
        attachment: Attachment? = nil,
        deliveryState: MessageDeliveryState = .read,
        isSelected: Bool = false
    ) {
        self.id = id
        self.chatID = chatID
        self.senderID = senderID
        self.text = text
        self.contentType = contentType
        self.timestamp = timestamp
        self.isOutgoing = isOutgoing
        self.isEdited = isEdited
        self.isForwarded = isForwarded
        self.forwardedFrom = forwardedFrom
        self.replyToMessageID = replyToMessageID
        self.reactions = reactions
        self.attachment = attachment
        self.deliveryState = deliveryState
        self.isSelected = isSelected
    }
}
