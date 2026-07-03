import Combine
import Foundation

/// Production Telegram API service stub for future MTProto integration.
/// Replace MockChatService in DIContainer when MTProto layer is ready.
public final class TelegramChatService: ChatServiceProtocol, @unchecked Sendable {
    private let mockFallback: MockChatService

    public init(networkConfiguration: NetworkConfigurationProvider) {
        self.mockFallback = MockChatService()
    }

    public func fetchChats(includeArchived: Bool) async throws -> [Chat] {
        try await mockFallback.fetchChats(includeArchived: includeArchived)
    }

    public func fetchMessages(for chatID: UUID, page: Int, pageSize: Int) async throws -> [Message] {
        try await mockFallback.fetchMessages(for: chatID, page: page, pageSize: pageSize)
    }

    public func sendMessage(_ text: String, to chatID: UUID, replyTo: UUID?) async throws -> Message {
        try await mockFallback.sendMessage(text, to: chatID, replyTo: replyTo)
    }

    public func deleteChat(_ chatID: UUID) async throws {
        try await mockFallback.deleteChat(chatID)
    }

    public func togglePin(chatID: UUID) async throws -> Chat {
        try await mockFallback.togglePin(chatID: chatID)
    }

    public func toggleMute(chatID: UUID) async throws -> Chat {
        try await mockFallback.toggleMute(chatID: chatID)
    }

    public func archiveChat(_ chatID: UUID) async throws -> Chat {
        try await mockFallback.archiveChat(chatID)
    }

    public func addReaction(_ emoji: String, to messageID: UUID, in chatID: UUID) async throws -> Message {
        try await mockFallback.addReaction(emoji, to: messageID, in: chatID)
    }

    public func typingPublisher(for chatID: UUID) -> AnyPublisher<TypingStatus, Never> {
        mockFallback.typingPublisher(for: chatID)
    }

    public func observeChats() -> AnyPublisher<[Chat], Never> {
        mockFallback.observeChats()
    }
}
