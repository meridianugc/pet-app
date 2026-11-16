import Foundation

public enum PowerUpKind: String, Codable, CaseIterable, Equatable, Sendable {
    case hammer
    case shuffle
    case colorBomb
    case extraMoves
    case blast
    case jet

    public var price: Int {
        switch self {
        case .hammer: return 8
        case .shuffle: return 6
        case .colorBomb: return 14
        case .extraMoves: return 10
        case .blast: return 12
        case .jet: return 12
        }
    }
}

public struct PowerCharge: Codable, Equatable, Sendable {
    public var count: Int
    public var updatedAt: Date

    public init(count: Int, updatedAt: Date) {
        self.count = count
        self.updatedAt = updatedAt
    }
}

public struct PowerPouch: Codable, Equatable, Sendable {
    public static let cap = 3
    public static let refillInterval: TimeInterval = 15 * 60

    public var slots: [String: PowerCharge]

    public init(slots: [String: PowerCharge] = [:]) {
        self.slots = slots
    }

    public static func stocked(at now: Date) -> PowerPouch {
        var pouch = PowerPouch()
        for kind in PowerUpKind.allCases {
            pouch.slots[kind.rawValue] = PowerCharge(count: cap, updatedAt: now)
        }
        return pouch
    }

    public func count(_ kind: PowerUpKind, now: Date) -> Int {
        refreshed(now: now).slots[kind.rawValue]?.count ?? 0
    }

    public func refreshed(now: Date) -> PowerPouch {
        var copy = self
        for kind in PowerUpKind.allCases {
            var slot = copy.slots[kind.rawValue] ?? PowerCharge(count: Self.cap, updatedAt: now)
            if slot.count >= Self.cap {
                slot.count = Self.cap
                slot.updatedAt = now
            } else {
                let gained = Int(now.timeIntervalSince(slot.updatedAt) / Self.refillInterval)
                if gained > 0 {
                    let add = min(Self.cap - slot.count, gained)
                    slot.count += add
                    slot.updatedAt = slot.updatedAt.addingTimeInterval(Self.refillInterval * Double(add))
                    if slot.count >= Self.cap {
                        slot.updatedAt = now
                    }
                }
            }
            copy.slots[kind.rawValue] = slot
        }
        return copy
    }

    public func spending(_ kind: PowerUpKind, now: Date) -> PowerPouch? {
        var copy = refreshed(now: now)
        guard var slot = copy.slots[kind.rawValue], slot.count > 0 else { return nil }
        slot.count -= 1
        slot.updatedAt = slot.count == 0 ? now : slot.updatedAt
        if slot.count == Self.cap - 1, copy.slots[kind.rawValue]?.count == Self.cap {
            slot.updatedAt = now
        }
        copy.slots[kind.rawValue] = slot
        return copy
    }

    public func buying(_ kind: PowerUpKind, coins: Int, now: Date) -> (PowerPouch, Int)? {
        var copy = refreshed(now: now)
        guard var slot = copy.slots[kind.rawValue], slot.count < Self.cap else { return nil }
        guard coins >= kind.price else { return nil }
        slot.count += 1
        copy.slots[kind.rawValue] = slot
        return (copy, coins - kind.price)
    }
}
