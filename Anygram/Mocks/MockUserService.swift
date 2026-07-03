import Combine
import Foundation

/// In-memory mock implementation of user and contact operations.
public final class MockUserService: UserServiceProtocol, @unchecked Sendable {
    private var contacts: [User]
    private let contactsSubject = CurrentValueSubject<[User], Never>([])
    private let lock = NSLock()

    public init() {
        let users = MockDataGenerator.generateUsers()
        self.contacts = users.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.contactsSubject = CurrentValueSubject(contacts)
    }

    public func fetchContacts() async throws -> [User] {
        lock.lock()
        defer { lock.unlock() }
        return contacts.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public func fetchContact(id: UUID) async throws -> User? {
        lock.lock()
        defer { lock.unlock() }
        return contacts.first { $0.id == id }
    }

    public func searchContacts(query: String) async throws -> [User] {
        lock.lock()
        defer { lock.unlock() }
        guard !query.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query)
        }
    }

    public func togglePinContact(id: UUID) async throws -> User {
        lock.lock()
        guard let index = contacts.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            throw MockServiceError.notFound
        }
        contacts[index].isPinned.toggle()
        let user = contacts[index]
        let updated = contacts
        lock.unlock()
        contactsSubject.send(updated)
        return user
    }

    public func deleteContact(id: UUID) async throws {
        lock.lock()
        contacts.removeAll { $0.id == id }
        let updated = contacts
        lock.unlock()
        contactsSubject.send(updated)
    }

    public func observeContacts() -> AnyPublisher<[User], Never> {
        contactsSubject.eraseToAnyPublisher()
    }
}
