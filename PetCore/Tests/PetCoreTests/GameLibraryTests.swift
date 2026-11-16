import XCTest
@testable import PetCore

final class GameLibraryTests: XCTestCase {
    func testBigAndMiniShelvesStaySeparate() {
        XCTAssertEqual(GameLibrary.big, [.starDefense, .shipDuo, .cosmicSolitaire, .starSudoku])
        XCTAssertEqual(GameLibrary.mini, [.snackMatch, .planetMerge, .starHopper])
        XCTAssertNil(GameLibrary.shelf(of: .starCatch))
        XCTAssertNil(GameLibrary.shelf(of: .memoryMatch))
        XCTAssertNil(GameLibrary.shelf(of: .hideAndSeek))
        XCTAssertEqual(GameLibrary.shelf(of: .shipDuo), "Big Games")
        XCTAssertEqual(GameLibrary.shelf(of: .starHopper), "Mini Games")
        let listed = GameLibrary.big + GameLibrary.mini
        XCTAssertEqual(Set(listed).count, listed.count)
    }
}
