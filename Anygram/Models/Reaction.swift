import Foundation

/// Emoji reaction on a message.
public struct Reaction: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var emoji: String
    public var count: Int
    public var isSelectedByCurrentUser: Bool

    public init(
        id: UUID = UUID(),
        emoji: String,
        count: Int = 1,
        isSelectedByCurrentUser: Bool = false
    ) {
        self.id = id
        self.emoji = emoji
        self.count = count
        self.isSelectedByCurrentUser = isSelectedByCurrentUser
    }
}
