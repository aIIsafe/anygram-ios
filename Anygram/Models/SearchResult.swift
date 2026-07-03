import Foundation

/// Search result category.
public enum SearchResultType: String, Codable, Hashable, Sendable {
    case chat
    case message
    case contact
    case group
}

/// Unified search result item.
public struct SearchResult: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var type: SearchResultType
    public var title: String
    public var subtitle: String
    public var avatarColorHex: String
    public var date: Date?
    public var chatID: UUID?
    public var messageID: UUID?
    public var userID: UUID?

    public init(
        id: UUID = UUID(),
        type: SearchResultType,
        title: String,
        subtitle: String,
        avatarColorHex: String,
        date: Date? = nil,
        chatID: UUID? = nil,
        messageID: UUID? = nil,
        userID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.avatarColorHex = avatarColorHex
        self.date = date
        self.chatID = chatID
        self.messageID = messageID
        self.userID = userID
    }
}
