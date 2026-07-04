import Combine
import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// TDLib-backed chat sync using BetterTG connection patterns (`getChats`, `getChatHistory`, update handlers).
public final class TDLibChatService: ChatServiceProtocol, @unchecked Sendable {
    private var chats: [Chat] = []
    private var messagesByChat: [UUID: [Message]] = [:]
    private var messagesSubjects: [UUID: CurrentValueSubject<[Message], Never>] = [:]
    private var loadedHistoryOffsets: [UUID: Int64] = [:]
    private var historyLoadTasks: [UUID: Task<[Message], Never>] = [:]
    private var currentUserTelegramId: Int64?
    private let chatsSubject: CurrentValueSubject<[Chat], Never>
    private var typingSubjects: [UUID: PassthroughSubject<TypingStatus, Never>] = [:]
    private var updateHandlerID: UUID?
    private let lock = NSLock()

    public init() {
        self.chatsSubject = CurrentValueSubject([])
        updateHandlerID = TDLibUpdateRouter.shared.addHandler { [weak self] update in
            self?.handleUpdate(update)
        }
    }

    deinit {
        if let updateHandlerID {
            TDLibUpdateRouter.shared.removeHandler(updateHandlerID)
        }
    }

    public func fetchChats(includeArchived: Bool) async throws -> [Chat] {
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return [] }
        await reloadAllChats()
        lock.lock()
        let snapshot = chats
        lock.unlock()
        let filtered = includeArchived ? snapshot : snapshot.filter { !$0.isArchived }
        return filtered.sorted(by: Self.sortChats)
    }

    public func cachedMessages(for chatID: UUID) -> [Message] {
        lock.lock()
        defer { lock.unlock() }
        return messagesByChat[chatID] ?? []
    }

    public func prefetchMessages(for chatID: UUID) async {
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return }
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID) else { return }
        await openChatIfNeeded(chatTelegramId: chatTelegramId, client: client)
        _ = await loadHistoryResilient(
            chatID: chatID,
            chatTelegramId: chatTelegramId,
            fromMessageId: 0,
            limit: 30,
            client: client
        )
    }

    public func openChat(_ chatID: UUID) async {
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return }
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID) else { return }
        await openChatIfNeeded(chatTelegramId: chatTelegramId, client: client)
    }

    public func closeChat(_ chatID: UUID) async {
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID) else { return }
        _ = try? await client.closeChat(chatId: chatTelegramId)
    }

    public func fetchMessages(for chatID: UUID, page: Int, pageSize: Int) async throws -> [Message] {
        await waitForAuthorizedAccess()

        lock.lock()
        let cached = messagesByChat[chatID] ?? []
        lock.unlock()

        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else {
            AppDebugLogger.shared.log(
                "fetchMessages: TDLib not authorized, returning \(cached.count) cached",
                category: .CHAT
            )
            return cached
        }
        guard let client = TDLibSession.shared.tdClient,
              let chatTelegramId = TelegramIdentity.telegramId(from: chatID) else {
            AppDebugLogger.shared.log(
                "fetchMessages: missing client or chat mapping for \(chatID.uuidString.prefix(8))",
                category: .CHAT
            )
            return cached
        }

        await openChatIfNeeded(chatTelegramId: chatTelegramId, client: client)

        lock.lock()
        let fromMessageId = page == 0 ? 0 : (loadedHistoryOffsets[chatID] ?? 0)
        lock.unlock()

        let result = await loadHistoryResilient(
            chatID: chatID,
            chatTelegramId: chatTelegramId,
            fromMessageId: fromMessageId,
            limit: pageSize,
            client: client
        )

        if page == 0,
           let lastMessage = result.last,
           let components = TelegramIdentity.telegramMessageId(from: lastMessage.id) {
            do {
                _ = try await client.viewMessages(
                    chatId: chatTelegramId,
                    forceRead: true,
                    messageIds: [components.messageId],
                    source: .messageSourceChatHistory
                )
            } catch {
                AppDebugLogger.shared.log(
                    "viewMessages failed chatId=\(chatTelegramId): \(Self.tdlibErrorMessage(error))",
                    category: .CHAT
                )
            }
        }

        AppDebugLogger.shared.log(
            "fetchMessages chatId=\(chatTelegramId) page=\(page) count=\(result.count)",
            category: .CHAT
        )
        return result
    }

    public func observeMessages(for chatID: UUID) -> AnyPublisher<[Message], Never> {
        lock.lock()
        if messagesSubjects[chatID] == nil {
            let initial = messagesByChat[chatID] ?? []
            messagesSubjects[chatID] = CurrentValueSubject(initial)
        }
        let subject = messagesSubjects[chatID]!
        lock.unlock()
        return subject.eraseToAnyPublisher()
    }

    public func sendMessage(_ text: String, to chatID: UUID, replyTo: UUID?) async throws -> Message {
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { throw AuthError.notConfigured }
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
        let old = tdChat.notificationSettings
        let settings = ChatNotificationSettings(
            disableMentionNotifications: old.disableMentionNotifications,
            disablePinnedMessageNotifications: old.disablePinnedMessageNotifications,
            muteFor: isMuted ? 0 : 365 * 24 * 60 * 60,
            muteStories: old.muteStories,
            showPreview: old.showPreview,
            showStoryPoster: old.showStoryPoster,
            soundId: old.soundId,
            storySoundId: old.storySoundId,
            useDefaultDisableMentionNotifications: old.useDefaultDisableMentionNotifications,
            useDefaultDisablePinnedMessageNotifications: old.useDefaultDisablePinnedMessageNotifications,
            useDefaultMuteFor: false,
            useDefaultMuteStories: old.useDefaultMuteStories,
            useDefaultShowPreview: old.useDefaultShowPreview,
            useDefaultShowStoryPoster: old.useDefaultShowStoryPoster,
            useDefaultSound: old.useDefaultSound,
            useDefaultStorySound: old.useDefaultStorySound
        )
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
        let targetList: ChatList = isArchived ? .chatListMain : .chatListArchive
        _ = try await client.addChatToList(chatId: chatTelegramId, chatList: targetList)
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

    // MARK: - History

    private func openChatIfNeeded(chatTelegramId: Int64, client: TDLibClient) async {
        do {
            _ = try await client.openChat(chatId: chatTelegramId)
        } catch {
            AppDebugLogger.shared.log(
                "openChat failed chatId=\(chatTelegramId): \(Self.tdlibErrorMessage(error))",
                category: .CHAT
            )
        }
    }

    private func loadHistoryResilient(
        chatID: UUID,
        chatTelegramId: Int64,
        fromMessageId: Int64,
        limit: Int,
        client: TDLibClient
    ) async -> [Message] {
        lock.lock()
        if let existingTask = historyLoadTasks[chatID] {
            lock.unlock()
            return await existingTask.value
        }

        let task = Task { [weak self] in
            guard let self else { return [] }
            return await self.performLoadAndMergeHistory(
                chatID: chatID,
                chatTelegramId: chatTelegramId,
                fromMessageId: fromMessageId,
                limit: limit,
                client: client
            )
        }
        historyLoadTasks[chatID] = task
        lock.unlock()

        let result = await task.value

        lock.lock()
        historyLoadTasks.removeValue(forKey: chatID)
        lock.unlock()
        return result
    }

    private func performLoadAndMergeHistory(
        chatID: UUID,
        chatTelegramId: Int64,
        fromMessageId: Int64,
        limit: Int,
        client: TDLibClient
    ) async -> [Message] {
        lock.lock()
        let cached = messagesByChat[chatID] ?? []
        lock.unlock()

        do {
            var rawMessages = try await requestChatHistory(
                chatTelegramId: chatTelegramId,
                fromMessageId: fromMessageId,
                limit: limit,
                onlyLocal: true,
                client: client
            )
            if rawMessages.isEmpty {
                rawMessages = try await requestChatHistory(
                    chatTelegramId: chatTelegramId,
                    fromMessageId: fromMessageId,
                    limit: limit,
                    onlyLocal: false,
                    client: client
                )
            }

            let mapped = await mapMessages(rawMessages, chatID: chatID, client: client)
            lock.lock()
            if let oldest = rawMessages.last?.id, oldest > 0 {
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
            publishMessages(for: chatID)
            AppDebugLogger.shared.log(
                "getChatHistory OK chatId=\(chatTelegramId) fetched=\(rawMessages.count) total=\(result.count)",
                category: .CHAT
            )
            return result
        } catch {
            AppDebugLogger.shared.log(
                "getChatHistory failed chatId=\(chatTelegramId): \(Self.tdlibErrorMessage(error))",
                category: .CHAT
            )
            return cached
        }
    }

    private func requestChatHistory(
        chatTelegramId: Int64,
        fromMessageId: Int64,
        limit: Int,
        onlyLocal: Bool,
        client: TDLibClient
    ) async throws -> [TDLibKit.Message] {
        let history = try await client.getChatHistory(
            chatId: chatTelegramId,
            fromMessageId: fromMessageId,
            limit: limit,
            offset: 0,
            onlyLocal: onlyLocal
        )
        return history.messages ?? []
    }

    private static func tdlibErrorMessage(_ error: Swift.Error) -> String {
        if let tdError = error as? TDLibKit.Error {
            return "\(tdError.message) (code \(tdError.code))"
        }
        return error.localizedDescription
    }

    private func publishMessages(for chatID: UUID) {
        lock.lock()
        let messages = messagesByChat[chatID] ?? []
        let subject = messagesSubjects[chatID]
        lock.unlock()
        subject?.send(messages)
    }

    // MARK: - Sync

    private func reloadAllChats() async {
        await waitForAuthorizedAccess()
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return }
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

    private func waitForAuthorizedAccess() async {
        for _ in 0..<30 {
            if TDLibAccessGate.shared.canCallAuthenticatedAPI { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func loadChats(from list: ChatList, archived: Bool, client: TDLibClient) async -> [Chat] {
        _ = try? await client.loadChats(chatList: list, limit: 100)

        var chatIds: [Int64] = []
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if let ids = try? await client.getChats(chatList: list, limit: 200).chatIds, !ids.isEmpty {
                chatIds = ids
                break
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        if chatIds.isEmpty,
           let ids = try? await client.getChats(chatList: list, limit: 200).chatIds {
            chatIds = ids
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
        case .chatTypeBasicGroup:
            return .group
        case .chatTypeSupergroup(let info):
            return info.isChannel ? .channel : .group
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
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return }
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
                TDLibAccessGate.shared.markAuthorized()
                Task { await reloadAllChats() }
            }
        case .updateNewChat, .updateChatLastMessage, .updateChatReadInbox, .updateChatPosition:
            guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return }
            Task { await reloadAllChats() }
        case .updateNewMessage(let payload):
            guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return }
            let chatUUID = TelegramIdentity.uuid(fromTelegramId: payload.message.chatId)
            Task {
                guard let client = TDLibSession.shared.tdClient else { return }
                let mapped = await mapMessage(payload.message, chatID: chatUUID, client: client)
                appendMessage(mapped)
                await reloadAllChats()
            }
        case .updateDeleteMessages(let payload):
            guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return }
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
            publishMessages(for: chatUUID)
        case .updateChatAction(let payload):
            guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return }
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
        publishMessages(for: message.chatID)
    }

    private func removeChatLocally(_ chatID: UUID) {
        lock.lock()
        chats.removeAll { $0.id == chatID }
        messagesByChat.removeValue(forKey: chatID)
        loadedHistoryOffsets.removeValue(forKey: chatID)
        messagesSubjects.removeValue(forKey: chatID)
        let snapshot = chats
        lock.unlock()
        chatsSubject.send(snapshot)
    }
}
#endif
