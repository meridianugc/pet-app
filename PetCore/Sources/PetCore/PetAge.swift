import Foundation

public enum PetAge {
    public static func phrase(from start: Date, to end: Date) -> String {
        let seconds = max(0, end.timeIntervalSince(start))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "just a moment" }
        if minutes < 60 { return count(minutes, unit: "minute") }
        let hours = minutes / 60
        if hours < 48 { return count(hours, unit: "hour") }
        return count(hours / 24, unit: "day")
    }

    public static func remaining(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds < 60 { return "less than a minute" }
        let minutes = seconds / 60
        if minutes < 60 { return count(minutes, unit: "minute") }
        let hours = minutes / 60
        let leftover = minutes % 60
        if hours < 48 {
            if leftover == 0 { return count(hours, unit: "hour") }
            return "\(count(hours, unit: "hour")) \(count(leftover, unit: "minute"))"
        }
        return count(hours / 24, unit: "day")
    }

    private static func count(_ value: Int, unit: String) -> String {
        value == 1 ? "1 \(unit)" : "\(value) \(unit)s"
    }
}
