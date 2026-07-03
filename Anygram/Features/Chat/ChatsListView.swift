import SwiftUI

struct ChatsListView: View {
    @StateObject private var viewModel: ChatsViewModel
    @Namespace private var animation
    @State private var selectedChat: Chat?

    init(container: DIContainer) {
        _viewModel = StateObject(wrappedValue: ChatsViewModel(
            repository: container.chatRepository,
            isAuthenticated: { container.isAuthenticated }
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.chats.isEmpty {
                    LoadingView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            SearchBarView(text: $viewModel.searchText)

                            if !viewModel.archivedChats.isEmpty && !viewModel.showArchived {
                                Button {
                                    withAnimation(AppAnimation.standard) {
                                        viewModel.showArchived = true
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "archivebox.fill")
                                            .foregroundStyle(AppColors.accent)
                                        Text(L10n.archivedChats)
                                            .foregroundStyle(AppColors.textPrimary)
                                        Spacer()
                                        Text("\(viewModel.archivedChats.count)")
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                }
                            }

                            Section {
                                ForEach(viewModel.pinnedChats) { chat in
                                    chatRow(chat)
                                }
                            } header: {
                                if !viewModel.pinnedChats.isEmpty {
                                    sectionHeader(L10n.pinned)
                                }
                            }

                            Section {
                                ForEach(viewModel.regularChats) { chat in
                                    chatRow(chat)
                                }
                            } header: {
                                HStack {
                                    Text(L10n.allChats)
                                    Spacer()
                                    Button {
                                        withAnimation(AppAnimation.standard) {}
                                    } label: {
                                        Image(systemName: "folder")
                                            .foregroundStyle(AppColors.accent)
                                    }
                                    .accessibilityLabel(L10n.chatFolders)
                                }
                                .font(AppTypography.captionBold)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.xs)
                                .background(AppColors.background)
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.showArchived ? L10n.archivedTitle : L10n.chatsTitle)
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.showArchived {
                        Button(L10n.back) {
                            viewModel.showArchived = false
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(AppColors.accent)
                    }
                    .accessibilityLabel(L10n.newMessage)
                }
            }
            .navigationDestination(item: $selectedChat) { chat in
                ChatDetailView(chat: chat, container: DIContainer.shared)
            }
            .task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func chatRow(_ chat: Chat) -> some View {
        Button {
            selectedChat = chat
        } label: {
            ChatRowView(chat: chat)
                .matchedGeometryEffect(id: chat.id, in: animation)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                Task { await viewModel.togglePin(chat) }
            } label: {
                Label(chat.isPinned ? L10n.unpin : L10n.pin, systemImage: "pin")
            }
            .tint(AppColors.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await viewModel.deleteChat(chat) }
            } label: {
                Label(L10n.delete, systemImage: "trash")
            }
            Button {
                Task { await viewModel.archive(chat) }
            } label: {
                Label(L10n.archive, systemImage: "archivebox")
            }
            .tint(AppColors.tertiaryBackground)
            Button {
                Task { await viewModel.toggleMute(chat) }
            } label: {
                Label(chat.isMuted ? L10n.unmute : L10n.mute, systemImage: chat.isMuted ? "speaker" : "speaker.slash")
            }
            .tint(AppColors.muted)
        }
        .contextMenu {
            Button { Task { await viewModel.togglePin(chat) } } label: {
                Label(chat.isPinned ? L10n.unpin : L10n.pin, systemImage: "pin")
            }
            Button { Task { await viewModel.toggleMute(chat) } } label: {
                Label(chat.isMuted ? L10n.unmute : L10n.mute, systemImage: "speaker.slash")
            }
            Button { Task { await viewModel.archive(chat) } } label: {
                Label(L10n.archive, systemImage: "archivebox")
            }
            Button(role: .destructive) { Task { await viewModel.deleteChat(chat) } } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.captionBold)
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.background)
    }
}
