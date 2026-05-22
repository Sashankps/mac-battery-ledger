import Foundation

enum BatteryFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainder)m"
    }

    static func timeRemaining(minutes: Int?) -> String {
        guard let minutes else { return "Learning" }
        return duration(TimeInterval(minutes * 60))
    }

    static func sessionWindow(_ session: BatterySession) -> String {
        let startDay = day.string(from: session.startDate)
        let startTime = time.string(from: session.startDate)
        let endTime = time.string(from: session.displayEndDate)
        return "\(startDay), \(startTime)-\(endTime)"
    }
}
