import Foundation

public enum SnackMatch {
    public static let kinds = 5
    public static let stripeOffset = 10
    public static let bombOffset = 20

    public static func isStripe(_ tile: Int) -> Bool {
        tile >= stripeOffset && tile < bombOffset
    }

    public static func isBomb(_ tile: Int) -> Bool { tile >= bombOffset }

    public static func hue(of tile: Int) -> Int {
        if isBomb(tile) { return tile - bombOffset }
        if isStripe(tile) { return tile - stripeOffset }
        return tile
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
            let column = index % width
            for x in 0..<width {
                matched.insert(row * width + x)
            }
            for y in 0..<height {
                matched.insert(y * width + column)
            }
        }
        let bombs = matched.filter { isBomb(cells[$0]) }
        for index in bombs {
            let color = hue(of: cells[index])
            for spot in cells.indices where hue(of: cells[spot]) == color {
                matched.insert(spot)
            }
        }
        return matched
    }

    public static func hasMove(in cells: [Int], width: Int, height: Int) -> Bool {
        hint(in: cells, width: width, height: height) != nil
    }

    /// One swap that would match, so the board can glow a hint.
    public static func hint(in cells: [Int], width: Int, height: Int) -> (Int, Int)? {
        guard width > 0, cells.count == width * height else { return nil }
        for index in cells.indices {
            let x = index % width
            let y = index / width
            if x + 1 < width, swapMatches(cells, width: width, height: height, a: index, b: index + 1) {
                return (index, index + 1)
            }
            if y + 1 < height, swapMatches(cells, width: width, height: height, a: index, b: index + width) {
                return (index, index + width)
            }
        }
        return nil
    }

    public static func reshuffled(_ cells: [Int], width: Int, height: Int, seed: UInt64) -> [Int] {
        var state = seed == 0 ? 1 : seed
        func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1
            return state
        }
        var best = cells
        for _ in 0..<16 {
            var deck = cells
            if deck.count > 1 {
                for index in stride(from: deck.count - 1, through: 1, by: -1) {
                    deck.swapAt(index, Int(next() % UInt64(index + 1)))
                }
            }
            best = deck
            if matchedIndexes(in: deck, width: width, height: height).isEmpty, hasMove(in: deck, width: width, height: height) {
                return deck
            }
        }
        return best
    }

    public static func smash(
        cells: [Int],
        width: Int,
        height: Int,
        index: Int,
        refill: () -> Int
    ) -> Outcome? {
        guard cells.indices.contains(index) else { return nil }
        return cascade(cells, width: width, height: height, clearing: [index], refill: refill)
    }

    public static func clearColor(
        cells: [Int],
        width: Int,
        height: Int,
        hue color: Int,
        refill: () -> Int
    ) -> Outcome? {
        let clearing = Set(cells.indices.filter { hue(of: cells[$0]) == color })
        guard !clearing.isEmpty else { return nil }
        return cascade(cells, width: width, height: height, clearing: clearing, refill: refill)
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
        public var madeBomb: Bool
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
        let resolved = cascade(board, width: width, height: height, clearing: [], refill: refill)
        return resolved
    }

    private static func swapMatches(_ cells: [Int], width: Int, height: Int, a: Int, b: Int) -> Bool {
        var copy = cells
        copy.swapAt(a, b)
        return !matchedIndexes(in: copy, width: width, height: height).isEmpty
    }

    private static func cascade(
        _ cells: [Int],
        width: Int,
        height: Int,
        clearing: Set<Int>,
        refill: () -> Int
    ) -> Outcome {
        var board = clearing.isEmpty ? cells : drop(cells: cells, width: width, height: height, clearing: clearing, refill: refill)
        var total = clearing.isEmpty ? 0 : points(forClearing: clearing.count, lineLength: 1)
        var cascades = clearing.isEmpty ? 0 : 1
        var madeStripe = false
        var madeBomb = false
        var guardrail = 0
        while guardrail < 8 {
            guardrail += 1
            let matched = matchedIndexes(in: board, width: width, height: height)
            if matched.isEmpty { break }
            cascades += 1
            let longest = longestRun(in: matched, width: width)
            total += points(forClearing: matched.count, lineLength: longest) * cascades
            if longest >= 5 { madeBomb = true }
            if longest >= 4 { madeStripe = true }
            let spot = matched.min()
            let color = spot.map { hue(of: board[$0]) } ?? 0
            board = drop(cells: board, width: width, height: height, clearing: matched, refill: refill)
            if let spot, board.indices.contains(spot), longest >= 4 {
                board[spot] = (longest >= 5 ? bombOffset : stripeOffset) + (color % kinds)
            }
        }
        return Outcome(cells: board, points: total, cascades: cascades, madeStripe: madeStripe, madeBomb: madeBomb)
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
