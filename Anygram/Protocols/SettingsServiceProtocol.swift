import Combine
import Foundation

/// Contract for application settings.
public protocol SettingsServiceProtocol: Sendable {
    func fetchSettings() async throws -> AppSettings
    func updateSettings(_ settings: AppSettings) async throws -> AppSettings
    func fetchDevices() async throws -> [Device]
    func fetchFolders() async throws -> [Folder]
    func observeSettings() -> AnyPublisher<AppSettings, Never>
}
