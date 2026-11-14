import XCTest
@testable import PetCore

final class StarSudokuTests: XCTestCase {
    func testAPuzzleHasOneSolutionAndMatchesIt() {
        let puzzle = SudokuPuzzle.generate(seed: 21, difficulty: .easy)
        XCTAssertEqual(puzzle.given.count, 81)
        XCTAssertEqual(SudokuPuzzle.solutionCount(puzzle.given), 1)
        XCTAssertTrue(SudokuPuzzle.isSolved(puzzle.solution))
        for index in puzzle.given.indices where puzzle.given[index] != 0 {
            XCTAssertEqual(puzzle.given[index], puzzle.solution[index])
        }
        let again = SudokuPuzzle.generate(seed: 21, difficulty: .easy)
        XCTAssertEqual(puzzle, again)
    }

    func testHarderBoardsKeepFewerClues() {
        let easy = SudokuPuzzle.generate(seed: 4, difficulty: .easy)
        let hard = SudokuPuzzle.generate(seed: 4, difficulty: .hard)
        XCTAssertLessThanOrEqual(hard.clueCount, easy.clueCount)
        XCTAssertEqual(SudokuPuzzle.solutionCount(hard.given), 1)
    }

    func testConflictsAndStars() {
        var cells = Array(repeating: 0, count: 81)
        cells[0] = 5
        cells[1] = 5
        XCTAssertTrue(SudokuPuzzle.conflicts(cells, at: 1))
        XCTAssertFalse(StarSudoku.isOpen(.medium, petLevel: 3, cleared: []))
        XCTAssertTrue(StarSudoku.isOpen(.medium, petLevel: 3, cleared: ["easy"]))
        XCTAssertEqual(StarSudoku.stars(mistakes: 0, hints: 0, solved: true), 3)
        XCTAssertEqual(StarSudoku.stars(mistakes: 1, hints: 0, solved: false), 0)
    }
}
