import Combine
import Foundation

/// Contract for chat list and message operations.
public protocol ChatServiceProtocol: Sendable {
    func fetchChats(includeArchived: Bool) async throws -> [Chat]
    func fetchMessages(for chatID: UUID, page: Int, pageSize: Int) async throws -> [Message]
    func sendMessage(_ text: String, to chatID: UUID, replyTo: UUID?) async throws -> Message
    func deleteChat(_ chatID: UUID) async throws
    func togglePin(chatID: UUID) async throws -> Chat
    func toggleMute(chatID: UUID) async throws -> Chat
    func archiveChat(_ chatID: UUID) async throws -> Chat
    func addReaction(_ emoji: String, to messageID: UUID, in chatID: UUID) async throws -> Message
    func typingPublisher(for chatID: UUID) -> AnyPublisher<TypingStatus, Never>
    func observeChats() -> AnyPublisher<[Chat], Never>
}
