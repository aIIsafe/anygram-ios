import Foundation

/// Contract for user profile detail operations.
public protocol ProfileServiceProtocol: Sendable {
    func fetchProfile(for userID: UUID) async throws -> Profile
    func updateMute(userID: UUID, muted: Bool) async throws -> Profile
    func updateBlock(userID: UUID, blocked: Bool) async throws -> Profile
    func deleteChat(with userID: UUID) async throws
}
