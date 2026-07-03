import Combine
import Foundation

/// Repository mediating contact data between ViewModels and services.
@MainActor
public final class UserRepository: ObservableObject {
    private let userService: UserServiceProtocol
    private var cachedContacts: [User] = []
    private var cancellables = Set<AnyCancellable>()

    public init(userService: UserServiceProtocol) {
        self.userService = userService
        userService.observeContacts()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contacts in
                self?.cachedContacts = contacts
            }
            .store(in: &cancellables)
    }

    public func fetchContacts() async throws -> [User] {
        let contacts = try await userService.fetchContacts()
        cachedContacts = contacts
        return contacts
    }

    public func fetchContact(id: UUID) async throws -> User? {
        try await userService.fetchContact(id: id)
    }

    public func searchContacts(query: String) async throws -> [User] {
        try await userService.searchContacts(query: query)
    }

    public func togglePinContact(id: UUID) async throws -> User {
        try await userService.togglePinContact(id: id)
    }

    public func deleteContact(id: UUID) async throws {
        try await userService.deleteContact(id: id)
    }
}
