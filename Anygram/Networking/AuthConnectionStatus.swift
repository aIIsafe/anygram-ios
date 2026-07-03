import Foundation

enum AuthConnectionPhase: Equatable, Sendable {
    case idle
    case connectingProxy
    case waitingTdlib
    case sendingPhone
}

struct AuthFlowProgress: Equatable, Sendable {
    let step: Int
    let total: Int
    let label: String

    var displayText: String {
        "Шаг \(step)/\(total): \(label)"
    }
}

enum AuthConnectionStatus {
    private static let notificationName = Notification.Name("anygram.auth.connectionPhase")
    private static let progressName = Notification.Name("anygram.auth.flowProgress")

    static func post(_ phase: AuthConnectionPhase) {
        NotificationCenter.default.post(name: notificationName, object: phase)
    }

    static func postProgress(step: Int, total: Int, label: String) {
        let progress = AuthFlowProgress(step: step, total: total, label: label)
        NotificationCenter.default.post(name: progressName, object: progress)
    }

    static func publisher() -> NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: notificationName)
    }

    static func progressPublisher() -> NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: progressName)
    }
}
