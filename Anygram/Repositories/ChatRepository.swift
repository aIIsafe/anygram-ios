import Combine
import Foundation

/// Repository mediating chat data between ViewModels and services.
@MainActor
public final class ChatRepository: ObservableObject {
    private let chatService: ChatServiceProtocol
    private var cachedChats: [Chat] = []
    private var cancellables = Set<AnyCancellable>()

    public init(chatService: ChatServiceProtocol) {
        self.chatService = chatService
        chatService.observeChats()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chats in
                self?.cachedChats = chats
            }
            .store(in: &cancellables)
    }

    public func fetchChats(includeArchived: Bool = false) async throws -> [Chat] {
        let chats = try await chatService.fetchChats(includeArchived: includeArchived)
        cachedChats = chats
        return chats
    }

    public func fetchMessages(for chatID: UUID, page: Int = 0, pageSize: Int = 30) async throws -> [Message] {
        try await chatService.fetchMessages(for: chatID, page: page, pageSize: pageSize)
    }

    public func sendMessage(_ text: String, to chatID: UUID, replyTo: UUID? = nil) async throws -> Message {
        try await chatService.sendMessage(text, to: chatID, replyTo: replyTo)
    }

    public func deleteChat(_ chatID: UUID) async throws {
        try await chatService.deleteChat(chatID)
    }

    public func togglePin(chatID: UUID) async throws -> Chat {
        try await chatService.togglePin(chatID: chatID)
    }

    public func toggleMute(chatID: UUID) async throws -> Chat {
        try await chatService.toggleMute(chatID: chatID)
    }

    public func archiveChat(_ chatID: UUID) async throws -> Chat {
        try await chatService.archiveChat(chatID)
    }

    public func addReaction(_ emoji: String, to messageID: UUID, in chatID: UUID) async throws -> Message {
        try await chatService.addReaction(emoji, to: messageID, in: chatID)
    }

    public func typingPublisher(for chatID: UUID) -> AnyPublisher<TypingStatus, Never> {
        chatService.typingPublisher(for: chatID)
    }
}
