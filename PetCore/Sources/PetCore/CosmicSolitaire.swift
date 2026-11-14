import Foundation

public struct CosmicCard: Equatable, Identifiable, Sendable {
    public enum Suit: Int, CaseIterable, Sendable {
        case star, moon, comet, gem
        public var isRed: Bool { self == .star || self == .comet }
    }

    public var suit: Suit
    public var rank: Int
    public var faceUp: Bool

    public var id: Int { suit.rawValue * 13 + rank }

    public init(suit: Suit, rank: Int, faceUp: Bool) {
        self.suit = suit
        self.rank = rank
        self.faceUp = faceUp
    }
}

public struct SolitaireDeal: Equatable, Sendable {
    public var tableau: [[CosmicCard]]
    public var foundations: [[CosmicCard]]
    public var stock: [CosmicCard]
    public var waste: [CosmicCard]
    public var drawCount: Int

    public init(
        tableau: [[CosmicCard]],
        foundations: [[CosmicCard]] = Array(repeating: [], count: 4),
        stock: [CosmicCard],
        waste: [CosmicCard] = [],
        drawCount: Int
    ) {
        self.tableau = tableau
        self.foundations = foundations
        self.stock = stock
        self.waste = waste
        self.drawCount = drawCount
    }

    public var won: Bool { foundations.allSatisfy { $0.count == 13 } }

    public enum Move: Equatable, Sendable {
        case draw
        case wasteToFoundation
        case wasteToTableau(Int)
        case tableauToFoundation(pile: Int)
        case tableauToTableau(from: Int, to: Int, count: Int)
    }

    public static func shuffledDeck(seed: UInt64) -> [CosmicCard] {
        var deck: [CosmicCard] = []
        for suit in CosmicCard.Suit.allCases {
            for rank in 1...13 {
                deck.append(CosmicCard(suit: suit, rank: rank, faceUp: false))
            }
        }
        var state = seed == 0 ? 1 : seed
        func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1
            return state
        }
        for index in stride(from: deck.count - 1, through: 1, by: -1) {
            deck.swapAt(index, Int(next() % UInt64(index + 1)))
        }
        return deck
    }

    public static func deal(seed: UInt64, drawCount: Int) -> SolitaireDeal {
        var deck = shuffledDeck(seed: seed)
        var tableau: [[CosmicCard]] = []
        for pile in 0..<7 {
            var cards: [CosmicCard] = []
            for cardIndex in 0...pile {
                var card = deck.removeFirst()
                card.faceUp = cardIndex == pile
                cards.append(card)
            }
            tableau.append(cards)
        }
        return SolitaireDeal(tableau: tableau, stock: deck, drawCount: max(1, drawCount))
    }

    public func applying(_ move: Move) -> SolitaireDeal? {
        var deal = self
        switch move {
        case .draw:
            if deal.stock.isEmpty {
                guard !deal.waste.isEmpty else { return nil }
                deal.stock = deal.waste.reversed().map { card in
                    var copy = card
                    copy.faceUp = false
                    return copy
                }
                deal.waste = []
                return deal
            }
            let count = min(deal.drawCount, deal.stock.count)
            for _ in 0..<count {
                var card = deal.stock.removeLast()
                card.faceUp = true
                deal.waste.append(card)
            }
            return deal
        case .wasteToFoundation:
            guard let card = deal.waste.last, Self.fitsFoundation(card, on: deal.foundations) else { return nil }
            deal.waste.removeLast()
            deal.foundations[card.suit.rawValue].append(card)
            return deal
        case let .wasteToTableau(pile):
            guard deal.tableau.indices.contains(pile), let card = deal.waste.last, Self.fitsTableau(card, on: deal.tableau[pile]) else { return nil }
            deal.waste.removeLast()
            deal.tableau[pile].append(card)
            return deal
        case let .tableauToFoundation(pile):
            guard deal.tableau.indices.contains(pile), let card = deal.tableau[pile].last, card.faceUp,
                  Self.fitsFoundation(card, on: deal.foundations) else { return nil }
            deal.tableau[pile].removeLast()
            deal.foundations[card.suit.rawValue].append(card)
            Self.reveal(&deal.tableau[pile])
            return deal
        case let .tableauToTableau(from, to, count):
            guard from != to, deal.tableau.indices.contains(from), deal.tableau.indices.contains(to), count > 0 else { return nil }
            let pile = deal.tableau[from]
            guard pile.count >= count else { return nil }
            let run = Array(pile.suffix(count))
            guard run.allSatisfy(\.faceUp), Self.isRun(run), Self.fitsTableau(run[0], on: deal.tableau[to]) else { return nil }
            deal.tableau[from].removeLast(count)
            deal.tableau[to].append(contentsOf: run)
            Self.reveal(&deal.tableau[from])
            return deal
        }
    }

    public func hint() -> Move? {
        if applying(.wasteToFoundation) != nil { return .wasteToFoundation }
        for pile in tableau.indices where applying(.tableauToFoundation(pile: pile)) != nil {
            return .tableauToFoundation(pile: pile)
        }
        for pile in tableau.indices where applying(.wasteToTableau(pile)) != nil {
            return .wasteToTableau(pile)
        }
        for from in tableau.indices {
            var face = 0
            for card in tableau[from].reversed() {
                if card.faceUp { face += 1 } else { break }
            }
            guard face > 0 else { continue }
            for count in 1...face {
                for to in tableau.indices where applying(.tableauToTableau(from: from, to: to, count: count)) != nil {
                    return .tableauToTableau(from: from, to: to, count: count)
                }
            }
        }
        if applying(.draw) != nil { return .draw }
        return nil
    }

    public var canAutocomplete: Bool {
        stock.isEmpty && tableau.allSatisfy { $0.allSatisfy(\.faceUp) }
    }

    public static func fitsFoundation(_ card: CosmicCard, on foundations: [[CosmicCard]]) -> Bool {
        let pile = foundations[card.suit.rawValue]
        if pile.isEmpty { return card.rank == 1 }
        return pile.last?.rank == card.rank - 1
    }

    public static func fitsTableau(_ card: CosmicCard, on pile: [CosmicCard]) -> Bool {
        guard let top = pile.last else { return card.rank == 13 }
        guard top.faceUp, top.suit.isRed != card.suit.isRed else { return false }
        return top.rank == card.rank + 1
    }

    public static func isRun(_ cards: [CosmicCard]) -> Bool {
        guard cards.count > 1 else { return !cards.isEmpty }
        for index in 1..<cards.count {
            if cards[index - 1].suit.isRed == cards[index].suit.isRed { return false }
            if cards[index - 1].rank != cards[index].rank + 1 { return false }
        }
        return true
    }

    private static func reveal(_ pile: inout [CosmicCard]) {
        guard var top = pile.last, !top.faceUp else { return }
        top.faceUp = true
        pile[pile.count - 1] = top
    }
}

public enum CosmicSolitaire {
    public struct Level: Equatable, Sendable, Identifiable {
        public var id: Int
        public var name: String
        public var seed: UInt64
        public var drawCount: Int
        public var unlockLevel: Int
    }

    public static let levels: [Level] = [
        Level(id: 1, name: "First shuffle", seed: 11, drawCount: 1, unlockLevel: 1),
        Level(id: 2, name: "Quiet stars", seed: 27, drawCount: 1, unlockLevel: 1),
        Level(id: 3, name: "Two moons", seed: 42, drawCount: 1, unlockLevel: 2),
        Level(id: 4, name: "Draw three", seed: 64, drawCount: 3, unlockLevel: 3),
        Level(id: 5, name: "Comet stack", seed: 88, drawCount: 3, unlockLevel: 4),
        Level(id: 6, name: "Gem palace", seed: 101, drawCount: 3, unlockLevel: 5),
        Level(id: 7, name: "Long night", seed: 256, drawCount: 3, unlockLevel: 6),
        Level(id: 8, name: "Crown", seed: 512, drawCount: 3, unlockLevel: 8)
    ]

    public static func isOpen(level: Int, petLevel: Int, stars: [Int: Int]) -> Bool {
        guard let map = levels.first(where: { $0.id == level }) else { return false }
        guard petLevel >= map.unlockLevel else { return false }
        if level <= 1 { return true }
        return (stars[level - 1] ?? 0) > 0
    }

    public static func stars(moves: Int, won: Bool) -> Int {
        guard won else { return 0 }
        if moves <= 60 { return 3 }
        if moves <= 100 { return 2 }
        return 1
    }
}
