import Foundation

/// Local search index with mock architecture ready for production backend.
public final class MockSearchService: SearchServiceProtocol, @unchecked Sendable {
    private var index: [SearchResult] = []
    private let lock = NSLock()

    public init(
        chatService: ChatServiceProtocol,
        userService: UserServiceProtocol
    ) {
        _ = chatService
        _ = userService
        let users = MockDataGenerator.generateUsers()
        let chats = MockDataGenerator.generateChats(users: users)
        index = Self.buildIndex(chats: chats, users: users)
    }

    public func indexAll() async {
        let users = MockDataGenerator.generateUsers()
        let chats = MockDataGenerator.generateChats(users: users)
        lock.lock()
        index = Self.buildIndex(chats: chats, users: users)
        lock.unlock()
    }

    public func search(query: String) async throws -> [SearchResult] {
        lock.lock()
        defer { lock.unlock() }
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()
        return index.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.subtitle.lowercased().contains(lowercased)
        }
    }

    private static func buildIndex(chats: [Chat], users: [User]) -> [SearchResult] {
        var results: [SearchResult] = []
        for chat in chats {
            results.append(SearchResult(
                type: chat.type == .group ? .group : .chat,
                title: chat.title,
                subtitle: chat.lastMessage,
                avatarColorHex: chat.avatarColorHex,
                date: chat.lastMessageDate,
                chatID: chat.id
            ))
            results.append(SearchResult(
                type: .message,
                title: chat.title,
                subtitle: chat.lastMessage,
                avatarColorHex: chat.avatarColorHex,
                date: chat.lastMessageDate,
                chatID: chat.id
            ))
        }
        for user in users {
            results.append(SearchResult(
                type: .contact,
                title: user.name,
                subtitle: "@\(user.username)",
                avatarColorHex: user.avatarColorHex,
                userID: user.id
            ))
        }
        return results
    }
}
