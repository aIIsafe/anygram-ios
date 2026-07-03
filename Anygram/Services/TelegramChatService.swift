import Combine
import Foundation

/// Production Telegram chat service — delegates to TDLib when available, otherwise mock data.
public final class TelegramChatService: ChatServiceProtocol, @unchecked Sendable {
    #if USE_SCAFFOLD_AUTH
    private let backend: MockChatService
    #elseif targetEnvironment(simulator)
    private let backend: MockChatService
    #elseif canImport(TDLibKit)
    private let backend: TDLibChatService
    #else
    private let backend: MockChatService
    #endif

    public init(networkConfiguration: NetworkConfigurationProvider) {
        #if USE_SCAFFOLD_AUTH
        self.backend = MockChatService()
        #elseif targetEnvironment(simulator)
        self.backend = MockChatService()
        #elseif canImport(TDLibKit)
        self.backend = TDLibChatService()
        #else
        self.backend = MockChatService()
        #endif
    }

    public func fetchChats(includeArchived: Bool) async throws -> [Chat] {
        try await backend.fetchChats(includeArchived: includeArchived)
    }

    public func fetchMessages(for chatID: UUID, page: Int, pageSize: Int) async throws -> [Message] {
        try await backend.fetchMessages(for: chatID, page: page, pageSize: pageSize)
    }

    public func sendMessage(_ text: String, to chatID: UUID, replyTo: UUID?) async throws -> Message {
        try await backend.sendMessage(text, to: chatID, replyTo: replyTo)
    }

    public func deleteChat(_ chatID: UUID) async throws {
        try await backend.deleteChat(chatID)
    }

    public func togglePin(chatID: UUID) async throws -> Chat {
        try await backend.togglePin(chatID: chatID)
    }

    public func toggleMute(chatID: UUID) async throws -> Chat {
        try await backend.toggleMute(chatID: chatID)
    }

    public func archiveChat(_ chatID: UUID) async throws -> Chat {
        try await backend.archiveChat(chatID)
    }

    public func addReaction(_ emoji: String, to messageID: UUID, in chatID: UUID) async throws -> Message {
        try await backend.addReaction(emoji, to: messageID, in: chatID)
    }

    public func typingPublisher(for chatID: UUID) -> AnyPublisher<TypingStatus, Never> {
        backend.typingPublisher(for: chatID)
    }

    public func observeChats() -> AnyPublisher<[Chat], Never> {
        backend.observeChats()
    }
}
