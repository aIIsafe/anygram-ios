import Foundation

/// Application settings aggregate.
public struct AppSettings: Codable, Hashable, Sendable {
    public var notifications: NotificationSettings
    public var appearance: Appearance
    public var languageCode: String
    public var savedMessagesEnabled: Bool
    public var dataUsageAutoDownload: Bool
    public var proxyEnabled: Bool
    public var activeProxyID: UUID?

    public init(
        notifications: NotificationSettings = NotificationSettings(),
        appearance: Appearance = Appearance(),
        languageCode: String = "en",
        savedMessagesEnabled: Bool = true,
        dataUsageAutoDownload: Bool = true,
        proxyEnabled: Bool = true,
        activeProxyID: UUID? = nil
    ) {
        self.notifications = notifications
        self.appearance = appearance
        self.languageCode = languageCode
        self.savedMessagesEnabled = savedMessagesEnabled
        self.dataUsageAutoDownload = dataUsageAutoDownload
        self.proxyEnabled = proxyEnabled
        self.activeProxyID = activeProxyID
    }
}

/// Notification preference settings.
public struct NotificationSettings: Codable, Hashable, Sendable {
    public var messagePreview: Bool
    public var soundEnabled: Bool
    public var badgeEnabled: Bool
    public var groupNotifications: Bool
    public var channelNotifications: Bool

    public init(
        messagePreview: Bool = true,
        soundEnabled: Bool = true,
        badgeEnabled: Bool = true,
        groupNotifications: Bool = true,
        channelNotifications: Bool = true
    ) {
        self.messagePreview = messagePreview
        self.soundEnabled = soundEnabled
        self.badgeEnabled = badgeEnabled
        self.groupNotifications = groupNotifications
        self.channelNotifications = channelNotifications
    }
}

/// Visual appearance settings.
public struct Appearance: Codable, Hashable, Sendable {
    public enum Theme: String, Codable, Hashable, Sendable {
        case system
        case light
        case dark
    }

    public var theme: Theme
    public var accentColorHex: String
    public var useLargeEmoji: Bool
    public var animateStickers: Bool

    public init(
        theme: Theme = .dark,
        accentColorHex: String = "#3390EC",
        useLargeEmoji: Bool = true,
        animateStickers: Bool = true
    ) {
        self.theme = theme
        self.accentColorHex = accentColorHex
        self.useLargeEmoji = useLargeEmoji
        self.animateStickers = animateStickers
    }
}
