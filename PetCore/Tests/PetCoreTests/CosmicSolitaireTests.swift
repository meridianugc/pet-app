import XCTest
@testable import PetCore

final class CosmicSolitaireTests: XCTestCase {
    func testADealUsesEveryCardOnce() {
        let deal = SolitaireDeal.deal(seed: 7, drawCount: 1)
        let again = SolitaireDeal.deal(seed: 7, drawCount: 1)
        XCTAssertEqual(deal, again)
        var ids: [Int] = []
        ids += deal.tableau.flatMap { $0.map(\.id) }
        ids += deal.stock.map(\.id)
        XCTAssertEqual(Set(ids).count, 52)
        XCTAssertEqual(deal.tableau[0].count, 1)
        XCTAssertEqual(deal.tableau[6].count, 7)
        XCTAssertTrue(deal.tableau[6].last?.faceUp == true)
        XCTAssertTrue(deal.tableau[6].first?.faceUp == false)
    }

    func testFoundationsTakeAcesThenTheNextRankOnly() {
        let ace = CosmicCard(suit: .star, rank: 1, faceUp: true)
        let two = CosmicCard(suit: .star, rank: 2, faceUp: true)
        let redTwo = CosmicCard(suit: .moon, rank: 2, faceUp: true)
        XCTAssertTrue(SolitaireDeal.fitsFoundation(ace, on: Array(repeating: [], count: 4)))
        var foundations = Array(repeating: [CosmicCard](), count: 4)
        foundations[0] = [ace]
        XCTAssertTrue(SolitaireDeal.fitsFoundation(two, on: foundations))
        XCTAssertFalse(SolitaireDeal.fitsFoundation(redTwo, on: foundations))
    }

    func testTableauWantsTheOppositeColorAndAKingOnEmpty() {
        let redKing = CosmicCard(suit: .star, rank: 13, faceUp: true)
        let blackQueen = CosmicCard(suit: .moon, rank: 12, faceUp: true)
        let redQueen = CosmicCard(suit: .comet, rank: 12, faceUp: true)
        XCTAssertTrue(SolitaireDeal.fitsTableau(redKing, on: []))
        XCTAssertFalse(SolitaireDeal.fitsTableau(blackQueen, on: []))
        XCTAssertTrue(SolitaireDeal.fitsTableau(blackQueen, on: [redKing]))
        XCTAssertFalse(SolitaireDeal.fitsTableau(redQueen, on: [redKing]))
    }

    func testDrawingAndAnIllegalMove() {
        var deal = SolitaireDeal.deal(seed: 3, drawCount: 1)
        let drawn = deal.applying(.draw)
        XCTAssertEqual(drawn?.waste.count, 1)
        XCTAssertEqual(drawn?.stock.count, deal.stock.count - 1)
        deal.waste = [CosmicCard(suit: .moon, rank: 5, faceUp: true)]
        deal.tableau[0] = [CosmicCard(suit: .star, rank: 9, faceUp: true)]
        XCTAssertNil(deal.applying(.wasteToTableau(0)))
        XCTAssertNotNil(deal.hint())
    }

    func testAWonBoardAndStarBudget() {
        var foundations: [[CosmicCard]] = []
        for suit in CosmicCard.Suit.allCases {
            foundations.append((1...13).map { CosmicCard(suit: suit, rank: $0, faceUp: true) })
        }
        let deal = SolitaireDeal(tableau: Array(repeating: [], count: 7), foundations: foundations, stock: [], drawCount: 1)
        XCTAssertTrue(deal.won)
        XCTAssertEqual(CosmicSolitaire.stars(moves: 40, won: true), 3)
        XCTAssertEqual(CosmicSolitaire.stars(moves: 90, won: true), 2)
        XCTAssertEqual(CosmicSolitaire.stars(moves: 10, won: false), 0)
        XCTAssertTrue(CosmicSolitaire.isOpen(level: 1, petLevel: 1, stars: [:]))
        XCTAssertFalse(CosmicSolitaire.isOpen(level: 4, petLevel: 1, stars: [3: 1]))
    }
}
