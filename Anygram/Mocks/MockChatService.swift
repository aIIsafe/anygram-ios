import Combine
import Foundation

/// In-memory mock implementation of chat operations.
public final class MockChatService: ChatServiceProtocol, @unchecked Sendable {
    private var chats: [Chat]
    private var messagesByChat: [UUID: [Message]]
    private let chatsSubject: CurrentValueSubject<[Chat], Never>
    private var typingSubjects: [UUID: PassthroughSubject<TypingStatus, Never>] = [:]
    private let lock = NSLock()

    public init() {
        let users = MockDataGenerator.generateUsers()
        let chats = MockDataGenerator.generateChats(users: users)
        self.chats = chats
        var messages: [UUID: [Message]] = [:]
        for chat in chats.prefix(20) {
            messages[chat.id] = MockDataGenerator.generateMessages(for: chat, users: users)
        }
        self.messagesByChat = messages
        self.chatsSubject = CurrentValueSubject(chats)
        startTypingSimulation()
    }

    public func fetchChats(includeArchived: Bool) async throws -> [Chat] {
        lock.lock()
        defer { lock.unlock() }
        let filtered = includeArchived ? chats : chats.filter { !$0.isArchived }
        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.lastMessageDate > rhs.lastMessageDate
        }
    }

    public func fetchMessages(for chatID: UUID, page: Int, pageSize: Int) async throws -> [Message] {
        lock.lock()
        defer { lock.unlock() }
        if messagesByChat[chatID] == nil {
            let users = MockDataGenerator.generateUsers()
            if let chat = chats.first(where: { $0.id == chatID }) {
                messagesByChat[chatID] = MockDataGenerator.generateMessages(for: chat, users: users)
            }
        }
        let all = messagesByChat[chatID] ?? []
        let start = max(0, all.count - (page + 1) * pageSize)
        let end = all.count - page * pageSize
        guard start < end else { return [] }
        return Array(all[start..<min(end, all.count)])
    }

    public func sendMessage(_ text: String, to chatID: UUID, replyTo: UUID?) async throws -> Message {
        let message = Message(
            chatID: chatID,
            senderID: MockDataGenerator.currentUserID,
            text: text,
            timestamp: Date(),
            isOutgoing: true,
            replyToMessageID: replyTo,
            deliveryState: .sent
        )
        lock.lock()
        messagesByChat[chatID, default: []].append(message)
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].lastMessage = text
            chats[index].lastMessageDate = Date()
            chats[index].deliveryState = .sent
        }
        let updated = chats
        lock.unlock()
        chatsSubject.send(updated)
        return message
    }

    public func deleteChat(_ chatID: UUID) async throws {
        lock.lock()
        chats.removeAll { $0.id == chatID }
        messagesByChat.removeValue(forKey: chatID)
        let updated = chats
        lock.unlock()
        chatsSubject.send(updated)
    }

    public func togglePin(chatID: UUID) async throws -> Chat {
        lock.lock()
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else {
            lock.unlock()
            throw MockServiceError.notFound
        }
        chats[index].isPinned.toggle()
        let chat = chats[index]
        let updated = chats
        lock.unlock()
        chatsSubject.send(updated)
        return chat
    }

    public func toggleMute(chatID: UUID) async throws -> Chat {
        lock.lock()
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else {
            lock.unlock()
            throw MockServiceError.notFound
        }
        chats[index].isMuted.toggle()
        let chat = chats[index]
        let updated = chats
        lock.unlock()
        chatsSubject.send(updated)
        return chat
    }

    public func archiveChat(_ chatID: UUID) async throws -> Chat {
        lock.lock()
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else {
            lock.unlock()
            throw MockServiceError.notFound
        }
        chats[index].isArchived.toggle()
        let chat = chats[index]
        let updated = chats
        lock.unlock()
        chatsSubject.send(updated)
        return chat
    }

    public func addReaction(_ emoji: String, to messageID: UUID, in chatID: UUID) async throws -> Message {
        lock.lock()
        guard var messages = messagesByChat[chatID],
              let index = messages.firstIndex(where: { $0.id == messageID }) else {
            lock.unlock()
            throw MockServiceError.notFound
        }
        if let reactionIndex = messages[index].reactions.firstIndex(where: { $0.emoji == emoji }) {
            messages[index].reactions[reactionIndex].count += 1
            messages[index].reactions[reactionIndex].isSelectedByCurrentUser = true
        } else {
            messages[index].reactions.append(Reaction(emoji: emoji, isSelectedByCurrentUser: true))
        }
        let message = messages[index]
        messagesByChat[chatID] = messages
        lock.unlock()
        return message
    }

    public func typingPublisher(for chatID: UUID) -> AnyPublisher<TypingStatus, Never> {
        lock.lock()
        if typingSubjects[chatID] == nil {
            typingSubjects[chatID] = PassthroughSubject()
        }
        let subject = typingSubjects[chatID]!
        lock.unlock()
        return subject.eraseToAnyPublisher()
    }

    public func observeChats() -> AnyPublisher<[Chat], Never> {
        chatsSubject.eraseToAnyPublisher()
    }

    private func startTypingSimulation() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                lock.lock()
                for index in chats.indices where chats[index].isTyping {
                    chats[index].lastMessage = "typing..."
                }
                let updated = chats
                lock.unlock()
                chatsSubject.send(updated)
            }
        }
    }
}

public enum MockServiceError: Error {
    case notFound
}

