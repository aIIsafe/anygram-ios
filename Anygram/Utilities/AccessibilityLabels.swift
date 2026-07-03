import Foundation

/// Centralized VoiceOver label builders.
enum AccessibilityLabels {
    static func contact(_ user: User) -> String {
        var parts = [user.name]
        if user.isOnline {
            parts.append(L10n.online)
        } else if let lastSeen = user.lastSeen {
            parts.append(lastSeen.lastSeenFormatted)
        }
        if user.isPremium { parts.append("premium") }
        if user.isVerified { parts.append("verified") }
        return parts.joined(separator: ", ")
    }

    static func chat(_ chat: Chat) -> String {
        var parts = [chat.title, chat.lastMessage]
        if chat.unreadCount > 0 {
            parts.append("\(chat.unreadCount) unread")
        }
        if chat.isMuted { parts.append(L10n.mute) }
        if chat.isPinned { parts.append(L10n.pin) }
        return parts.joined(separator: ", ")
    }

    static func message(_ message: Message) -> String {
        let direction = message.isOutgoing ? "You" : "Contact"
        var text = "\(direction): \(message.text)"
        if message.isEdited { text += ", \(L10n.edited)" }
        if message.isForwarded { text += ", \(L10n.forward)" }
        return text
    }

    static func call(_ call: Call) -> String {
        "\(call.direction.rawValue) \(call.mediaType.rawValue) call with \(call.userName), \(Date.formatDuration(call.duration))"
    }
}
