import Foundation

public enum SnackMatch {
    public static let kinds = 5
    public static let stripeOffset = 10

    public static func isStripe(_ tile: Int) -> Bool { tile >= stripeOffset }

    public static func hue(of tile: Int) -> Int {
        isStripe(tile) ? tile - stripeOffset : tile
    }

    public static func areNeighbors(_ a: Int, _ b: Int, width: Int) -> Bool {
        guard a != b, width > 0 else { return false }
        let ax = a % width
        let ay = a / width
        let bx = b % width
        let by = b / width
        return abs(ax - bx) + abs(ay - by) == 1
    }

    /// Groups of 3 or more in a straight line. A stripe also clears its whole row.
    public static func matchedIndexes(in cells: [Int], width: Int, height: Int) -> Set<Int> {
        guard width > 0, height > 0, cells.count == width * height else { return [] }
        var matched = Set<Int>()
        for y in 0..<height {
            var run: [Int] = []
            var color: Int?
            func close() {
                if run.count >= 3 { matched.formUnion(run) }
                run = []
                color = nil
            }
            for x in 0..<width {
                let index = y * width + x
                let tileColor = hue(of: cells[index])
                if tileColor == color {
                    run.append(index)
                } else {
                    close()
                    color = tileColor
                    run = [index]
                }
            }
            close()
        }
        for x in 0..<width {
            var run: [Int] = []
            var color: Int?
            func close() {
                if run.count >= 3 { matched.formUnion(run) }
                run = []
                color = nil
            }
            for y in 0..<height {
                let index = y * width + x
                let tileColor = hue(of: cells[index])
                if tileColor == color {
                    run.append(index)
                } else {
                    close()
                    color = tileColor
                    run = [index]
                }
            }
            close()
        }
        let stripes = matched.filter { isStripe(cells[$0]) }
        for index in stripes {
            let row = index / width
            for x in 0..<width {
                matched.insert(row * width + x)
            }
        }
        return matched
    }

    public static func points(forClearing count: Int, lineLength: Int) -> Int {
        let bonus = lineLength >= 5 ? 30 : (lineLength >= 4 ? 12 : 0)
        return count * 5 + bonus
    }

    /// Drops tiles into the holes and fills the top with `refill`, which is called once per hole.
    public static func drop(cells: [Int], width: Int, height: Int, clearing: Set<Int>, refill: () -> Int) -> [Int] {
        var next = cells
        guard width > 0, cells.count == width * height else { return cells }
        for x in 0..<width {
            var stack: [Int] = []
            for y in stride(from: height - 1, through: 0, by: -1) {
                let index = y * width + x
                if !clearing.contains(index) {
                    stack.append(cells[index])
                }
            }
            for y in stride(from: height - 1, through: 0, by: -1) {
                let index = y * width + x
                if stack.isEmpty {
                    next[index] = refill()
                } else {
                    next[index] = stack.removeFirst()
                }
            }
        }
        return next
    }

    public struct Outcome: Equatable {
        public var cells: [Int]
        public var points: Int
        public var cascades: Int
        public var madeStripe: Bool
    }

    /// Swaps two neighbors. Returns nil when the swap is illegal or makes no match.
    public static func swapAndResolve(
        cells: [Int],
        width: Int,
        height: Int,
        a: Int,
        b: Int,
        refill: () -> Int
    ) -> Outcome? {
        guard areNeighbors(a, b, width: width), cells.indices.contains(a), cells.indices.contains(b) else { return nil }
        var board = cells
        board.swapAt(a, b)
        guard !matchedIndexes(in: board, width: width, height: height).isEmpty else { return nil }
        var total = 0
        var cascades = 0
        var madeStripe = false
        var guardrail = 0
        while guardrail < 8 {
            guardrail += 1
            let matched = matchedIndexes(in: board, width: width, height: height)
            if matched.isEmpty { break }
            cascades += 1
            let longest = longestRun(in: matched, width: width)
            total += Self.points(forClearing: matched.count, lineLength: longest)
            if longest >= 4 { madeStripe = true }
            board = drop(cells: board, width: width, height: height, clearing: matched, refill: refill)
            if longest >= 4, let spot = matched.min() {
                let color = hue(of: cells[min(spot, cells.count - 1)])
                if board.indices.contains(spot) {
                    board[spot] = stripeOffset + (color % kinds)
                }
            }
        }
        return Outcome(cells: board, points: total, cascades: cascades, madeStripe: madeStripe)
    }

    private static func longestRun(in matched: Set<Int>, width: Int) -> Int {
        var best = 1
        let rows = Dictionary(grouping: matched) { $0 / width }
        for indexes in rows.values {
            best = max(best, indexes.count)
        }
        let columns = Dictionary(grouping: matched) { $0 % width }
        for indexes in columns.values {
            best = max(best, indexes.count)
        }
        return best
    }
}
