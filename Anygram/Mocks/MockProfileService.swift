import Foundation

/// In-memory mock implementation of profile operations.
public final class MockProfileService: ProfileServiceProtocol, @unchecked Sendable {
    private var profiles: [UUID: Profile] = [:]
    private let lock = NSLock()

    public init(userService: UserServiceProtocol) {
        Task {
            let users = (try? await userService.fetchContacts()) ?? []
            lock.lock()
            for user in users {
                profiles[user.id] = Profile(
                    user: user,
                    sharedMediaCount: Int.random(in: 5...50),
                    encryptionEnabled: true
                )
            }
            lock.unlock()
        }
    }

    public func fetchProfile(for userID: UUID) async throws -> Profile {
        lock.lock()
        defer { lock.unlock() }
        guard let profile = profiles[userID] else {
            throw MockServiceError.notFound
        }
        return profile
    }

    public func updateMute(userID: UUID, muted: Bool) async throws -> Profile {
        lock.lock()
        guard var profile = profiles[userID] else {
            lock.unlock()
            throw MockServiceError.notFound
        }
        profile.isMuted = muted
        profiles[userID] = profile
        lock.unlock()
        return profile
    }

    public func updateBlock(userID: UUID, blocked: Bool) async throws -> Profile {
        lock.lock()
        guard var profile = profiles[userID] else {
            lock.unlock()
            throw MockServiceError.notFound
        }
        profile.isBlocked = blocked
        profiles[userID] = profile
        lock.unlock()
        return profile
    }

    public func deleteChat(with userID: UUID) async throws {}
}
