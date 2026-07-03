import Combine
import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Fetches the authenticated Telegram account profile via TDLib.
public final class TDLibUserService: UserServiceProtocol, @unchecked Sendable {
    private let contactsSubject = CurrentValueSubject<[User], Never>([])
    private var cachedCurrentUser: User?
    private let lock = NSLock()

    public init() {}

    public func fetchCurrentUser() async throws -> User? {
        guard let client = TDLibSession.shared.tdClient else { return nil }
        let tdUser = try await client.getMe()
        let user = Self.mapTDLibUser(tdUser)
        lock.lock()
        cachedCurrentUser = user
        lock.unlock()
        contactsSubject.send([user])
        return user
    }

    public func fetchContacts() async throws -> [User] {
        if let cachedCurrentUser {
            return [cachedCurrentUser]
        }
        if let current = try await fetchCurrentUser() {
            return [current]
        }
        return []
    }

    public func fetchContact(id: UUID) async throws -> User? {
        try await fetchContacts().first { $0.id == id }
    }

    public func searchContacts(query: String) async throws -> [User] {
        let contacts = try await fetchContacts()
        guard !query.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query)
        }
    }

    public func togglePinContact(id: UUID) async throws -> User {
        guard let user = try await fetchContact(id: id) else {
            throw AuthError.unknown
        }
        return user
    }

    public func deleteContact(id: UUID) async throws {}

    public func observeContacts() -> AnyPublisher<[User], Never> {
        contactsSubject.eraseToAnyPublisher()
    }

    private static func mapTDLibUser(_ tdUser: TDLibKit.User) -> User {
        let firstName = tdUser.firstName
        let lastName = tdUser.lastName
        let displayName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        let username = tdUser.usernames?.editableUsername
            ?? tdUser.usernames?.activeUsernames.first
            ?? ""
        let isOnline: Bool
        if case .userStatusOnline = tdUser.status {
            isOnline = true
        } else {
            isOnline = false
        }

        return User(
            id: TelegramIdentity.uuid(fromTelegramId: tdUser.id),
            name: displayName.isEmpty ? firstName : displayName,
            username: username,
            avatarColorHex: TelegramIdentity.colorHex(forTelegramId: tdUser.id),
            phone: tdUser.phoneNumber,
            bio: "",
            status: "",
            isOnline: isOnline,
            isPremium: tdUser.isPremium,
            isVerified: tdUser.isVerified
        )
    }
}
#endif
