import Foundation

/// Telegram API credentials and TDLib bootstrap configuration.
///
/// Obtain credentials at https://my.telegram.org/apps
/// Set environment variables `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` for local builds,
/// or replace the defaults below before release.
///
/// TDLib SPM setup (optional, ~300 MB download):
/// 1. Xcode → Project → Package Dependencies → Add `https://github.com/Swiftgram/TDLibKit`
/// 2. Link `TDLibKit` to the Anygram target
/// 3. Add linker flags: `-lc++`, `-lz` (Build Settings → Other Linker Flags)
/// 4. Build — `TDLibAuthService` automatically uses the real client via `#if canImport(TDLibKit)`
enum TelegramAPIConfiguration {
    static var apiId: Int32 {
        if let env = ProcessInfo.processInfo.environment["TELEGRAM_API_ID"],
           let value = Int32(env), value > 0 {
            return value
        }
        return 24053256
    }

    static var apiHash: String {
        ProcessInfo.processInfo.environment["TELEGRAM_API_HASH"] ?? "bc8984a70877b5768a5a6a80222da985"
    }

    static var isConfigured: Bool {
        apiId > 0 && !apiHash.isEmpty
    }

    static let applicationVersion = "1.0.0"
    static let systemLanguageCode = "ru"
    static let deviceModel = "iPhone"
    static let databaseDirectory = "tdlib"
    static let filesDirectory = "tdlib_files"

    static var databaseDirectoryPath: String {
        storageRoot.appendingPathComponent(databaseDirectory, isDirectory: true).path
    }

    static var filesDirectoryPath: String {
        storageRoot.appendingPathComponent(filesDirectory, isDirectory: true).path
    }

    private static var storageRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Anygram", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}
