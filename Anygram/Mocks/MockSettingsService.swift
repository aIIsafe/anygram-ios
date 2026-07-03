import Combine
import Foundation

/// In-memory mock implementation of app settings.
public final class MockSettingsService: SettingsServiceProtocol, @unchecked Sendable {
    private var settings: AppSettings
    private let settingsSubject = CurrentValueSubject<AppSettings, Never>([])
    private let devices: [Device]
    private let folders: [Folder]
    private let lock = NSLock()

    public init() {
        let users = MockDataGenerator.generateUsers()
        let chats = MockDataGenerator.generateChats(users: users)
        self.settings = PreferencesStorage.shared.loadSettings() ?? AppSettings()
        self.devices = MockDataGenerator.generateDevices()
        self.folders = MockDataGenerator.generateFolders(chats: chats)
        self.settingsSubject = CurrentValueSubject(settings)
    }

    public func fetchSettings() async throws -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    public func updateSettings(_ settings: AppSettings) async throws -> AppSettings {
        lock.lock()
        self.settings = settings
        try? PreferencesStorage.shared.saveSettings(settings)
        let updated = settings
        lock.unlock()
        settingsSubject.send(updated)
        return updated
    }

    public func fetchDevices() async throws -> [Device] {
        devices
    }

    public func fetchFolders() async throws -> [Folder] {
        folders
    }

    public func observeSettings() -> AnyPublisher<AppSettings, Never> {
        settingsSubject.eraseToAnyPublisher()
    }
}
