import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching = false

    private let repository: SearchRepository
    private var searchTask: Task<Void, Never>?

    init(repository: SearchRepository) {
        self.repository = repository
    }

    var groupedResults: [(SearchResultType, [SearchResult])] {
        let grouped = Dictionary(grouping: results, by: \.type)
        return SearchResultType.allCases.compactMap { type in
            guard let items = grouped[type], !items.isEmpty else { return nil }
            return (type, items)
        }
    }

    func search() {
        searchTask?.cancel()
        guard !query.isEmpty else {
            results = []
            return
        }
        searchTask = Task {
            isSearching = true
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            results = (try? await repository.search(query: query)) ?? []
            isSearching = false
        }
    }
}

extension SearchResultType: CaseIterable {
    public static var allCases: [SearchResultType] { [.chat, .message, .contact, .group] }

    var title: String {
        switch self {
        case .chat: return "Chats"
        case .message: return "Messages"
        case .contact: return "Contacts"
        case .group: return "Groups"
        }
    }
}
