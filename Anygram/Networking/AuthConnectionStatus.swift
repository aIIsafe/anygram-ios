import Foundation

enum AuthConnectionPhase: Equatable, Sendable {
    case idle
    case connectingProxy
    case waitingTdlib
    case sendingPhone
}

enum AuthConnectionStatus {
    private static let notificationName = Notification.Name("anygram.auth.connectionPhase")

    static func post(_ phase: AuthConnectionPhase) {
        NotificationCenter.default.post(name: notificationName, object: phase)
    }

    static func publisher() -> NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: notificationName)
    }
}
