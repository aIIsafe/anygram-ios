import Combine
import Foundation

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var contacts: [User] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: UserRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: UserRepository) {
        self.repository = repository
        repository.observeContacts()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contacts in
                self?.contacts = contacts
            }
            .store(in: &cancellables)
    }

    var filteredContacts: [User] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var pinnedContacts: [User] {
        filteredContacts.filter(\.isPinned)
    }

    var groupedContacts: [(String, [User])] {
        let regular = filteredContacts.filter { !$0.isPinned }
        let grouped = Dictionary(grouping: regular) { $0.name.sectionLetter }
        return grouped.sorted { $0.key < $1.key }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            contacts = try await repository.fetchContacts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteContact(_ user: User) async {
        try? await repository.deleteContact(id: user.id)
        await load()
    }

    func togglePin(_ user: User) async {
        _ = try? await repository.togglePinContact(id: user.id)
        await load()
    }
}
