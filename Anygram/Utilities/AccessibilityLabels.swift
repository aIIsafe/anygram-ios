import Foundation

/// Centralized VoiceOver label builders.
enum AccessibilityLabels {
    static func contact(_ user: User) -> String {
        var parts = [user.name]
        if user.isOnline {
            parts.append("online")
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
        if chat.isMuted { parts.append("muted") }
        if chat.isPinned { parts.append("pinned") }
        return parts.joined(separator: ", ")
    }

    static func message(_ message: Message) -> String {
        let direction = message.isOutgoing ? "You" : "Contact"
        var text = "\(direction): \(message.text)"
        if message.isEdited { text += ", edited" }
        if message.isForwarded { text += ", forwarded" }
        return text
    }

    static func call(_ call: Call) -> String {
        "\(call.direction.rawValue) \(call.mediaType.rawValue) call with \(call.userName), \(Date.formatDuration(call.duration))"
    }
}
