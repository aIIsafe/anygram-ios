import Foundation

/// Repository mediating profile data between ViewModels and services.
@MainActor
public final class ProfileRepository: ObservableObject {
    private let profileService: ProfileServiceProtocol
    private let mediaService: MediaServiceProtocol

    public init(profileService: ProfileServiceProtocol, mediaService: MediaServiceProtocol) {
        self.profileService = profileService
        self.mediaService = mediaService
    }

    public func fetchProfile(for userID: UUID) async throws -> Profile {
        try await profileService.fetchProfile(for: userID)
    }

    public func fetchSharedMedia(for userID: UUID) async throws -> [Media] {
        try await mediaService.fetchSharedMedia(for: userID)
    }

    public func updateMute(userID: UUID, muted: Bool) async throws -> Profile {
        try await profileService.updateMute(userID: userID, muted: muted)
    }

    public func updateBlock(userID: UUID, blocked: Bool) async throws -> Profile {
        try await profileService.updateBlock(userID: userID, blocked: blocked)
    }

    public func deleteChat(with userID: UUID) async throws {
        try await profileService.deleteChat(with: userID)
    }
}
