import Combine
import Foundation

/// Contract for contact and user profile operations.
public protocol UserServiceProtocol: Sendable {
    func fetchContacts() async throws -> [User]
    func fetchContact(id: UUID) async throws -> User?
    func searchContacts(query: String) async throws -> [User]
    func togglePinContact(id: UUID) async throws -> User
    func deleteContact(id: UUID) async throws
    func observeContacts() -> AnyPublisher<[User], Never>
    func fetchCurrentUser() async throws -> User?
}
