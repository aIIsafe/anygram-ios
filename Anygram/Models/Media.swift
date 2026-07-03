import Foundation

/// Media asset type for shared profile content.
public enum MediaType: String, Codable, Hashable, Sendable {
    case photo
    case video
    case file
    case link
    case voice
}

/// Represents shared media in a profile or chat.
public struct Media: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let chatID: UUID?
    public let userID: UUID?
    public var type: MediaType
    public var title: String
    public var thumbnailColorHex: String
    public var date: Date
    public var fileSize: Int64

    public init(
        id: UUID = UUID(),
        chatID: UUID? = nil,
        userID: UUID? = nil,
        type: MediaType,
        title: String,
        thumbnailColorHex: String,
        date: Date,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.chatID = chatID
        self.userID = userID
        self.type = type
        self.title = title
        self.thumbnailColorHex = thumbnailColorHex
        self.date = date
        self.fileSize = fileSize
    }
}
