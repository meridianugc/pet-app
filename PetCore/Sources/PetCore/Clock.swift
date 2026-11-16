import Foundation

/// A source of "now" for the app and the widget.
/// The engine itself takes dates, so tests can pass a `ManualClock` or raw dates.
public protocol Clock {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}

    public var now: Date { Date() }
}

public struct ManualClock: Clock {
    public var now: Date

    public init(now: Date) {
        self.now = now
    }

    public mutating func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
