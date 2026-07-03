import Combine
import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// TDLib-backed chat sync using BetterTG connection patterns (`getChats`, `getChatHistory`, update handlers).
public final class TDLibChatService: ChatServiceProtocol, @unchecked Sendable {
    private var chats: [Chat] = []
    private var messagesByChat: [UUID: [Message]] = [:]
    private var loadedHistoryOffsets: [UUID: Int64] = [:]
    private var currentUserTelegramId: Int64?
    private let chatsSubject: CurrentValueSubject<[Chat], Never>
    private var typingSubjects: [UUID: PassthroughSubject<TypingStatus, Never>] = [:]
    private var updateHandlerID: UUID?
    private let lock = NSLock()

    public init() {
        self.chatsSubject = CurrentValueSubject([])
        _ = TDLibSession.shared.ensureClient { [weak self] _, _ in
            self?.refreshCurrentUserId()
        }
        updateHandlerID = TDLibUpdateRouter.shared.addHandler { [weak self] update in
            self?.handleUpdate(update)
        }
        Task { await reloadAllChats() }
    }

    deinit {
        if let updateHandlerID {
            TDLibUpdateRouter.shared.removeHandler(updateHandlerID)
        }
    }

    public func fetchChats(includeArchived: Bool) async throws -> [Chat] {
        await reloadAllChats()
        lock.lock()
        let snapshot = chats
        lock.unlock()
        let filtered = includeArchived ? snapshot : snapshot.filter { !$0.isArchived }
        return filtered.sorted(by: Self.sortChats)
    }

    public func fetchMessages(for chatID: UUID, page: Int, pageSize: Int) async throws -> [Message] {
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID) else {
            return []
        }

        lock.lock()
        let fromMessageId = loadedHistoryOffsets[chatID] ?? 0
        lock.unlock()

        let history = try await client.getChatHistory(
            chatId: chatTelegramId,
            fromMessageId: fromMessageId,
            limit: pageSize,
            offset: 0,
            onlyLocal: false
        )

        let mapped = await mapMessages(history.messages, chatID: chatID, client: client)
        lock.lock()
        if let oldest = history.messages.last?.id, oldest > 0 {
            loadedHistoryOffsets[chatID] = oldest
        }
        var existing = messagesByChat[chatID, default: []]
        let existingIDs = Set(existing.map(\.id))
        let newMessages = mapped.filter { !existingIDs.contains($0.id) }
        existing.insert(contentsOf: newMessages, at: 0)
        existing.sort { $0.timestamp < $1.timestamp }
        messagesByChat[chatID] = existing
        let result = existing
        lock.unlock()
        return result
    }

    public func sendMessage(_ text: String, to chatID: UUID, replyTo: UUID?) async throws -> Message {
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID) else {
            throw AuthError.notConfigured
        }

        let replyToMessage: InputMessageReplyTo?
        if let replyTo,
           let components = TelegramIdentity.telegramMessageId(from: replyTo),
           components.chatId == chatTelegramId {
            replyToMessage = .inputMessageReplyToMessage(
                InputMessageReplyToMessage(checklistTaskId: 0, messageId: components.messageId, quote: nil)
            )
        } else {
            replyToMessage = nil
        }

        let sent = try await client.sendMessage(
            chatId: chatTelegramId,
            inputMessageContent: .inputMessageText(
                InputMessageText(
                    clearDraft: true,
                    linkPreviewOptions: nil,
                    text: FormattedText(entities: [], text: text)
                )
            ),
            options: nil,
            replyMarkup: nil,
            replyTo: replyToMessage,
            topicId: nil
        )

        let mapped = await mapMessage(sent, chatID: chatID, client: client)
        appendMessage(mapped)
        await reloadAllChats()
        return mapped
    }

    public func deleteChat(_ chatID: UUID) async throws {
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID) else { return }
        _ = try await client.deleteChatHistory(chatId: chatTelegramId, removeFromChatList: true, revoke: false)
        removeChatLocally(chatID)
    }

    public func togglePin(chatID: UUID) async throws -> Chat {
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID) else {
            throw AuthError.notConfigured
        }
        lock.lock()
        let isPinned = chats.first(where: { $0.id == chatID })?.isPinned ?? false
        lock.unlock()
        _ = try await client.toggleChatIsPinned(
            chatId: chatTelegramId,
            chatList: .chatListMain,
            isPinned: !isPinned
        )
        await reloadAllChats()
        lock.lock()
        defer { lock.unlock() }
        guard let chat = chats.first(where: { $0.id == chatID }) else { throw AuthError.unknown }
        return chat
    }

    public func toggleMute(chatID: UUID) async throws -> Chat {
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID),
              let tdChat = try? await client.getChat(chatId: chatTelegramId) else {
            throw AuthError.notConfigured
        }
        let isMuted = tdChat.notificationSettings.muteFor > 0
        var settings = tdChat.notificationSettings
        settings.muteFor = isMuted ? 0 : 365 * 24 * 60 * 60
        _ = try await client.setChatNotificationSettings(chatId: chatTelegramId, notificationSettings: settings)
        await reloadAllChats()
        lock.lock()
        defer { lock.unlock() }
        guard let chat = chats.first(where: { $0.id == chatID }) else { throw AuthError.unknown }
        return chat
    }

    public func archiveChat(_ chatID: UUID) async throws -> Chat {
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID) else {
            throw AuthError.notConfigured
        }
        lock.lock()
        let isArchived = chats.first(where: { $0.id == chatID })?.isArchived ?? false
        lock.unlock()
        if isArchived {
            _ = try await client.removeChatFromList(chatId: chatTelegramId, chatList: .chatListArchive)
        } else {
            _ = try await client.addChatToList(chatId: chatTelegramId, chatList: .chatListArchive)
        }
        await reloadAllChats()
        lock.lock()
        defer { lock.unlock() }
        guard let chat = chats.first(where: { $0.id == chatID }) else { throw AuthError.unknown }
        return chat
    }

    public func addReaction(_ emoji: String, to messageID: UUID, in chatID: UUID) async throws -> Message {
        lock.lock()
        defer { lock.unlock() }
        guard var messages = messagesByChat[chatID],
              let index = messages.firstIndex(where: { $0.id == messageID }) else {
            throw AuthError.unknown
        }
        if let reactionIndex = messages[index].reactions.firstIndex(where: { $0.emoji == emoji }) {
            messages[index].reactions[reactionIndex].count += 1
            messages[index].reactions[reactionIndex].isSelectedByCurrentUser = true
        } else {
            messages[index].reactions.append(Reaction(emoji: emoji, isSelectedByCurrentUser: true))
        }
        messagesByChat[chatID] = messages
        return messages[index]
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

    // MARK: - Sync

    private func reloadAllChats() async {
        guard let client = TDLibSession.shared.tdClient else { return }
        await refreshCurrentUserId()

        async let mainChats = loadChats(from: .chatListMain, archived: false, client: client)
        async let archiveChats = loadChats(from: .chatListArchive, archived: true, client: client)
        let combined = await (mainChats + archiveChats).sorted(by: Self.sortChats)

        lock.lock()
        chats = combined
        lock.unlock()
        chatsSubject.send(combined)
    }

    private func loadChats(from list: ChatList, archived: Bool, client: TDLibClient) async -> [Chat] {
        guard let chatIds = try? await client.getChats(chatList: list, limit: 200).chatIds else {
            return []
        }
        var result: [Chat] = []
        for chatId in chatIds {
            if let chat = await mapChat(chatId: chatId, archived: archived, client: client) {
                result.append(chat)
            }
        }
        return result
    }

    private func mapChat(chatId: Int64, archived: Bool, client: TDLibClient) async -> Chat? {
        guard let tdChat = try? await client.getChat(chatId: chatId) else { return nil }

        let chatUUID = TelegramIdentity.uuid(fromTelegramId: chatId)
        let type = mapChatType(tdChat.type)
        let isPinned = tdChat.positions.contains { $0.isPinned }
        let lastPreview = previewText(for: tdChat.lastMessage)
        let lastDate = Date(timeIntervalSince1970: TimeInterval(tdChat.lastMessage?.date ?? 0))
        let participantIDs = await participantIDs(for: tdChat.type, client: client)

        return Chat(
            id: chatUUID,
            title: tdChat.title,
            type: type,
            participantIDs: participantIDs,
            lastMessage: lastPreview,
            lastMessageDate: lastDate,
            unreadCount: tdChat.unreadCount,
            isPinned: isPinned,
            isMuted: tdChat.notificationSettings.muteFor > 0,
            isArchived: archived,
            isVerified: false,
            isPremium: false,
            avatarColorHex: TelegramIdentity.colorHex(forTelegramId: chatId),
            deliveryState: tdChat.unreadCount > 0 ? .delivered : .read,
            isTyping: false
        )
    }

    private func mapChatType(_ type: TDLibKit.ChatType) -> ChatType {
        switch type {
        case .chatTypePrivate:
            return .privateChat
        case .chatTypeBasicGroup, .chatTypeSupergroup:
            return .group
        case .chatTypeChannel:
            return .channel
        default:
            return .privateChat
        }
    }

    private func participantIDs(for type: TDLibKit.ChatType, client: TDLibClient) async -> [UUID] {
        switch type {
        case .chatTypePrivate(let info):
            return [TelegramIdentity.uuid(fromTelegramId: info.userId)]
        default:
            return []
        }
    }

    private func mapMessages(_ tdMessages: [TDLibKit.Message], chatID: UUID, client: TDLibClient) async -> [Message] {
        var mapped: [Message] = []
        for tdMessage in tdMessages {
            mapped.append(await mapMessage(tdMessage, chatID: chatID, client: client))
        }
        return mapped
    }

    private func mapMessage(_ tdMessage: TDLibKit.Message, chatID: UUID, client: TDLibClient) async -> Message {
        let messageUUID = TelegramIdentity.messageUUID(chatId: tdMessage.chatId, messageId: tdMessage.id)
        let senderUUID: UUID
        switch tdMessage.senderId {
        case .messageSenderUser(let sender):
            senderUUID = TelegramIdentity.uuid(fromTelegramId: sender.userId)
        case .messageSenderChat(let sender):
            senderUUID = TelegramIdentity.uuid(fromTelegramId: sender.chatId)
        default:
            senderUUID = TelegramIdentity.uuid(fromTelegramId: tdMessage.chatId)
        }

        let currentUserId = await currentUserTelegramId()
        let isOutgoing: Bool
        if case .messageSenderUser(let sender) = tdMessage.senderId, let currentUserId {
            isOutgoing = sender.userId == currentUserId
        } else {
            isOutgoing = false
        }

        let text = messageText(from: tdMessage.content)
        let contentType = messageContentType(from: tdMessage.content)
        let replyUUID: UUID?
        if case .messageReplyToMessage(let reply) = tdMessage.replyTo, reply.messageId != 0 {
            replyUUID = TelegramIdentity.messageUUID(chatId: tdMessage.chatId, messageId: reply.messageId)
        } else {
            replyUUID = nil
        }

        return Message(
            id: messageUUID,
            chatID: chatID,
            senderID: senderUUID,
            text: text,
            contentType: contentType,
            timestamp: Date(timeIntervalSince1970: TimeInterval(tdMessage.date)),
            isOutgoing: isOutgoing,
            isEdited: tdMessage.editDate > 0,
            isForwarded: tdMessage.forwardInfo != nil,
            forwardedFrom: nil,
            replyToMessageID: replyUUID,
            deliveryState: isOutgoing ? .sent : .read
        )
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
            return "Unsupported message"
        }
    }

    private func messageContentType(from content: MessageContent) -> MessageContentType {
        switch content {
        case .messageText:
            return .text
        case .messagePhoto:
            return .image
        case .messageVideo:
            return .video
        case .messageVoiceNote:
            return .voice
        case .messageSticker:
            return .sticker
        case .messageDocument:
            return .file
        default:
            return .text
        }
    }

    private func previewText(for message: TDLibKit.Message?) -> String {
        guard let message else { return "" }
        let text = messageText(from: message.content)
        return text.isEmpty ? "New message" : text
    }

    private func refreshCurrentUserId() {
        Task {
            guard let client = TDLibSession.shared.tdClient,
                  let me = try? await client.getMe() else { return }
            lock.lock()
            currentUserTelegramId = me.id
            lock.unlock()
        }
    }

    private func currentUserTelegramId() async -> Int64? {
        lock.lock()
        if let currentUserTelegramId {
            lock.unlock()
            return currentUserTelegramId
        }
        lock.unlock()
        refreshCurrentUserId()
        try? await Task.sleep(nanoseconds: 100_000_000)
        lock.lock()
        defer { lock.unlock() }
        return currentUserTelegramId
    }

    private static func sortChats(lhs: Chat, rhs: Chat) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        return lhs.lastMessageDate > rhs.lastMessageDate
    }

    // MARK: - Updates

    private func handleUpdate(_ update: Update) {
        switch update {
        case .updateAuthorizationState(let state):
            if case .authorizationStateReady = state.authorizationState {
                Task { await reloadAllChats() }
            }
        case .updateNewChat, .updateChatLastMessage, .updateChatReadInbox, .updateChatPosition:
            Task { await reloadAllChats() }
        case .updateNewMessage(let payload):
            let chatUUID = TelegramIdentity.uuid(fromTelegramId: payload.message.chatId)
            Task {
                guard let client = TDLibSession.shared.tdClient else { return }
                let mapped = await mapMessage(payload.message, chatID: chatUUID, client: client)
                appendMessage(mapped)
                await reloadAllChats()
            }
        case .updateDeleteMessages(let payload):
            let chatUUID = TelegramIdentity.uuid(fromTelegramId: payload.chatId)
            lock.lock()
            if var messages = messagesByChat[chatUUID] {
                messages.removeAll { message in
                    guard let components = TelegramIdentity.telegramMessageId(from: message.id) else { return false }
                    return payload.messageIds.contains(components.messageId)
                }
                messagesByChat[chatUUID] = messages
            }
            lock.unlock()
        case .updateChatAction(let payload):
            let chatUUID = TelegramIdentity.uuid(fromTelegramId: payload.chatId)
            lock.lock()
            let subject = typingSubjects[chatUUID]
            lock.unlock()
            if case .chatActionTyping = payload.action {
                subject?.send(
                    TypingStatus(
                        chatID: chatUUID,
                        userID: TelegramIdentity.uuid(fromTelegramId: payload.chatId),
                        userName: "",
                        isTyping: true
                    )
                )
            } else if case .chatActionCancel = payload.action {
                subject?.send(
                    TypingStatus(
                        chatID: chatUUID,
                        userID: TelegramIdentity.uuid(fromTelegramId: payload.chatId),
                        userName: "",
                        isTyping: false
                    )
                )
            }
        default:
            break
        }
    }

    private func appendMessage(_ message: Message) {
        lock.lock()
        var existing = messagesByChat[message.chatID, default: []]
        if !existing.contains(where: { $0.id == message.id }) {
            existing.append(message)
            existing.sort { $0.timestamp < $1.timestamp }
            messagesByChat[message.chatID] = existing
        }
        lock.unlock()
    }

    private func removeChatLocally(_ chatID: UUID) {
        lock.lock()
        chats.removeAll { $0.id == chatID }
        messagesByChat.removeValue(forKey: chatID)
        loadedHistoryOffsets.removeValue(forKey: chatID)
        let snapshot = chats
        lock.unlock()
        chatsSubject.send(snapshot)
    }
}
#endif
