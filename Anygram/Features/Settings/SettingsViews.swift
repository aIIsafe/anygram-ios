import SwiftUI

struct SettingsRootView: View {
    @StateObject private var viewModel: SettingsViewModel
    private let container: DIContainer

    init(container: DIContainer) {
        self.container = container
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
                            AvatarView(name: "You", colorHex: "#3390EC", size: 60)
                            VStack(alignment: .leading) {
                                Text("Your Name")
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
                        .background(AppColors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.md)

                    settingsSection(title: nil, rows: [
                        SettingsNavRow(icon: "bookmark.fill", title: "Saved Messages", color: AppColors.accent) {
                            SavedMessagesView(container: container)
                        },
                        SettingsNavRow(icon: "iphone", title: "Devices", color: AppColors.accent) {
                            DevicesSettingsView(container: container)
                        }
                    ])

                    settingsSection(title: "Settings", rows: [
                        SettingsNavRow(icon: "lock.fill", title: "Privacy and Security", color: AppColors.online) {
                            PrivacySettingsView()
                        },
                        SettingsNavRow(icon: "bell.fill", title: "Notifications", color: AppColors.destructive) {
                            NotificationsSettingsView(container: container)
                        },
                        SettingsNavRow(icon: "arrow.up.arrow.down", title: "Data and Storage", color: AppColors.accent) {
                            DataStorageSettingsView(container: container)
                        },
                        SettingsNavRow(icon: "paintbrush.fill", title: "Appearance", color: AppColors.premium) {
                            AppearanceSettingsView(container: container)
                        },
                        SettingsNavRow(icon: "globe", title: "Language", color: AppColors.accentSecondary) {
                            LanguageSettingsView(container: container)
                        },
                        SettingsNavRow(icon: "folder.fill", title: "Chat Folders", color: AppColors.accent) {
                            FoldersSettingsView(container: container)
                        }
                    ])

                    settingsSection(title: nil, rows: [
                        SettingsNavRow(icon: "star.fill", title: "Telegram Premium", color: AppColors.premium) {
                            PremiumSettingsView()
                        },
                        SettingsNavRow(icon: "externaldrive.fill", title: "Storage Usage", color: AppColors.accent) {
                            StorageUsageSettingsView()
                        },
                        SettingsNavRow(icon: "network", title: "Proxy Settings", color: AppColors.online) {
                            ProxySettingsView(container: container)
                        },
                        SettingsNavRow(icon: "wallet.pass.fill", title: "Wallet", color: AppColors.accentSecondary) {
                            WalletSettingsView()
                        }
                    ])

                    settingsSection(title: nil, rows: [
                        SettingsNavRow(icon: "info.circle.fill", title: "About Anygram", color: AppColors.textSecondary) {
                            AboutSettingsView()
                        }
                    ])
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
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
    @State private var name = "Your Name"
    @State private var username = "your_username"
    @State private var bio = ""

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $name)
                TextField("Username", text: $username)
                TextField("Bio", text: $bio, axis: .vertical)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Edit Profile")
    }
}

struct SavedMessagesView: View {
    init(container: DIContainer) {}

    var body: some View {
        ContentUnavailableView("Saved Messages", systemImage: "bookmark.fill", description: Text("Messages you save will appear here"))
            .background(AppColors.background)
            .navigationTitle("Saved Messages")
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
                            Text("This device")
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
        .navigationTitle("Devices")
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
            Section("Privacy") {
                Toggle("Phone Number", isOn: $phoneVisible)
                Toggle("Last Seen", isOn: $lastSeenVisible)
                Toggle("Groups", isOn: $groupsVisible)
            }
            Section("Security") {
                NavigationLink("Two-Step Verification") { Text("Two-Step Verification").navigationTitle("2FA") }
                NavigationLink("Passcode Lock") { Text("Passcode Lock").navigationTitle("Passcode") }
                NavigationLink("Blocked Users") { Text("Blocked Users").navigationTitle("Blocked") }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Privacy and Security")
    }
}

struct NotificationsSettingsView: View {
    @State private var settings = AppSettings()

    init(container: DIContainer) {}

    var body: some View {
        Form {
            Section("Messages") {
                Toggle("Message Preview", isOn: $settings.notifications.messagePreview)
                Toggle("Sound", isOn: $settings.notifications.soundEnabled)
                Toggle("Badge", isOn: $settings.notifications.badgeEnabled)
            }
            Section("Groups & Channels") {
                Toggle("Group Notifications", isOn: $settings.notifications.groupNotifications)
                Toggle("Channel Notifications", isOn: $settings.notifications.channelNotifications)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Notifications")
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
            Section("Auto-Download") {
                Toggle("Auto-Download Media", isOn: $autoDownload)
            }
            Section("Storage") {
                NavigationLink("Clear Cache") { Text("Cache cleared").navigationTitle("Clear Cache") }
                NavigationLink("Network Usage") { Text("Network stats").navigationTitle("Network Usage") }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Data and Storage")
    }
}

struct AppearanceSettingsView: View {
    @State private var appearance = Appearance()

    init(container: DIContainer) {}

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $appearance.theme) {
                    Text("System").tag(Appearance.Theme.system)
                    Text("Light").tag(Appearance.Theme.light)
                    Text("Dark").tag(Appearance.Theme.dark)
                }
                Toggle("Large Emoji", isOn: $appearance.useLargeEmoji)
                Toggle("Animate Stickers", isOn: $appearance.animateStickers)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Appearance")
    }
}

struct LanguageSettingsView: View {
    @State private var language = "English"

    init(container: DIContainer) {}

    var body: some View {
        List {
            ForEach(["English", "Russian", "Spanish", "French", "German", "Arabic", "Chinese"], id: \.self) { lang in
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
        .navigationTitle("Language")
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
                    Text("\(folder.chatIDs.count) chats")
                        .foregroundStyle(AppColors.textSecondary)
                        .font(AppTypography.caption)
                }
                .listRowBackground(AppColors.secondaryBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Chat Folders")
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
            Text("Anygram Premium")
                .font(AppTypography.largeTitle)
            Text("Exclusive features, faster downloads, and more.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Subscribe") {}
                .padding(.horizontal, AppSpacing.xl)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .navigationTitle("Premium")
    }
}

struct StorageUsageSettingsView: View {
    var body: some View {
        List {
            Section("Storage") {
                HStack { Text("Photos"); Spacer(); Text("1.2 GB").foregroundStyle(AppColors.textSecondary) }
                HStack { Text("Videos"); Spacer(); Text("3.4 GB").foregroundStyle(AppColors.textSecondary) }
                HStack { Text("Documents"); Spacer(); Text("256 MB").foregroundStyle(AppColors.textSecondary) }
                HStack { Text("Other"); Spacer(); Text("128 MB").foregroundStyle(AppColors.textSecondary) }
            }
            Section {
                Button("Clear Cache") {}
                    .foregroundStyle(AppColors.destructive)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Storage Usage")
    }
}

struct WalletSettingsView: View {
    var body: some View {
        ContentUnavailableView("Wallet", systemImage: "wallet.pass.fill", description: Text("Crypto wallet integration coming soon"))
            .background(AppColors.background)
            .navigationTitle("Wallet")
    }
}

struct AboutSettingsView: View {
    var body: some View {
        List {
            Section {
                HStack { Text("Version"); Spacer(); Text("1.0.0").foregroundStyle(AppColors.textSecondary) }
                NavigationLink("Terms of Service") { Text("Terms of Service").padding() }
                NavigationLink("Privacy Policy") { Text("Privacy Policy").padding() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("About Anygram")
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
                    Button("Reconnect") {
                        Task { await viewModel.reconnect() }
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.accent)
                }
            } header: {
                Text("Connection Status")
            }

            Section("Proxies") {
                ForEach(viewModel.proxies) { proxy in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(proxy.label)
                                .font(AppTypography.headline)
                            if proxy.isDefault {
                                Text("Default")
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
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    viewModel.showAddProxy = true
                } label: {
                    Label("Add Proxy", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppColors.accent)
                }
            }

            Section("Default Proxy") {
                Text(Proxy.builtInDefault.link)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Proxy Settings")
        .sheet(isPresented: $viewModel.showAddProxy) {
            NavigationStack {
                Form {
                    TextField("Server", text: $viewModel.newServer)
                    TextField("Port", text: $viewModel.newPort)
                        .keyboardType(.numberPad)
                    TextField("Secret", text: $viewModel.newSecret)
                }
                .navigationTitle("Add Proxy")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { viewModel.showAddProxy = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { Task { await viewModel.addProxy() } }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task { await viewModel.load() }
    }
}
