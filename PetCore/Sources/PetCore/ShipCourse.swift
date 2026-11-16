import Foundation

/// A long floating course. Both sticks push the same ship.
public struct ShipRun: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var checkpoint: Double
    public var level: Int

    public init(x: Double = 0, y: Double = 0, checkpoint: Double = 0, level: Int = 1) {
        self.x = x
        self.y = y
        self.checkpoint = checkpoint
        self.level = level
    }
}

public enum ShipCourse {
    public static let length = 8_000.0
    public static let checkpoints = [1_600.0, 3_200.0, 4_800.0, 6_400.0]

    public static func obstacles(level: Int) -> [(Double, Double)] {
        var list: [(Double, Double)] = []
        var seed = level * 17 + 3
        var along = 420.0
        while along < length - 240 {
            seed = (seed * 1_103_515_245 + 12_345) & 0x7fff_ffff
            let across = Double(seed % 220) - 110
            list.append((across, along))
            along += 320
        }
        return list
    }

    /// `left` and `right` are joystick pairs from -1 to 1. Positive y moves the ship forward.
    public static func step(_ run: ShipRun, left: (Double, Double), right: (Double, Double), dt: Double) -> ShipRun {
        var run = run
        let across = (left.0 + right.0) * 140
        let forward = 42 + max(0, left.1) * 70 + max(0, right.1) * 70
        run.x = min(150, max(-150, run.x + across * dt))
        run.y += forward * dt
        for gate in checkpoints where run.y >= gate && run.checkpoint < gate {
            run.checkpoint = gate
        }
        for rock in obstacles(level: run.level) where hypot(run.x - rock.0, run.y - rock.1) < 34 {
            run.y = run.checkpoint
            run.x = 0
            break
        }
        if run.y >= length {
            run.level += 1
            run.y = 0
            run.x = 0
            run.checkpoint = 0
        }
        return run
    }
}

public enum PetCard {
    public static func text(name: String, form: String, level: Int) -> String {
        "pocketpet|\(name)|\(form)|\(level)"
    }

    public static func parse(_ raw: String) -> (name: String, form: String, level: Int)? {
        let parts = raw.split(separator: "|").map(String.init)
        guard parts.count == 4, parts[0] == "pocketpet", let level = Int(parts[3]) else { return nil }
        return (parts[1], parts[2], level)
    }
}
