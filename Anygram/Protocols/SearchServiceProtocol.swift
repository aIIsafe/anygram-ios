import Foundation

/// Contract for global search operations.
public protocol SearchServiceProtocol: Sendable {
    func search(query: String) async throws -> [SearchResult]
    func indexAll() async
}
