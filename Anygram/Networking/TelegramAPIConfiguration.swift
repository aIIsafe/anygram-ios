import Foundation

/// Telegram API credentials and TDLib bootstrap configuration.
///
/// Obtain credentials at https://my.telegram.org/apps
/// Defaults match BetterTG `Secret.swift` (api_id 34053256) — verified working with TDLibKit on iOS.
/// Set environment variables `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` to override for local builds.
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
        return 34_053_256
    }

    static var apiHash: String {
        ProcessInfo.processInfo.environment["TELEGRAM_API_HASH"] ?? "bc8984a70877b5768a5a6a80222da985"
    }

    /// Masked api_hash for debug logs: first 4 + last 3 characters.
    static var maskedApiHash: String {
        let hash = apiHash
        guard hash.count > 7 else { return "***" }
        return "\(hash.prefix(4))...\(hash.suffix(3))"
    }

    static var isConfigured: Bool {
        apiId > 0 && !apiHash.isEmpty
    }

    static let applicationVersion = "1.0.0"
    static let systemLanguageCode = "ru"
    static let deviceModel = "iPhone"
    /// BetterTG stores TDLib data under Documents/td.
    static var databaseDirectoryPath: String {
        tdStorageRoot.path
    }

    static var filesDirectoryPath: String {
        tdStorageRoot.path
    }

    private static var tdStorageRoot: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let root = base.appendingPathComponent("td", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
