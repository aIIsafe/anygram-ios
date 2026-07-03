import Foundation

/// Chat folder for organizing conversations.
public struct Folder: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var chatIDs: [UUID]
    public var isIncluded: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        chatIDs: [UUID] = [],
        isIncluded: Bool = true
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.chatIDs = chatIDs
        self.isIncluded = isIncluded
    }
}
