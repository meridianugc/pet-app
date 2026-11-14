import Foundation

public struct StarSeed: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var plantedAt: Date

    public init(id: UUID = UUID(), plantedAt: Date) {
        self.id = id
        self.plantedAt = plantedAt
    }

    /// 0 seed, 1 sprout, 2 bud, 3 ready to pick.
    public func stage(at now: Date) -> Int {
        let hours = now.timeIntervalSince(plantedAt) / 3600
        if hours >= 6 { return 3 }
        if hours >= 3 { return 2 }
        if hours >= 1 { return 1 }
        return 0
    }
}

public struct SpaceTrip: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var hours: Int

    public init(startedAt: Date, hours: Int) {
        self.startedAt = startedAt
        self.hours = hours
    }

    public var returnsAt: Date {
        startedAt.addingTimeInterval(Double(hours) * 3600)
    }

    public func isBack(at now: Date) -> Bool {
        now >= returnsAt
    }
}

public struct Postcard: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var message: String
    public var at: Date
    public var souvenir: String

    public init(id: UUID = UUID(), title: String, message: String, at: Date, souvenir: String) {
        self.id = id
        self.title = title
        self.message = message
        self.at = at
        self.souvenir = souvenir
    }
}

public struct AwayWorld: Codable, Equatable, Sendable {
    public static let seedCap = 3
    public static let gemPerHour = 2
    public static let gemCap = 24

    public var seeds: [StarSeed]
    public var trip: SpaceTrip?
    public var treeAt: Date
    public var seenAt: Date
    public var postcards: [Postcard]
    public var doodle: String

    public init(
        seeds: [StarSeed] = [],
        trip: SpaceTrip? = nil,
        treeAt: Date,
        seenAt: Date,
        postcards: [Postcard] = [],
        doodle: String = ""
    ) {
        self.seeds = seeds
        self.trip = trip
        self.treeAt = treeAt
        self.seenAt = seenAt
        self.postcards = postcards
        self.doodle = doodle
    }

    public static func fresh(at date: Date) -> AwayWorld {
        AwayWorld(treeAt: date, seenAt: date)
    }

    public func traveling(at now: Date) -> Bool {
        guard let trip else { return false }
        return !trip.isBack(at: now)
    }
}

public struct AwayReport: Equatable, Sendable {
    public var lines: [String]
    public var gift: Int

    public init(lines: [String], gift: Int) {
        self.lines = lines
        self.gift = gift
    }
}

public enum AwayLife {
    public static func plant(_ world: AwayWorld, at now: Date) -> AwayWorld? {
        guard world.seeds.count < AwayWorld.seedCap else { return nil }
        var world = world
        world.seeds.append(StarSeed(plantedAt: now))
        return world
    }

    public static func harvest(_ world: AwayWorld, at now: Date) -> (AwayWorld, Int)? {
        let ready = world.seeds.filter { $0.stage(at: now) >= 3 }
        guard !ready.isEmpty else { return nil }
        var world = world
        world.seeds.removeAll { $0.stage(at: now) >= 3 }
        return (world, ready.count * 12)
    }

    public static func launch(_ world: AwayWorld, hours: Int, at now: Date) -> AwayWorld? {
        guard [1, 4, 8].contains(hours), !world.traveling(at: now) else { return nil }
        var world = world
        world.trip = SpaceTrip(startedAt: now, hours: hours)
        return world
    }

    public static func collectTrip(_ world: AwayWorld, at now: Date) -> (AwayWorld, Postcard)? {
        guard let trip = world.trip, trip.isBack(at: now) else { return nil }
        var world = world
        world.trip = nil
        let card = Postcard(
            title: trip.hours >= 8 ? "The far moon" : (trip.hours >= 4 ? "A quiet ring" : "A short hop"),
            message: "I brought something shiny home.",
            at: now,
            souvenir: trip.hours >= 8 ? "a tiny helmet charm" : "a pocket of gems"
        )
        world.postcards.insert(card, at: 0)
        return (world, card)
    }

    public static func pendingGems(_ world: AwayWorld, at now: Date) -> Int {
        let hours = max(0, now.timeIntervalSince(world.treeAt) / 3600)
        return min(AwayWorld.gemCap, Int(hours * Double(AwayWorld.gemPerHour)))
    }

    public static func collectTree(_ world: AwayWorld, at now: Date) -> (AwayWorld, Int) {
        let gems = pendingGems(world, at: now)
        guard gems > 0 else { return (world, 0) }
        var world = world
        world.treeAt = now
        return (world, gems)
    }

    /// What changed since the player last opened the room. Safe to call often.
    public static func catchUp(_ world: AwayWorld, at now: Date) -> (AwayWorld, AwayReport) {
        var world = world
        let away = now.timeIntervalSince(world.seenAt)
        var lines: [String] = []
        var gift = 0
        if away >= 30 * 60 {
            let roll = Int(world.seenAt.timeIntervalSince1970) % 3
            switch roll {
            case 0:
                world.doodle = "doodle"
                lines.append("They doodled on the wall.")
                gift = 4
                lines.append("A visitor left a gift.")
            case 1:
                world.doodle = "toys"
                lines.append("They knocked a toy around.")
            default:
                world.doodle = "nap"
                lines.append("They took an extra nap.")
            }
            if world.seeds.contains(where: { $0.stage(at: now) >= 3 }) {
                lines.append("Your star seeds are ready.")
            }
            if world.trip?.isBack(at: now) == true {
                lines.append("Back from the stars with a gift.")
            }
            if pendingGems(world, at: now) > 0 {
                lines.append("The gem tree has fruit.")
            }
        }
        world.seenAt = now
        return (world, AwayReport(lines: lines, gift: gift))
    }
}
