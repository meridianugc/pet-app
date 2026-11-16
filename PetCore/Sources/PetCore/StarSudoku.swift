import Foundation

public enum SudokuDifficulty: String, CaseIterable, Equatable, Sendable {
    case easy
    case medium
    case hard
    case expert

    public var clueTarget: Int {
        switch self {
        case .easy: return 46
        case .medium: return 36
        case .hard: return 30
        case .expert: return 24
        }
    }

    public var unlockLevel: Int {
        switch self {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 4
        case .expert: return 6
        }
    }
}

public struct SudokuPuzzle: Equatable, Sendable {
    public var given: [Int]
    public var solution: [Int]

    public init(given: [Int], solution: [Int]) {
        self.given = given
        self.solution = solution
    }

    public var clueCount: Int { given.filter { $0 != 0 }.count }

    public static func generate(seed: UInt64, difficulty: SudokuDifficulty) -> SudokuPuzzle {
        var state = seed == 0 ? 1 : seed
        func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1
            return state
        }
        var filled = Array(repeating: 0, count: 81)
        _ = fill(&filled, draw: next)
        var puzzle = filled
        var order = Array(0..<81)
        for index in stride(from: order.count - 1, through: 1, by: -1) {
            order.swapAt(index, Int(next() % UInt64(index + 1)))
        }
        for index in order {
            if puzzle.filter({ $0 != 0 }).count <= difficulty.clueTarget { break }
            let saved = puzzle[index]
            guard saved != 0 else { continue }
            puzzle[index] = 0
            if solutionCount(puzzle, limit: 2) != 1 {
                puzzle[index] = saved
            }
        }
        return SudokuPuzzle(given: puzzle, solution: filled)
    }

    public static func solutionCount(_ cells: [Int], limit: Int = 2) -> Int {
        count(cells, limit: limit)
    }

    public static func conflicts(_ cells: [Int], at index: Int) -> Bool {
        let value = cells[index]
        guard value != 0 else { return false }
        let row = index / 9
        let column = index % 9
        for other in cells.indices where other != index && cells[other] == value {
            let otherRow = other / 9
            let otherColumn = other % 9
            if otherRow == row || otherColumn == column { return true }
            if otherRow / 3 == row / 3 && otherColumn / 3 == column / 3 { return true }
        }
        return false
    }

    public static func isSolved(_ cells: [Int]) -> Bool {
        guard cells.count == 81, cells.allSatisfy({ $0 >= 1 && $0 <= 9 }) else { return false }
        return cells.indices.allSatisfy { !conflicts(cells, at: $0) }
    }

    private static func fill(_ cells: inout [Int], draw: () -> UInt64) -> Bool {
        guard let index = cells.firstIndex(of: 0) else { return true }
        var digits = Array(1...9)
        for cursor in stride(from: digits.count - 1, through: 1, by: -1) {
            digits.swapAt(cursor, Int(draw() % UInt64(cursor + 1)))
        }
        for digit in digits where !hits(cells, index, digit) {
            cells[index] = digit
            if fill(&cells, draw: draw) { return true }
            cells[index] = 0
        }
        return false
    }

    private static func count(_ cells: [Int], limit: Int) -> Int {
        guard limit > 0 else { return 0 }
        guard let index = emptiest(cells) else { return 1 }
        let options = (1...9).filter { !hits(cells, index, $0) }
        if options.isEmpty { return 0 }
        var total = 0
        for digit in options {
            var next = cells
            next[index] = digit
            total += count(next, limit: limit - total)
            if total >= limit { return total }
        }
        return total
    }

    private static func emptiest(_ cells: [Int]) -> Int? {
        var best: Int?
        var bestCount = 10
        for index in cells.indices where cells[index] == 0 {
            let options = (1...9).filter { !hits(cells, index, $0) }.count
            if options < bestCount {
                best = index
                bestCount = options
                if options == 0 { return index }
            }
        }
        return best
    }

    private static func hits(_ cells: [Int], _ index: Int, _ digit: Int) -> Bool {
        let row = index / 9
        let column = index % 9
        for other in 0..<81 where cells[other] == digit {
            let otherRow = other / 9
            let otherColumn = other % 9
            if otherRow == row || otherColumn == column { return true }
            if otherRow / 3 == row / 3 && otherColumn / 3 == column / 3 { return true }
        }
        return false
    }
}

public enum StarSudoku {
    public static func isOpen(_ difficulty: SudokuDifficulty, petLevel: Int, cleared: Set<String>) -> Bool {
        if petLevel < difficulty.unlockLevel { return false }
        switch difficulty {
        case .easy: return true
        case .medium: return cleared.contains(SudokuDifficulty.easy.rawValue)
        case .hard: return cleared.contains(SudokuDifficulty.medium.rawValue)
        case .expert: return cleared.contains(SudokuDifficulty.hard.rawValue)
        }
    }

    public static func stars(mistakes: Int, hints: Int, solved: Bool) -> Int {
        guard solved else { return 0 }
        if mistakes == 0 && hints == 0 { return 3 }
        if mistakes + hints <= 2 { return 2 }
        return 1
    }
}
