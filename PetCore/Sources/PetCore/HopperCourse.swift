import Foundation

public struct HopperPad: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case steady
        case moving
        case crumbly
        case spring
    }

    public var x: Double
    public var y: Double
    public var kind: Kind

    public init(x: Double, y: Double, kind: Kind) {
        self.x = x
        self.y = y
        self.kind = kind
    }
}

public enum HopperCourse {
    /// Platforms from a seed, so a run can be replayed and tested.
    public static func pads(seed: UInt64, count: Int, spacing: Double = 88) -> [HopperPad] {
        guard count > 0 else { return [] }
        var state = seed == 0 ? 1 : seed
        func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
        var pads: [HopperPad] = []
        for index in 0..<count {
            let roll = next() % 100
            let kind: HopperPad.Kind
            if index == 0 {
                kind = .steady
            } else if roll < 58 {
                kind = .steady
            } else if roll < 78 {
                kind = .moving
            } else if roll < 92 {
                kind = .crumbly
            } else {
                kind = .spring
            }
            let x = 0.12 + Double(next() % 76) / 100
            pads.append(HopperPad(x: x, y: Double(index) * spacing, kind: kind))
        }
        return pads
    }
}
