import Foundation

/// One side of the bedroom. Swiping turns the view from one wall to the next.
public enum RoomWall: Int, Codable, CaseIterable, Sendable {
    case toys
    case closet
    case bed
    case window

    public var title: String {
        switch self {
        case .toys: return "Toy wall"
        case .closet: return "Closet wall"
        case .bed: return "Bed wall"
        case .window: return "Window wall"
        }
    }

    public var next: RoomWall {
        RoomWall(rawValue: (rawValue + 1) % 4) ?? .toys
    }

    public var previous: RoomWall {
        RoomWall(rawValue: (rawValue + 3) % 4) ?? .window
    }
}

public enum RoomKind: String, Codable, Equatable, Sendable {
    case toy
    case snack
    case decor
    case clothes
}

/// A spot on a wall. x runs left to right. y runs from the front of the floor up the wall.
public struct RoomSpot: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func distance(to other: RoomSpot) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

public struct RoomZone: Equatable, Sendable, Identifiable {
    public var id: String
    public var wall: RoomWall
    public var kind: RoomKind
    public var center: RoomSpot
    public var reach: Double

    public init(id: String, wall: RoomWall, kind: RoomKind, center: RoomSpot, reach: Double) {
        self.id = id
        self.wall = wall
        self.kind = kind
        self.center = center
        self.reach = reach
    }
}

public struct RoomThing: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: RoomKind
    public var wall: RoomWall
    public var spot: RoomSpot
    /// Furniture id this thing belongs in.
    public var home: String
    public var tucked: Bool

    public init(id: String, kind: RoomKind, wall: RoomWall, spot: RoomSpot, home: String, tucked: Bool) {
        self.id = id
        self.kind = kind
        self.wall = wall
        self.spot = spot
        self.home = home
        self.tucked = tucked
    }
}

public struct RoomFurniture: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var wall: RoomWall
    public var anchor: RoomSpot

    public init(id: String, wall: RoomWall, anchor: RoomSpot) {
        self.id = id
        self.wall = wall
        self.anchor = anchor
    }
}

/// Saved bedroom. Positions stay put across launches.
public struct PlayRoom: Codable, Equatable, Sendable {
    public var wall: RoomWall
    public var petWall: RoomWall
    public var pet: RoomSpot
    public var things: [RoomThing]
    public var furniture: [RoomFurniture]
    public var closetOpen: Bool

    public init(
        wall: RoomWall = .toys,
        petWall: RoomWall = .toys,
        pet: RoomSpot = RoomSpot(x: 0.5, y: 0.2),
        things: [RoomThing] = [],
        furniture: [RoomFurniture] = [],
        closetOpen: Bool = false
    ) {
        self.wall = wall
        self.petWall = petWall
        self.pet = pet
        self.things = things
        self.furniture = furniture
        self.closetOpen = closetOpen
    }

    public static func starter(looseToy: String = "") -> PlayRoom {
        let furniture = [
            RoomFurniture(id: "bin", wall: .toys, anchor: RoomSpot(x: 0.28, y: 0.46)),
            RoomFurniture(id: "closet", wall: .closet, anchor: RoomSpot(x: 0.5, y: 0.5)),
            RoomFurniture(id: "bed", wall: .bed, anchor: RoomSpot(x: 0.58, y: 0.42)),
            RoomFurniture(id: "shelf", wall: .window, anchor: RoomSpot(x: 0.5, y: 0.66))
        ]
        let cometLoose = looseToy == "toy_comet" || looseToy.isEmpty == false
        let things = [
            RoomThing(
                id: "toy_comet",
                kind: .toy,
                wall: cometLoose ? .toys : .toys,
                spot: cometLoose ? RoomSpot(x: 0.72, y: 0.16) : RoomSpot(x: 0.28, y: 0.46),
                home: "bin",
                tucked: !cometLoose
            ),
            RoomThing(id: "toy_moon", kind: .toy, wall: .toys, spot: RoomSpot(x: 0.28, y: 0.46), home: "bin", tucked: true),
            RoomThing(id: "snack_cookie", kind: .snack, wall: .bed, spot: RoomSpot(x: 0.3, y: 0.14), home: "bed", tucked: false),
            RoomThing(id: "decor_star", kind: .decor, wall: .window, spot: RoomSpot(x: 0.5, y: 0.66), home: "shelf", tucked: true)
        ]
        return PlayRoom(things: things, furniture: furniture)
    }

    /// If the away life left a toy out, make sure it is on the floor.
    public func adoptingLooseToy(_ id: String) -> PlayRoom {
        guard !id.isEmpty else { return self }
        var room = self
        if let index = room.things.firstIndex(where: { $0.id == id }) {
            if room.things[index].tucked {
                room.things[index].tucked = false
                room.things[index].wall = .toys
                room.things[index].spot = RoomSpot(x: 0.72, y: 0.16)
            }
            return room
        }
        room.things.append(RoomThing(id: id, kind: .toy, wall: .toys, spot: RoomSpot(x: 0.72, y: 0.16), home: "bin", tucked: false))
        return room
    }
}

public enum RoomRules {
    public static let tidyGems = 3
    public static let floorLow = 0.08
    public static let floorHigh = 0.36

    public static func zones(in room: PlayRoom) -> [RoomZone] {
        room.furniture.map { piece in
            let kind: RoomKind
            switch piece.id {
            case "closet": kind = .clothes
            case "bed": kind = .snack
            case "shelf": kind = .decor
            default: kind = .toy
            }
            return RoomZone(id: piece.id, wall: piece.wall, kind: kind, center: piece.anchor, reach: 0.16)
        }
    }

    public static func zone(at spot: RoomSpot, on wall: RoomWall, kind: RoomKind, in room: PlayRoom) -> RoomZone? {
        zones(in: room).first { zone in
            zone.wall == wall && zone.kind == kind && spot.distance(to: zone.center) <= zone.reach
        }
    }

    /// Drop a thing. Matching a home zone tucks it and may pay the tidy reward.
    public static func drop(_ thing: RoomThing, at spot: RoomSpot, in room: PlayRoom) -> (RoomThing, reward: Int) {
        var next = thing
        next.wall = thing.wall
        next.spot = clampFloor(spot, for: thing.kind)
        let wasTucked = thing.tucked
        if let zone = zone(at: spot, on: thing.wall, kind: thing.kind, in: room), zone.id == thing.home {
            next.spot = zone.center
            next.wall = zone.wall
            next.tucked = true
        } else {
            next.tucked = false
        }
        let reward = (!wasTucked && next.tucked && thing.kind == .toy) ? tidyGems : 0
        return (next, reward)
    }

    public static func clampFloor(_ spot: RoomSpot, for kind: RoomKind) -> RoomSpot {
        if kind == .decor {
            return RoomSpot(x: min(0.9, max(0.1, spot.x)), y: min(0.84, max(0.4, spot.y)))
        }
        return RoomSpot(x: min(0.92, max(0.08, spot.x)), y: min(floorHigh, max(floorLow, spot.y)))
    }

    public static func moveFurniture(_ id: String, to wall: RoomWall, in room: PlayRoom) -> PlayRoom {
        guard let index = room.furniture.firstIndex(where: { $0.id == id }) else { return room }
        var room = room
        let previous = room.furniture[index].wall
        if let other = room.furniture.firstIndex(where: { $0.wall == wall && $0.id != id }) {
            room.furniture[other].wall = previous
        }
        room.furniture[index].wall = wall
        let moved = zones(in: room)
        for thingIndex in room.things.indices where room.things[thingIndex].tucked {
            if let zone = moved.first(where: { $0.id == room.things[thingIndex].home }) {
                room.things[thingIndex].wall = zone.wall
                room.things[thingIndex].spot = zone.center
            }
        }
        return room
    }

    public static func stepPet(_ room: PlayRoom, toward: RoomSpot, dt: Double) -> (PlayRoom, arrived: Bool) {
        var room = room
        let goal = RoomSpot(
            x: min(0.92, max(0.08, toward.x)),
            y: min(floorHigh, max(floorLow, toward.y))
        )
        let speed = 0.55 * max(0, dt)
        let dx = goal.x - room.pet.x
        let dy = goal.y - room.pet.y
        let distance = hypot(dx, dy)
        if distance <= speed || distance < 0.02 {
            room.pet = goal
            return (room, true)
        }
        room.pet = RoomSpot(x: room.pet.x + dx / distance * speed, y: room.pet.y + dy / distance * speed)
        return (room, false)
    }

    public static func wanderTarget(from spot: RoomSpot, seed: Int) -> RoomSpot {
        let swing = Double(abs(seed) % 7) / 10
        return RoomSpot(x: min(0.88, max(0.12, spot.x + swing - 0.3)), y: floorLow + Double(abs(seed) % 5) * 0.04)
    }

    public static func nearbyToy(in room: PlayRoom, reach: Double = 0.14) -> RoomThing? {
        room.things.first { thing in
            thing.kind == .toy && !thing.tucked && thing.wall == room.petWall && thing.spot.distance(to: room.pet) <= reach
        }
    }

    public static func closetAnchor(in room: PlayRoom) -> RoomSpot? {
        room.furniture.first { $0.id == "closet" }?.anchor
    }

    public static func canOpenCloset(_ room: PlayRoom) -> Bool {
        guard let closet = room.furniture.first(where: { $0.id == "closet" }) else { return false }
        guard room.petWall == closet.wall else { return false }
        return room.pet.distance(to: RoomSpot(x: closet.anchor.x, y: min(floorHigh, closet.anchor.y))) <= 0.22
            || room.pet.distance(to: closet.anchor) <= 0.28
    }
}
