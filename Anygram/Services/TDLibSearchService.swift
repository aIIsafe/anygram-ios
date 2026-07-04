import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// TDLib-backed global search (chats, messages, contacts).
public final class TDLibSearchService: SearchServiceProtocol, @unchecked Sendable {
    public init() {}

    public func indexAll() async {}

    public func search(query: String) async throws -> [SearchResult] {
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return [] }
        guard let client = TDLibSession.shared.tdClient else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        async let chatResults = searchChats(query: trimmed, client: client)
        async let messageResults = searchMessages(query: trimmed, client: client)
        async let contactResults = searchContacts(query: trimmed, client: client)
        let combined = await chatResults + messageResults + contactResults
        return combined.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private func searchChats(query: String, client: TDLibClient) async -> [SearchResult] {
        guard let chatIds = try? await client.searchChats(query: query, limit: 20).chatIds else {
            return []
        }
        var results: [SearchResult] = []
        for chatId in chatIds {
            guard let tdChat = try? await client.getChat(chatId: chatId) else { continue }
            let chatUUID = TelegramIdentity.uuid(fromTelegramId: chatId)
            let preview = previewText(for: tdChat.lastMessage)
            let type: SearchResultType
            switch tdChat.type {
            case .chatTypeSupergroup(let info):
                type = info.isChannel ? .group : .group
            case .chatTypeBasicGroup:
                type = .group
            default:
                type = .chat
            }
            results.append(SearchResult(
                type: type,
                title: tdChat.title,
                subtitle: preview,
                avatarColorHex: TelegramIdentity.colorHex(forTelegramId: chatId),
                date: Date(timeIntervalSince1970: TimeInterval(tdChat.lastMessage?.date ?? 0)),
                chatID: chatUUID
            ))
        }
        return results
    }

    private func searchMessages(query: String, client: TDLibClient) async -> [SearchResult] {
        guard let found = try? await client.searchMessages(
            chatList: .chatListMain,
            query: query,
            offset: "",
            limit: 20,
            filter: nil,
            minDate: 0,
            maxDate: 0
        ) else {
            return []
        }

        var results: [SearchResult] = []
        for tdMessage in found.messages ?? [] {
            guard let tdChat = try? await client.getChat(chatId: tdMessage.chatId) else { continue }
            let text = messageText(from: tdMessage.content)
            results.append(SearchResult(
                type: .message,
                title: tdChat.title,
                subtitle: text,
                avatarColorHex: TelegramIdentity.colorHex(forTelegramId: tdMessage.chatId),
                date: Date(timeIntervalSince1970: TimeInterval(tdMessage.date)),
                chatID: TelegramIdentity.uuid(fromTelegramId: tdMessage.chatId),
                messageID: TelegramIdentity.messageUUID(chatId: tdMessage.chatId, messageId: tdMessage.id)
            ))
        }
        return results
    }

    private func searchContacts(query: String, client: TDLibClient) async -> [SearchResult] {
        guard let users = try? await client.searchContacts(query: query, limit: 20).userIds else {
            return []
        }
        var results: [SearchResult] = []
        for userId in users {
            guard let tdUser = try? await client.getUser(userId: userId) else { continue }
            let user = mapTDLibUser(tdUser)
            results.append(SearchResult(
                type: .contact,
                title: user.name,
                subtitle: user.username.isEmpty ? user.phone : "@\(user.username)",
                avatarColorHex: user.avatarColorHex,
                userID: user.id
            ))
        }
        return results
    }

    private func messageText(from content: MessageContent) -> String {
        switch content {
        case .messageText(let value):
            return value.text.text
        case .messagePhoto(let value):
            return value.caption.text.isEmpty ? "📷 Photo" : value.caption.text
        case .messageVideo(let value):
            return value.caption.text.isEmpty ? "🎬 Video" : value.caption.text
        case .messageVoiceNote:
            return "🎤 Voice message"
        case .messageSticker(let value):
            return value.sticker.emoji
        case .messageDocument(let value):
            return value.caption.text.isEmpty ? "📎 Document" : value.caption.text
        default:
            return "Message"
        }
    }

    private func previewText(for message: TDLibKit.Message?) -> String {
        guard let message else { return "" }
        let text = messageText(from: message.content)
        return text.isEmpty ? "New message" : text
    }

    private func mapTDLibUser(_ tdUser: TDLibKit.User) -> User {
        let firstName = tdUser.firstName
        let lastName = tdUser.lastName
        let displayName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        let username = tdUser.usernames?.editableUsername
            ?? tdUser.usernames?.activeUsernames.first
            ?? ""
        return User(
            id: TelegramIdentity.uuid(fromTelegramId: tdUser.id),
            name: displayName.isEmpty ? firstName : displayName,
            username: username,
            avatarColorHex: TelegramIdentity.colorHex(forTelegramId: tdUser.id),
            phone: tdUser.phoneNumber,
            bio: "",
            status: "",
            isOnline: false,
            isPremium: tdUser.isPremium,
            isVerified: tdUser.verificationStatus?.isVerified ?? false
        )
    }
}
#endif
