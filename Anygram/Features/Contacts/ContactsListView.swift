import SwiftUI

struct ContactsListView: View {
    @StateObject private var viewModel: ContactsViewModel

    init(container: DIContainer) {
        _viewModel = StateObject(wrappedValue: ContactsViewModel(repository: container.userRepository))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.contacts.isEmpty {
                    LoadingView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            SearchBarView(text: $viewModel.searchText, placeholder: L10n.searchContacts)

                            Button {} label: {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundStyle(.white)
                                        .frame(width: 48, height: 48)
                                        .background(AppColors.accent)
                                        .clipShape(Circle())
                                    Text(L10n.inviteFriends)
                                        .font(AppTypography.headline)
                                        .foregroundStyle(AppColors.accent)
                                    Spacer()
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                            }

                            if !viewModel.pinnedContacts.isEmpty {
                                Section {
                                    ForEach(viewModel.pinnedContacts) { user in
                                        contactRow(user)
                                    }
                                } header: {
                                    sectionHeader(L10n.pinned)
                                }
                            }

                            ForEach(viewModel.groupedContacts, id: \.0) { letter, users in
                                Section {
                                    ForEach(users) { user in
                                        contactRow(user)
                                    }
                                } header: {
                                    sectionHeader(letter)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.contactsTitle)
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func contactRow(_ user: User) -> some View {
        NavigationLink {
            ProfileView(userID: user.id, container: DIContainer.shared)
        } label: {
            ContactRowView(user: user)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button { Task { await viewModel.togglePin(user) } } label: {
                Label(user.isPinned ? L10n.unpin : L10n.pin, systemImage: "pin")
            }
            .tint(AppColors.accent)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { Task { await viewModel.deleteContact(user) } } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
        .contextMenu {
            Button { Task { await viewModel.togglePin(user) } } label: {
                Label(user.isPinned ? L10n.unpin : L10n.pin, systemImage: "pin")
            }
            Button(role: .destructive) { Task { await viewModel.deleteContact(user) } } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.captionBold)
            .foregroundStyle(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xxs)
            .background(AppColors.secondaryBackground)
    }
}
