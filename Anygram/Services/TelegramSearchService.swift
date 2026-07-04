import Foundation

/// Production search service — delegates to TDLib when available, otherwise mock data.
public final class TelegramSearchService: SearchServiceProtocol, @unchecked Sendable {
    #if USE_SCAFFOLD_AUTH
    private let backend: MockSearchService
    #elseif targetEnvironment(simulator)
    private let backend: MockSearchService
    #elseif canImport(TDLibKit)
    private let backend: TDLibSearchService
    #else
    private let backend: MockSearchService
    #endif

    public init(chatService: ChatServiceProtocol, userService: UserServiceProtocol) {
        #if USE_SCAFFOLD_AUTH
        self.backend = MockSearchService(chatService: chatService, userService: userService)
        #elseif targetEnvironment(simulator)
        self.backend = MockSearchService(chatService: chatService, userService: userService)
        #elseif canImport(TDLibKit)
        self.backend = TDLibSearchService()
        #else
        self.backend = MockSearchService(chatService: chatService, userService: userService)
        #endif
    }

    public func search(query: String) async throws -> [SearchResult] {
        try await backend.search(query: query)
    }

    public func indexAll() async {
        await backend.indexAll()
    }
}
