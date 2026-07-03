import Foundation

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var contacts: [User] = []
    @Published var searchText = ""
    @Published var isLoading = false

    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
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
        defer { isLoading = false }
        contacts = (try? await repository.fetchContacts()) ?? []
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
