import Combine
import Foundation

@MainActor
final class ChatDetailViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var chat: Chat
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isTyping = false
    @Published var selectedMessageIDs: Set<UUID> = []
    @Published var replyToMessage: Message?
    @Published var unreadSeparatorIndex: Int?

    private let repository: ChatRepository
    private var currentPage = 0
    private var cancellables = Set<AnyCancellable>()

    init(chat: Chat, repository: ChatRepository) {
        self.chat = chat
        self.repository = repository
        messages = repository.cachedMessages(for: chat.id)

        repository.observeMessages(for: chat.id)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updated in
                guard let self, !updated.isEmpty else { return }
                self.messages = updated
                self.refreshUnreadSeparator()
            }
            .store(in: &cancellables)
    }

    func load() async {
        errorMessage = nil

        let cached = repository.cachedMessages(for: chat.id)
        if !cached.isEmpty {
            messages = cached
        } else {
            isLoading = true
        }

        defer { isLoading = false }

        await repository.openChat(chat.id)

        do {
            let fetched = try await repository.fetchMessages(for: chat.id, page: currentPage)
            if !fetched.isEmpty || messages.isEmpty {
                messages = fetched
            }
            refreshUnreadSeparator()
            simulateTyping()
        } catch {
            AppDebugLogger.shared.log(
                "ChatDetail load failed chat=\(chat.title): \(error.localizedDescription)",
                category: .CHAT
            )
            if messages.isEmpty {
                errorMessage = Self.userFacingError(error)
            }
        }
    }

    private static func userFacingError(_ error: Error) -> String {
        #if canImport(TDLibKit)
        if let tdError = error as? TDLibKit.Error {
            return tdError.message
        }
        #endif
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    func close() async {
        await repository.closeChat(chat.id)
    }

    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = inputText
        inputText = ""
        let replyID = replyToMessage?.id
        replyToMessage = nil
        if let message = try? await repository.sendMessage(text, to: chat.id, replyTo: replyID) {
            messages.append(message)
        }
    }

    func toggleSelection(_ message: Message) {
        if selectedMessageIDs.contains(message.id) {
            selectedMessageIDs.remove(message.id)
        } else {
            selectedMessageIDs.insert(message.id)
        }
    }

    func addReaction(_ emoji: String, to message: Message) async {
        if let updated = try? await repository.addReaction(emoji, to: message.id, in: chat.id),
           let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = updated
        }
    }

    func replyPreview(for messageID: UUID) -> String? {
        messages.first { $0.id == messageID }?.text
    }

    func groupedMessages() -> [(String, [Message])] {
        let grouped = Dictionary(grouping: messages) { $0.timestamp.messageSeparatorFormatted }
        return grouped.sorted { lhs, rhs in
            guard let lDate = messages.first(where: { $0.timestamp.messageSeparatorFormatted == lhs.key })?.timestamp,
                  let rDate = messages.first(where: { $0.timestamp.messageSeparatorFormatted == rhs.key })?.timestamp else {
                return lhs.key < rhs.key
            }
            return lDate < rDate
        }
    }

    private func refreshUnreadSeparator() {
        if let firstUnread = messages.firstIndex(where: { !$0.isOutgoing && $0.deliveryState != .read }) {
            unreadSeparatorIndex = firstUnread
        } else {
            unreadSeparatorIndex = nil
        }
    }

    private func simulateTyping() {
        guard chat.isTyping else { return }
        isTyping = true
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            isTyping = false
        }
    }
}
