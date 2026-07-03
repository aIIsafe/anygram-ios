import Foundation

extension Date {
    /// Formats date for chat list display.
    var chatListFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        if calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) {
            return formatted(.dateTime.weekday(.abbreviated))
        }
        return formatted(date: .numeric, time: .omitted)
    }

    /// Formats date for message separators.
    var messageSeparatorFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        }
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        return formatted(date: .long, time: .omitted)
    }

    /// Formats last seen timestamp.
    var lastSeenFormatted: String {
        if Calendar.current.isDateInToday(self) {
            return "last seen today at \(formatted(date: .omitted, time: .shortened))"
        }
        if Calendar.current.isDateInYesterday(self) {
            return "last seen yesterday at \(formatted(date: .omitted, time: .shortened))"
        }
        return "last seen \(formatted(date: .abbreviated, time: .shortened))"
    }

    /// Formats call duration display.
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return String(format: "0:%02d", seconds)
    }
}
