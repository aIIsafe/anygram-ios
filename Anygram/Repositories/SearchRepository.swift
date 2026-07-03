import Foundation

/// Repository mediating search operations between ViewModels and services.
@MainActor
public final class SearchRepository: ObservableObject {
    private let searchService: SearchServiceProtocol

    public init(searchService: SearchServiceProtocol) {
        self.searchService = searchService
    }

    public func search(query: String) async throws -> [SearchResult] {
        try await searchService.search(query: query)
    }

    public func reindex() async {
        await searchService.indexAll()
    }
}
