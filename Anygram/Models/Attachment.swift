import Foundation

/// Message attachment metadata.
public struct Attachment: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var fileName: String
    public var mimeType: String
    public var fileSize: Int64
    public var duration: TimeInterval?
    public var thumbnailColorHex: String
    public var width: Int?
    public var height: Int?

    public init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        fileSize: Int64,
        duration: TimeInterval? = nil,
        thumbnailColorHex: String = "#3390EC",
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.duration = duration
        self.thumbnailColorHex = thumbnailColorHex
        self.width = width
        self.height = height
    }
}
