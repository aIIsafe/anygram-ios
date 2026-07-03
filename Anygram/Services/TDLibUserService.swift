import Combine
import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Fetches the authenticated Telegram account profile via TDLib.
public final class TDLibUserService: UserServiceProtocol, @unchecked Sendable {
    private let contactsSubject = CurrentValueSubject<[User], Never>([])
    private var cachedCurrentUser: User?
    private var updateHandlerID: UUID?
    private let lock = NSLock()

    public init() {
        updateHandlerID = TDLibUpdateRouter.shared.addHandler { [weak self] update in
            if case .updateAuthorizationState(let state) = update,
               case .authorizationStateReady = state.authorizationState {
                Task { _ = try? await self?.fetchContacts() }
            }
        }
    }

    deinit {
        if let updateHandlerID {
            TDLibUpdateRouter.shared.removeHandler(updateHandlerID)
        }
    }

    public func fetchCurrentUser() async throws -> User? {
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return nil }
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
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return [] }
        guard let client = TDLibSession.shared.tdClient else { return [] }
        let contacts = try await client.getContacts()
        var users: [User] = []
        for userId in contacts.userIds {
            guard let tdUser = try? await client.getUser(userId: userId) else { continue }
            users.append(Self.mapTDLibUser(tdUser))
        }
        users.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        contactsSubject.send(users)
        return users
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
            isVerified: tdUser.verificationStatus?.isVerified ?? false
        )
    }
}
#endif
