import Combine
import Foundation

/// Repository mediating settings between ViewModels and services.
@MainActor
public final class SettingsRepository: ObservableObject {
    private let settingsService: SettingsServiceProtocol

    public init(settingsService: SettingsServiceProtocol) {
        self.settingsService = settingsService
    }

    public func fetchSettings() async throws -> AppSettings {
        try await settingsService.fetchSettings()
    }

    public func updateSettings(_ settings: AppSettings) async throws -> AppSettings {
        try await settingsService.updateSettings(settings)
    }

    public func fetchDevices() async throws -> [Device] {
        try await settingsService.fetchDevices()
    }

    public func fetchFolders() async throws -> [Folder] {
        try await settingsService.fetchFolders()
    }
}
