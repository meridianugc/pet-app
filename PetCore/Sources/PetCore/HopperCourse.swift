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
    /// 1 is a full-width launch pad. Later pads are narrower.
    public var span: Double

    public init(x: Double, y: Double, kind: Kind, span: Double = 0.46) {
        self.x = x
        self.y = y
        self.kind = kind
        self.span = span
    }
}

public enum HopperCourse {
    public static let easyPadCount = 8
    /// How far sideways the alien can drift during one hop, as a fraction of the screen.
    public static let maxHorizontalStep = 0.28
    /// Tallest gap a normal hop can clear.
    public static let maxVerticalGap = 110.0

    /// Platforms from a seed, so a run can be replayed and tested.
    public static func pads(seed: UInt64, count: Int, spacing: Double = 88) -> [HopperPad] {
        guard count > 0 else { return [] }
        var state = seed == 0 ? 1 : seed
        func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
        let gap = min(max(40, spacing), maxVerticalGap)
        var pads: [HopperPad] = []
        var previousX = 0.5
        for index in 0..<count {
            if index == 0 {
                pads.append(HopperPad(x: 0.5, y: 0, kind: .steady, span: 1))
                continue
            }
            let roll = next() % 100
            let kind: HopperPad.Kind
            if index < easyPadCount {
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
            let reach = index < easyPadCount ? maxHorizontalStep : min(0.36, maxHorizontalStep + 0.06)
            let swing = (Double(next() % 1000) / 1000) * 2 - 1
            let x = min(0.82, max(0.18, previousX + swing * reach))
            previousX = x
            pads.append(HopperPad(x: x, y: Double(index) * gap, kind: kind, span: kind == .spring ? 0.4 : 0.5))
        }
        return pads
    }

    /// The opening of a course must be a chain of hops, never a gap you cannot clear.
    public static func openingIsReachable(_ pads: [HopperPad], count: Int = easyPadCount) -> Bool {
        let slice = Array(pads.prefix(min(count, pads.count)))
        guard let first = slice.first else { return true }
        guard first.kind == .steady, abs(first.x - 0.5) < 0.001, first.span >= 0.9 else { return false }
        for index in 1..<slice.count {
            let dx = abs(slice[index].x - slice[index - 1].x)
            let dy = slice[index].y - slice[index - 1].y
            if dx > maxHorizontalStep + 0.001 { return false }
            if dy <= 0 || dy > maxVerticalGap + 0.001 { return false }
            if index < easyPadCount, slice[index].kind != .steady { return false }
        }
        return true
    }
}
