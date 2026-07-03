import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var sharedMedia: [Media] = []
    @Published var selectedMediaTab = 0
    @Published var isLoading = false

    let userID: UUID
    private let repository: ProfileRepository

    init(userID: UUID, repository: ProfileRepository) {
        self.userID = userID
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        profile = try? await repository.fetchProfile(for: userID)
        sharedMedia = (try? await repository.fetchSharedMedia(for: userID)) ?? []
    }

    func toggleMute() async {
        guard let profile else { return }
        self.profile = try? await repository.updateMute(userID: userID, muted: !profile.isMuted)
    }

    func toggleBlock() async {
        guard let profile else { return }
        self.profile = try? await repository.updateBlock(userID: userID, blocked: !profile.isBlocked)
    }

    func deleteChat() async {
        try? await repository.deleteChat(with: userID)
    }

    var filteredMedia: [Media] {
        switch selectedMediaTab {
        case 0: return sharedMedia.filter { $0.type == .photo || $0.type == .video }
        case 1: return sharedMedia.filter { $0.type == .file }
        case 2: return sharedMedia.filter { $0.type == .link }
        default: return sharedMedia.filter { $0.type == .voice }
        }
    }
}
