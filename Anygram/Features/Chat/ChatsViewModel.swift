import Combine
import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var archivedChats: [Chat] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var showArchived = false
    @Published var errorMessage: String?

    private let repository: ChatRepository
    private let isAuthenticated: () -> Bool

    init(repository: ChatRepository, isAuthenticated: @escaping () -> Bool = { true }) {
        self.repository = repository
        self.isAuthenticated = isAuthenticated
        repository.observeChats()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chats in
                guard let self else { return }
                self.archivedChats = chats.filter(\.isArchived)
                self.chats = chats.filter { !$0.isArchived }
                if !chats.isEmpty {
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    var filteredChats: [Chat] {
        let source = showArchived ? archivedChats : chats.filter { !$0.isArchived }
        guard !searchText.isEmpty else { return source }
        return source.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.lastMessage.localizedCaseInsensitiveContains(searchText)
        }
    }

    var pinnedChats: [Chat] {
        filteredChats.filter(\.isPinned)
    }

    var regularChats: [Chat] {
        filteredChats.filter { !$0.isPinned }
    }

    func load() async {
        guard isAuthenticated() else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await withLoadTimeout {
                try await repository.fetchChats(includeArchived: true)
            }
            archivedChats = fetched.filter(\.isArchived)
            chats = fetched.filter { !$0.isArchived }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteChat(_ chat: Chat) async {
        do {
            try await repository.deleteChat(chat.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePin(_ chat: Chat) async {
        _ = try? await repository.togglePin(chatID: chat.id)
        await load()
    }

    func toggleMute(_ chat: Chat) async {
        _ = try? await repository.toggleMute(chatID: chat.id)
        await load()
    }

    func archive(_ chat: Chat) async {
        _ = try? await repository.archiveChat(chat.id)
        await load()
    }

    func prefetchMessages(for chatID: UUID) async {
        await repository.prefetchMessages(for: chatID)
    }

    private func withLoadTimeout<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await AsyncTimeout.withTimeout(seconds: 20, error: ChatLoadTimeoutError()) {
            try await operation()
        }
    }
}

private struct ChatLoadTimeoutError: LocalizedError {
    var errorDescription: String? {
        "Chat list load timed out"
    }
}
