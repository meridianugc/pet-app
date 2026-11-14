import Foundation

public enum PlanetMerge {
    public static let largest = 6

    /// Two planets of `size` become the next size. The biggest size does not merge further.
    public static func nextSize(after size: Int) -> Int? {
        guard size >= 0, size < largest else { return nil }
        return size + 1
    }

    public static func points(forMerging size: Int, combo: Int) -> Int {
        let base = (size + 1) * 4
        return base * max(1, combo)
    }

    /// Drop radius in points, growing quickly so later planets feel heavy.
    public static func radius(for size: Int) -> Double {
        16 + Double(max(0, size)) * 11
    }
}
