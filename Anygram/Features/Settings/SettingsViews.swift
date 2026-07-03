import SwiftUI

struct SettingsRootView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var container: DIContainer
    private let diContainer: DIContainer

    init(container: DIContainer) {
        self.diContainer = container
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            settingsRepository: container.settingsRepository,
            proxyRepository: container.proxyRepository
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    NavigationLink {
                        EditProfileSettingsView()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            AvatarView(name: L10n.yourName, colorHex: "#3390EC", size: 60)
                            VStack(alignment: .leading) {
                                Text(L10n.yourName)
                                    .font(AppTypography.headline)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("@your_username")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        .padding(AppSpacing.md)
                    }
                    .glassCard()
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.md)

                    settingsSection(title: nil, rows: [
                        SettingsNavRow(icon: "bookmark.fill", title: L10n.savedMessages, color: AppColors.accent) {
                            SavedMessagesView(container: diContainer)
                        },
                        SettingsNavRow(icon: "iphone", title: L10n.devices, color: AppColors.accent) {
                            DevicesSettingsView(container: diContainer)
                        }
                    ])

                    settingsSection(title: L10n.settingsSection, rows: [
                        SettingsNavRow(icon: "lock.fill", title: L10n.privacySecurity, color: AppColors.online) {
                            PrivacySettingsView()
                        },
                        SettingsNavRow(icon: "bell.fill", title: L10n.notifications, color: AppColors.destructive) {
                            NotificationsSettingsView(container: diContainer)
                        },
                        SettingsNavRow(icon: "arrow.up.arrow.down", title: L10n.dataStorage, color: AppColors.accent) {
                            DataStorageSettingsView(container: diContainer)
                        },
                        SettingsNavRow(icon: "paintbrush.fill", title: L10n.appearance, color: AppColors.premium) {
                            AppearanceSettingsView(container: diContainer)
                        },
                        SettingsNavRow(icon: "globe", title: L10n.language, color: AppColors.accentSecondary) {
                            LanguageSettingsView(container: diContainer)
                        },
                        SettingsNavRow(icon: "folder.fill", title: L10n.chatFoldersSettings, color: AppColors.accent) {
                            FoldersSettingsView(container: diContainer)
                        }
                    ])

                    settingsSection(title: nil, rows: [
                        SettingsNavRow(icon: "star.fill", title: L10n.premium, color: AppColors.premium) {
                            PremiumSettingsView()
                        },
                        SettingsNavRow(icon: "externaldrive.fill", title: L10n.storageUsage, color: AppColors.accent) {
                            StorageUsageSettingsView()
                        },
                        SettingsNavRow(icon: "network", title: L10n.proxySettings, color: AppColors.online) {
                            ProxySettingsView(container: diContainer)
                        },
                        SettingsNavRow(icon: "wallet.pass.fill", title: L10n.wallet, color: AppColors.accentSecondary) {
                            WalletSettingsView()
                        }
                    ])

                    settingsSection(title: nil, rows: [
                        SettingsNavRow(icon: "info.circle.fill", title: L10n.about, color: AppColors.textSecondary) {
                            AboutSettingsView()
                        }
                    ])

                    Button(role: .destructive) {
                        Task { await container.logout() }
                    } label: {
                        Text(L10n.authLogout)
                            .font(AppTypography.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                    }
                    .glassCard()
                    .padding(.horizontal, AppSpacing.md)
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.background)
            .navigationTitle(L10n.settingsTitle)
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func settingsSection(title: String?, rows: [SettingsNavRow]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            if let title {
                Text(title)
                    .font(AppTypography.captionBold)
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, AppSpacing.lg)
            }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    NavigationLink {
                        row.destination
                    } label: {
                        SettingsRowView(icon: row.icon, title: row.title, iconColor: row.color)
                    }
                    .buttonStyle(.plain)
                    if index < rows.count - 1 {
                        Divider().background(AppColors.separator).padding(.leading, 56)
                    }
                }
            }
            .glassCard()
            .padding(.horizontal, AppSpacing.md)
        }
    }
}

private struct SettingsNavRow {
    let icon: String
    let title: String
    let color: Color
    let destination: AnyView

    init<Destination: View>(icon: String, title: String, color: Color, @ViewBuilder destination: () -> Destination) {
        self.icon = icon
        self.title = title
        self.color = color
        self.destination = AnyView(destination())
    }
}

struct EditProfileSettingsView: View {
    @State private var name = L10n.yourName
    @State private var username = "your_username"
    @State private var bio = ""

    var body: some View {
        Form {
            Section(L10n.profile) {
                TextField(L10n.name, text: $name)
                TextField(L10n.username, text: $username)
                TextField(L10n.bio, text: $bio, axis: .vertical)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.editProfile)
        .glassNavigationBar()
    }
}

struct SavedMessagesView: View {
    init(container: DIContainer) {}

    var body: some View {
        ContentUnavailableView(L10n.savedMessages, systemImage: "bookmark.fill", description: Text(L10n.savedMessagesEmpty))
            .background(AppColors.background)
            .navigationTitle(L10n.savedMessages)
    }
}

struct DevicesSettingsView: View {
    @State private var devices: [Device] = []

    init(container: DIContainer) {
        _devices = State(initialValue: [])
    }

    var body: some View {
        List {
            ForEach(devices) { device in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.name)
                            .font(AppTypography.headline)
                        if device.isCurrent {
                            Text(L10n.thisDevice)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                    Text(device.platform)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(device.location)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .listRowBackground(AppColors.secondaryBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.devices)
        .task {
            devices = (try? await DIContainer.shared.settingsRepository.fetchDevices()) ?? []
        }
    }
}

struct PrivacySettingsView: View {
    @State private var phoneVisible = true
    @State private var lastSeenVisible = true
    @State private var groupsVisible = true

    var body: some View {
        Form {
            Section(L10n.privacy) {
                Toggle(L10n.phoneNumber, isOn: $phoneVisible)
                Toggle(L10n.lastSeen, isOn: $lastSeenVisible)
                Toggle(L10n.groups, isOn: $groupsVisible)
            }
            Section(L10n.security) {
                NavigationLink(L10n.twoStepVerification) { Text(L10n.twoStepVerification).navigationTitle("2FA") }
                NavigationLink(L10n.passcodeLock) { Text(L10n.passcodeLock).navigationTitle(L10n.passcodeLock) }
                NavigationLink(L10n.blockedUsers) { Text(L10n.blockedUsers).navigationTitle(L10n.blockedUsers) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.privacySecurity)
    }
}

struct NotificationsSettingsView: View {
    @State private var settings = AppSettings()

    init(container: DIContainer) {}

    var body: some View {
        Form {
            Section(L10n.messagesSection) {
                Toggle(L10n.messagePreview, isOn: $settings.notifications.messagePreview)
                Toggle(L10n.sound, isOn: $settings.notifications.soundEnabled)
                Toggle(L10n.badge, isOn: $settings.notifications.badgeEnabled)
            }
            Section(L10n.groupsChannels) {
                Toggle(L10n.groupNotifications, isOn: $settings.notifications.groupNotifications)
                Toggle(L10n.channelNotifications, isOn: $settings.notifications.channelNotifications)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.notifications)
        .task {
            settings = (try? await DIContainer.shared.settingsRepository.fetchSettings()) ?? AppSettings()
        }
    }
}

struct DataStorageSettingsView: View {
    @State private var autoDownload = true

    init(container: DIContainer) {}

    var body: some View {
        Form {
            Section(L10n.autoDownload) {
                Toggle(L10n.autoDownloadMedia, isOn: $autoDownload)
            }
            Section(L10n.storage) {
                NavigationLink(L10n.clearCache) { Text(L10n.clearCache).navigationTitle(L10n.clearCache) }
                NavigationLink(L10n.networkUsage) { Text(L10n.networkUsage).navigationTitle(L10n.networkUsage) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.dataStorage)
    }
}

struct AppearanceSettingsView: View {
    @State private var appearance = Appearance()

    init(container: DIContainer) {}

    var body: some View {
        Form {
            Section(L10n.theme) {
                Picker(L10n.theme, selection: $appearance.theme) {
                    Text(L10n.themeSystem).tag(Appearance.Theme.system)
                    Text(L10n.themeLight).tag(Appearance.Theme.light)
                    Text(L10n.themeDark).tag(Appearance.Theme.dark)
                }
                Toggle(L10n.largeEmoji, isOn: $appearance.useLargeEmoji)
                Toggle(L10n.animateStickers, isOn: $appearance.animateStickers)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.appearance)
    }
}

struct LanguageSettingsView: View {
    @State private var language = "Русский"

    init(container: DIContainer) {}

    var body: some View {
        List {
            ForEach(["Русский", "English", "Español", "Français", "Deutsch", "العربية", "中文"], id: \.self) { lang in
                HStack {
                    Text(lang)
                    Spacer()
                    if language == lang {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppColors.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { language = lang }
                .listRowBackground(AppColors.secondaryBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.language)
    }
}

struct FoldersSettingsView: View {
    @State private var folders: [Folder] = []

    init(container: DIContainer) {}

    var body: some View {
        List {
            ForEach(folders) { folder in
                HStack {
                    Image(systemName: folder.icon)
                        .foregroundStyle(AppColors.accent)
                    Text(folder.name)
                    Spacer()
                    Text(L10n.settingsChatsCount(folder.chatIDs.count))
                        .foregroundStyle(AppColors.textSecondary)
                        .font(AppTypography.caption)
                }
                .listRowBackground(AppColors.secondaryBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.chatFoldersSettings)
        .task {
            folders = (try? await DIContainer.shared.settingsRepository.fetchFolders()) ?? []
        }
    }
}

struct PremiumSettingsView: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "star.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.premium)
            Text(L10n.premiumTitle)
                .font(AppTypography.largeTitle)
            Text(L10n.premiumDescription)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: L10n.subscribe) {}
                .padding(.horizontal, AppSpacing.xl)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .navigationTitle(L10n.premium)
    }
}

struct StorageUsageSettingsView: View {
    var body: some View {
        List {
            Section(L10n.storage) {
                HStack { Text(L10n.photos); Spacer(); Text("1.2 GB").foregroundStyle(AppColors.textSecondary) }
                HStack { Text(L10n.videos); Spacer(); Text("3.4 GB").foregroundStyle(AppColors.textSecondary) }
                HStack { Text(L10n.documents); Spacer(); Text("256 MB").foregroundStyle(AppColors.textSecondary) }
                HStack { Text(L10n.other); Spacer(); Text("128 MB").foregroundStyle(AppColors.textSecondary) }
            }
            Section {
                Button(L10n.clearCache) {}
                    .foregroundStyle(AppColors.destructive)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.storageUsage)
    }
}

struct WalletSettingsView: View {
    var body: some View {
        ContentUnavailableView(L10n.wallet, systemImage: "wallet.pass.fill", description: Text(L10n.walletEmpty))
            .background(AppColors.background)
            .navigationTitle(L10n.wallet)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        List {
            Section {
                HStack { Text(L10n.version); Spacer(); Text("1.0.0").foregroundStyle(AppColors.textSecondary) }
                NavigationLink(L10n.termsOfService) { Text(L10n.termsOfService).padding() }
                NavigationLink(L10n.privacyPolicy) { Text(L10n.privacyPolicy).padding() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.about)
    }
}

struct ProxySettingsView: View {
    @StateObject private var viewModel: ProxySettingsViewModel

    init(container: DIContainer) {
        _viewModel = StateObject(wrappedValue: ProxySettingsViewModel(
            proxyRepository: container.proxyRepository,
            settingsRepository: container.settingsRepository
        ))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Circle()
                        .fill(Color(hex: viewModel.connectionStatusColor))
                        .frame(width: 10, height: 10)
                    Text(viewModel.connectionStatusText)
                        .font(AppTypography.headline)
                    Spacer()
                    Button(L10n.reconnect) {
                        Task { await viewModel.reconnect() }
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.accent)
                }
            } header: {
                Text(L10n.connectionStatus)
            }

            Section(L10n.proxies) {
                ForEach(viewModel.proxies) { proxy in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(proxy.label)
                                .font(AppTypography.headline)
                            if proxy.isDefault {
                                Text(L10n.defaultLabel)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.accent)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { proxy.isEnabled },
                                set: { _ in Task { await viewModel.toggleProxy(proxy) } }
                            ))
                            .labelsHidden()
                        }
                        Text("\(proxy.server):\(proxy.port)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .swipeActions {
                        if !proxy.isDefault {
                            Button(role: .destructive) {
                                Task { await viewModel.removeProxy(proxy) }
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    viewModel.showAddProxy = true
                } label: {
                    Label(L10n.addProxy, systemImage: "plus.circle.fill")
                        .foregroundStyle(AppColors.accent)
                }
            }

            Section(L10n.defaultProxy) {
                Text(Proxy.builtInDefault.link)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L10n.proxySettings)
        .sheet(isPresented: $viewModel.showAddProxy) {
            NavigationStack {
                Form {
                    TextField(L10n.server, text: $viewModel.newServer)
                    TextField(L10n.port, text: $viewModel.newPort)
                        .keyboardType(.numberPad)
                    TextField(L10n.secret, text: $viewModel.newSecret)
                }
                .navigationTitle(L10n.addProxy)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.cancel) { viewModel.showAddProxy = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.add) { Task { await viewModel.addProxy() } }
                    }
                }
            }
            .presentationDetents([.medium])
            .glassSheetBackground()
        }
        .task { await viewModel.load() }
    }
}
