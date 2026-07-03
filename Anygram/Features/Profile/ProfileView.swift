import SwiftUI

struct ProfileView: View {
    let userID: UUID
    @StateObject private var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    init(userID: UUID, container: DIContainer) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userID: userID, repository: container.profileRepository))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                if let profile = viewModel.profile {
                    VStack(spacing: AppSpacing.sm) {
                        AvatarView(
                            name: profile.user.name,
                            colorHex: profile.user.avatarColorHex,
                            size: 100,
                            isOnline: profile.user.isOnline,
                            showOnlineIndicator: true
                        )
                        .scaleEffect(1.0)
                        .animation(AppAnimation.spring, value: profile.user.isOnline)

                        Text(profile.user.name)
                            .font(AppTypography.largeTitle)
                            .foregroundStyle(AppColors.textPrimary)

                        HStack(spacing: 4) {
                            Text("@\(profile.user.username)")
                                .foregroundStyle(AppColors.textSecondary)
                            if profile.user.isVerified { VerifiedBadge() }
                            if profile.user.isPremium { PremiumBadge() }
                        }
                        .font(AppTypography.subheadline)

                        if !profile.user.bio.isEmpty {
                            Text(profile.user.bio)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        Text(profile.user.phone)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(.top, AppSpacing.lg)

                    HStack(spacing: AppSpacing.md) {
                        profileActionButton(icon: "message.fill", title: L10n.messagePlaceholder) {}
                        profileActionButton(icon: "phone.fill", title: L10n.tabCalls) {}
                        profileActionButton(icon: "video.fill", title: L10n.videos) {}
                        profileActionButton(icon: "ellipsis", title: L10n.other) {}
                    }
                    .padding(.horizontal, AppSpacing.md)

                    VStack(spacing: 0) {
                        SettingsRowView(icon: "bell.fill", title: L10n.notifications, subtitle: profile.notificationEnabled ? L10n.connected : L10n.disconnected, showChevron: true)
                        SettingsRowView(icon: "lock.fill", title: "Encryption", subtitle: profile.encryptionEnabled ? "End-to-end encrypted" : "Not encrypted", iconColor: AppColors.online)
                    }
                    .background(AppColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    .padding(.horizontal, AppSpacing.md)

                    VStack(spacing: AppSpacing.sm) {
                        Picker("Media", selection: $viewModel.selectedMediaTab) {
                            Text("Media").tag(0)
                            Text("Files").tag(1)
                            Text("Links").tag(2)
                            Text("Voice").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, AppSpacing.md)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                            ForEach(viewModel.filteredMedia) { media in
                                RoundedRectangle(cornerRadius: AppRadius.small)
                                    .fill(Color(hex: media.thumbnailColorHex))
                                    .frame(height: 100)
                                    .overlay {
                                        Image(systemName: mediaIcon(for: media.type))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    VStack(spacing: 0) {
                        Button { Task { await viewModel.toggleMute() } } label: {
                            SettingsRowView(
                                icon: "speaker.slash.fill",
                                title: profile.isMuted ? L10n.unmute : L10n.mute,
                                iconColor: AppColors.muted,
                                showChevron: false
                            )
                        }
                        Button { Task { await viewModel.toggleBlock() } } label: {
                            SettingsRowView(
                                icon: "hand.raised.fill",
                                title: profile.isBlocked ? "Unblock" : "Block",
                                iconColor: AppColors.destructive,
                                showChevron: false
                            )
                        }
                        Button(role: .destructive) { Task { await viewModel.deleteChat(); dismiss() } } label: {
                            SettingsRowView(
                                icon: "trash.fill",
                                title: L10n.delete,
                                iconColor: AppColors.destructive,
                                showChevron: false
                            )
                        }
                    }
                    .background(AppColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    .padding(.horizontal, AppSpacing.md)
                } else if viewModel.isLoading {
                    LoadingView()
                }
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.background)
        .navigationTitle(L10n.profile)
        .glassNavigationBar()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func profileActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xxs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 44, height: 44)
                    .background(AppColors.tertiaryBackground)
                    .clipShape(Circle())
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func mediaIcon(for type: MediaType) -> String {
        switch type {
        case .photo: return "photo"
        case .video: return "video"
        case .file: return "doc"
        case .link: return "link"
        case .voice: return "waveform"
        }
    }
}

