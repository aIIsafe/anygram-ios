import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings = AppSettings()
    @Published var devices: [Device] = []
    @Published var folders: [Folder] = []
    @Published var isLoading = false

    private let settingsRepository: SettingsRepository
    private let proxyRepository: ProxyRepository

    init(settingsRepository: SettingsRepository, proxyRepository: ProxyRepository) {
        self.settingsRepository = settingsRepository
        self.proxyRepository = proxyRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        settings = (try? await settingsRepository.fetchSettings()) ?? AppSettings()
        devices = (try? await settingsRepository.fetchDevices()) ?? []
        folders = (try? await settingsRepository.fetchFolders()) ?? []
    }

    func updateSettings() async {
        settings = (try? await settingsRepository.updateSettings(settings)) ?? settings
    }
}

@MainActor
final class ProxySettingsViewModel: ObservableObject {
    @Published var proxies: [Proxy] = []
    @Published var connectionState: ProxyConnectionState = .disconnected
    @Published var showAddProxy = false
    @Published var newServer = ""
    @Published var newPort = "443"
    @Published var newSecret = ""

    private let proxyRepository: ProxyRepository
    private let settingsRepository: SettingsRepository

    init(proxyRepository: ProxyRepository, settingsRepository: SettingsRepository) {
        self.proxyRepository = proxyRepository
        self.settingsRepository = settingsRepository
        connectionState = proxyRepository.connectionState
    }

    func load() async {
        proxies = (try? await proxyRepository.fetchProxies()) ?? []
        connectionState = proxyRepository.connectionState
    }

    func toggleProxy(_ proxy: Proxy) async {
        proxies = (try? await proxyRepository.setEnabled(!proxy.isEnabled, for: proxy.id)) ?? proxies
        var settings = (try? await settingsRepository.fetchSettings()) ?? AppSettings()
        settings.proxyEnabled = proxy.isEnabled == false
        settings.activeProxyID = proxy.isEnabled ? nil : proxy.id
        _ = try? await settingsRepository.updateSettings(settings)
        connectionState = proxyRepository.connectionState
    }

    func addProxy() async {
        guard let port = Int(newPort), !newServer.isEmpty, !newSecret.isEmpty else { return }
        let proxy = Proxy(server: newServer, port: port, secret: newSecret, label: "Custom Proxy")
        proxies = (try? await proxyRepository.addProxy(proxy)) ?? proxies
        newServer = ""
        newPort = "443"
        newSecret = ""
        showAddProxy = false
    }

    func removeProxy(_ proxy: Proxy) async {
        proxies = (try? await proxyRepository.removeProxy(id: proxy.id)) ?? proxies
    }

    func reconnect() async {
        await proxyRepository.reconnect()
        connectionState = proxyRepository.connectionState
    }

    var connectionStatusText: String {
        switch connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        }
    }

    var connectionStatusColor: String {
        switch connectionState {
        case .connected: return "#4CAF50"
        case .connecting: return "#FFD700"
        case .disconnected: return "#E53935"
        }
    }
}
