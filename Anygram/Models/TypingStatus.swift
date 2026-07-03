import Foundation

/// Typing indicator state for a chat.
public struct TypingStatus: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let chatID: UUID
    public let userID: UUID
    public var userName: String
    public var isTyping: Bool
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        chatID: UUID,
        userID: UUID,
        userName: String,
        isTyping: Bool,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.chatID = chatID
        self.userID = userID
        self.userName = userName
        self.isTyping = isTyping
        self.updatedAt = updatedAt
    }
}
