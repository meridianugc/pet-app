import Foundation

/// A point on the bedroom floor. x is left to right, z is closet to window.
public struct FloorPoint: Equatable, Sendable {
    public var x: Double
    public var z: Double

    public init(x: Double, z: Double) {
        self.x = x
        self.z = z
    }

    public func distance(to other: FloorPoint) -> Double {
        hypot(x - other.x, z - other.z)
    }
}

public enum RoomWing: Equatable, Sendable {
    case bedroom
    case kitchen
}

public struct FloorBox: Equatable, Sendable {
    public var minX: Double
    public var maxX: Double
    public var minZ: Double
    public var maxZ: Double

    public init(minX: Double, maxX: Double, minZ: Double, maxZ: Double) {
        self.minX = minX
        self.maxX = maxX
        self.minZ = minZ
        self.maxZ = maxZ
    }
}

/// Walking, collision, and pickup for the 3D bedroom. Saved spots stay on `PlayRoom`.
public enum RoomSpace {
    public static let limit = 2.15
    public static let body = 0.28
    public static let reach = 0.85

    public static let bin = FloorPoint(x: 1.7, z: 1.45)
    public static let shelf = FloorPoint(x: -1.85, z: 0.15)
    public static let closet = FloorPoint(x: 0, z: -1.85)
    public static let bed = FloorPoint(x: -1.1, z: -0.75)

    public static let solids: [FloorBox] = [
        FloorBox(minX: -2.05, maxX: -0.15, minZ: -2.15, maxZ: -1.05),
        FloorBox(minX: -0.75, maxX: 0.75, minZ: -2.2, maxZ: -1.72),
        FloorBox(minX: -2.2, maxX: -1.72, minZ: -0.7, maxZ: 0.85),
        FloorBox(minX: 1.35, maxX: 2.15, minZ: 1.05, maxZ: 1.9),
        FloorBox(minX: -2.2, maxX: -1.15, minZ: 0.75, maxZ: 1.7),
        FloorBox(minX: 0.7, maxX: 1.35, minZ: 0.6, maxZ: 1.25),
        FloorBox(minX: 1.05, maxX: 1.5, minZ: 0.3, maxZ: 0.8)
    ]

    public static let kitchenSolids: [FloorBox] = [
        FloorBox(minX: -0.7, maxX: 2.05, minZ: -2.2, maxZ: -1.45),
        FloorBox(minX: -0.75, maxX: 1.15, minZ: 0.0, maxZ: 1.25),
        FloorBox(minX: 0.95, maxX: 1.5, minZ: 0.9, maxZ: 1.45)
    ]

    public static func floor(from spot: RoomSpot) -> FloorPoint {
        FloorPoint(x: (spot.x - 0.5) * 4.2, z: (spot.y - 0.5) * 4.2)
    }

    public static func spot(from floor: FloorPoint) -> RoomSpot {
        RoomSpot(
            x: min(0.92, max(0.08, floor.x / 4.2 + 0.5)),
            y: min(0.92, max(0.08, floor.z / 4.2 + 0.5))
        )
    }

    public static func blocked(_ point: FloorPoint, radius: Double = body, wing: RoomWing = .bedroom) -> Bool {
        if abs(point.x) + radius > limit || abs(point.z) + radius > limit { return true }
        let boxes = wing == .kitchen ? kitchenSolids : solids
        for box in boxes {
            let hitsX = point.x + radius > box.minX && point.x - radius < box.maxX
            let hitsZ = point.z + radius > box.minZ && point.z - radius < box.maxZ
            if hitsX && hitsZ { return true }
        }
        return false
    }

    /// `stickX` and `stickY` are -1...1. Up on the stick is forward, relative to `yaw`.
    public static func walk(
        from point: FloorPoint,
        yaw: Double,
        stickX: Double,
        stickY: Double,
        dt: Double,
        wing: RoomWing = .bedroom
    ) -> (FloorPoint, yaw: Double, moving: Bool) {
        let input = min(1, hypot(stickX, stickY))
        guard input > 0.08, dt > 0 else { return (point, yaw, false) }
        let nx = stickX / input
        let ny = stickY / input
        let worldX = sin(yaw) * ny + cos(yaw) * nx
        let worldZ = -cos(yaw) * ny + sin(yaw) * nx
        let step = 1.7 * input * dt
        let moved = slide(point, dx: worldX * step, dz: worldZ * step, wing: wing)
        let facing = atan2(worldX, -worldZ)
        return (moved, turn(from: yaw, toward: facing, dt: dt), true)
    }

    public static func slide(_ point: FloorPoint, dx: Double, dz: Double, wing: RoomWing = .bedroom) -> FloorPoint {
        let both = FloorPoint(x: point.x + dx, z: point.z + dz)
        if !blocked(both, wing: wing) { return both }
        let alongX = FloorPoint(x: point.x + dx, z: point.z)
        if !blocked(alongX, wing: wing) { return alongX }
        let alongZ = FloorPoint(x: point.x, z: point.z + dz)
        if !blocked(alongZ, wing: wing) { return alongZ }
        return point
    }

    public static func looseThings(in room: PlayRoom) -> [RoomThing] {
        room.things.filter { !$0.tucked && !$0.carried }
    }

    public static func nearestLoose(in room: PlayRoom, at point: FloorPoint) -> RoomThing? {
        looseThings(in: room)
            .map { ($0, floor(from: $0.spot).distance(to: point)) }
            .filter { $0.1 <= reach }
            .min { $0.1 < $1.1 }?
            .0
    }

    public static func pickUp(_ id: String, in room: PlayRoom) -> PlayRoom? {
        guard let index = room.things.firstIndex(where: { $0.id == id && !$0.tucked && !$0.carried }) else { return nil }
        guard !room.things.contains(where: \.carried) else { return nil }
        var room = room
        room.things[index].carried = true
        return room
    }

    public static func carried(in room: PlayRoom) -> RoomThing? {
        room.things.first { $0.carried }
    }

    /// Put a carried toy in the bin, or decor on the shelf. Uses the existing snap reward.
    public static func putDown(in room: PlayRoom, at point: FloorPoint) -> (PlayRoom, reward: Int)? {
        guard let held = carried(in: room), let index = room.things.firstIndex(where: { $0.id == held.id }) else { return nil }
        let atBin = point.distance(to: bin) <= reach && held.kind == .toy
        let atShelf = point.distance(to: shelf) <= reach && held.kind == .decor
        let atBed = point.distance(to: bed) <= reach && held.kind == .snack
        guard atBin || atShelf || atBed else { return nil }
        var room = room
        room.things[index].carried = false
        let anchor = room.furniture.first { $0.id == held.home }?.anchor ?? held.spot
        let dropped = RoomRules.drop(room.things[index], at: anchor, in: room)
        room.things[index] = dropped.0
        room.things[index].carried = false
        return (room, dropped.reward)
    }

    public static func nearCloset(_ point: FloorPoint) -> Bool {
        point.distance(to: closet) <= reach
    }

    private static func turn(from yaw: Double, toward target: Double, dt: Double) -> Double {
        var gap = target - yaw
        while gap > .pi { gap -= .pi * 2 }
        while gap < -.pi { gap += .pi * 2 }
        let step = min(abs(gap), 8 * dt)
        return yaw + (gap >= 0 ? step : -step)
    }
}
