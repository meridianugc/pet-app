import Foundation

public struct DefenseCritter: Equatable, Identifiable, Sendable {
    public var id: Int
    public var layers: Int
    public var distance: Double
    public var slow: Double

    public init(id: Int, layers: Int, distance: Double = 0, slow: Double = 0) {
        self.id = id
        self.layers = layers
        self.distance = distance
        self.slow = slow
    }

    public var speed: Double {
        let base = max(8, 24 - Double(layers) * 3)
        return slow > 0 ? base * 0.45 : base
    }
}

public enum DefenseTowerKind: String, Codable, CaseIterable, Equatable, Sendable {
    case dart
    case laser
    case frost
    case bomb
    case farm

    public var cost: Int {
        switch self {
        case .dart: return 50
        case .laser: return 90
        case .frost: return 70
        case .bomb: return 120
        case .farm: return 80
        }
    }

    public var title: String {
        switch self {
        case .dart: return "Dart"
        case .laser: return "Laser"
        case .frost: return "Frost"
        case .bomb: return "Bomb"
        case .farm: return "Gem farm"
        }
    }
}

public struct DefenseTower: Equatable, Identifiable, Sendable {
    public var id: Int
    public var kind: DefenseTowerKind
    public var slot: Int
    public var pathA: Int
    public var pathB: Int
    public var cooldown: Double

    public init(id: Int, kind: DefenseTowerKind, slot: Int, pathA: Int = 0, pathB: Int = 0, cooldown: Double = 0) {
        self.id = id
        self.kind = kind
        self.slot = slot
        self.pathA = pathA
        self.pathB = pathB
        self.cooldown = cooldown
    }

    public var damage: Int {
        switch kind {
        case .dart: return 1 + pathA
        case .laser: return 2 + pathA
        case .frost: return 1
        case .bomb: return 1 + pathB
        case .farm: return 0
        }
    }

    public var rangeBonus: Double { Double(pathB) * 6 }
}

public struct DefenseField: Equatable, Sendable {
    public var cash: Int
    public var lives: Int
    public var livesAtStart: Int
    public var round: Int
    public var roundsToWin: Int
    public var critters: [DefenseCritter]
    public var queue: [Int]
    public var towers: [DefenseTower]
    public var nextID: Int
    public var spawnIn: Double
    public var running: Bool
    public var won: Bool
    public var lost: Bool

    public init(
        cash: Int,
        lives: Int,
        livesAtStart: Int,
        round: Int = 1,
        roundsToWin: Int,
        critters: [DefenseCritter] = [],
        queue: [Int] = [],
        towers: [DefenseTower] = [],
        nextID: Int = 1,
        spawnIn: Double = 0.4,
        running: Bool = false,
        won: Bool = false,
        lost: Bool = false
    ) {
        self.cash = cash
        self.lives = lives
        self.livesAtStart = livesAtStart
        self.round = round
        self.roundsToWin = roundsToWin
        self.critters = critters
        self.queue = queue
        self.towers = towers
        self.nextID = nextID
        self.spawnIn = spawnIn
        self.running = running
        self.won = won
        self.lost = lost
    }
}

public struct DefenseLevel: Equatable, Sendable, Identifiable {
    public var id: Int
    public var name: String
    public var rounds: Int
    public var cash: Int
    public var lives: Int
    public var unlockLevel: Int

    public init(id: Int, name: String, rounds: Int, cash: Int, lives: Int, unlockLevel: Int) {
        self.id = id
        self.name = name
        self.rounds = rounds
        self.cash = cash
        self.lives = lives
        self.unlockLevel = unlockLevel
    }
}

public enum StarDefense {
    public static let pathLength = 100.0
    public static let slotCount = 6

    public static let levels: [DefenseLevel] = [
        DefenseLevel(id: 1, name: "Home orbit", rounds: 3, cash: 160, lives: 20, unlockLevel: 1),
        DefenseLevel(id: 2, name: "Dust lane", rounds: 4, cash: 150, lives: 18, unlockLevel: 1),
        DefenseLevel(id: 3, name: "Ring road", rounds: 5, cash: 140, lives: 16, unlockLevel: 2),
        DefenseLevel(id: 4, name: "Comet pass", rounds: 5, cash: 130, lives: 16, unlockLevel: 3),
        DefenseLevel(id: 5, name: "Nebula gate", rounds: 6, cash: 150, lives: 15, unlockLevel: 4),
        DefenseLevel(id: 6, name: "Moon loop", rounds: 6, cash: 140, lives: 14, unlockLevel: 5),
        DefenseLevel(id: 7, name: "Asteroid alley", rounds: 7, cash: 160, lives: 14, unlockLevel: 6),
        DefenseLevel(id: 8, name: "Planet crown", rounds: 8, cash: 180, lives: 12, unlockLevel: 8)
    ]

    public static func field(for level: Int) -> DefenseField {
        let picked = levels.first { $0.id == level } ?? levels[0]
        return DefenseField(cash: picked.cash, lives: picked.lives, livesAtStart: picked.lives, roundsToWin: picked.rounds)
    }

    public static func stars(lives: Int, livesAtStart: Int, won: Bool) -> Int {
        guard won else { return 0 }
        if lives >= livesAtStart { return 3 }
        if lives * 2 >= livesAtStart { return 2 }
        return 1
    }

    /// The next map opens after the previous one earns a star, and the pet is high enough.
    public static func isOpen(level: Int, petLevel: Int, stars: [Int: Int]) -> Bool {
        guard let map = levels.first(where: { $0.id == level }) else { return false }
        guard petLevel >= map.unlockLevel else { return false }
        if level <= 1 { return true }
        return (stars[level - 1] ?? 0) > 0
    }

    public static func covers(slot: Int, distance: Double, bonus: Double = 0) -> Bool {
        let center = (Double(slot) + 0.5) / Double(slotCount) * pathLength
        return abs(distance - center) <= 16 + bonus
    }

    public static func place(_ kind: DefenseTowerKind, slot: Int, on field: DefenseField) -> DefenseField? {
        guard slot >= 0, slot < slotCount, !field.lost, !field.won else { return nil }
        guard !field.towers.contains(where: { $0.slot == slot }) else { return nil }
        guard field.cash >= kind.cost else { return nil }
        var field = field
        field.cash -= kind.cost
        field.towers.append(DefenseTower(id: field.nextID, kind: kind, slot: slot))
        field.nextID += 1
        return field
    }

    public static func upgrade(tower id: Int, pathA: Bool, on field: DefenseField) -> DefenseField? {
        guard let index = field.towers.firstIndex(where: { $0.id == id }) else { return nil }
        var tower = field.towers[index]
        let rank = pathA ? tower.pathA : tower.pathB
        guard rank < 3 else { return nil }
        if pathA, tower.pathB > 0 { return nil }
        if !pathA, tower.pathA > 0 { return nil }
        let price = tower.kind.cost / 2 + rank * 30
        guard field.cash >= price else { return nil }
        if pathA { tower.pathA += 1 } else { tower.pathB += 1 }
        var field = field
        field.cash -= price
        field.towers[index] = tower
        return field
    }

    public static func beginRound(_ field: DefenseField) -> DefenseField {
        guard !field.running, !field.won, !field.lost, field.round <= field.roundsToWin else { return field }
        var field = field
        let count = 6 + field.round * 2
        let layers = min(5, 1 + (field.round - 1) / 2)
        field.queue = Array(repeating: layers, count: count)
        field.spawnIn = 0.35
        field.running = true
        return field
    }

    public static func step(_ field: DefenseField, dt: Double) -> DefenseField {
        guard field.running, !field.won, !field.lost, dt > 0 else { return field }
        var field = field
        field.spawnIn -= dt
        if field.spawnIn <= 0, !field.queue.isEmpty {
            let layers = field.queue.removeFirst()
            field.critters.append(DefenseCritter(id: field.nextID, layers: layers))
            field.nextID += 1
            field.spawnIn = 0.55
        }
        for index in field.critters.indices {
            field.critters[index].slow = max(0, field.critters[index].slow - dt)
            field.critters[index].distance += field.critters[index].speed * dt
        }
        var leaked: [Int] = []
        for critter in field.critters where critter.distance >= pathLength {
            field.lives -= 1
            leaked.append(critter.id)
        }
        field.critters.removeAll { leaked.contains($0.id) }
        if field.lives <= 0 {
            field.lives = 0
            field.lost = true
            field.running = false
            field.critters = []
            return field
        }
        for index in field.towers.indices {
            field.towers[index].cooldown = max(0, field.towers[index].cooldown - dt)
            guard field.towers[index].cooldown <= 0 else { continue }
            let tower = field.towers[index]
            if tower.kind == .farm {
                field.cash += 4 + tower.pathA * 3
                field.towers[index].cooldown = 1.6
                continue
            }
            guard let target = field.critters
                .filter({ covers(slot: tower.slot, distance: $0.distance, bonus: tower.rangeBonus) })
                .max(by: { $0.distance < $1.distance }) else { continue }
            field = strike(tower, target: target.id, field: field)
            if let towerIndex = field.towers.firstIndex(where: { $0.id == tower.id }) {
                let pace = tower.kind == .laser ? 0.28 : (tower.kind == .bomb ? 1.1 : 0.55)
                field.towers[towerIndex].cooldown = max(0.18, pace - Double(tower.pathA) * 0.05)
            }
        }
        if field.queue.isEmpty, field.critters.isEmpty {
            field.running = false
            field.round += 1
            if field.round > field.roundsToWin {
                field.won = true
            }
        }
        return field
    }

    private static func strike(_ tower: DefenseTower, target: Int, field: DefenseField) -> DefenseField {
        var field = field
        guard let index = field.critters.firstIndex(where: { $0.id == target }) else { return field }
        let origin = field.critters[index].distance
        var victims = [index]
        if tower.kind == .bomb {
            victims = field.critters.indices.filter { abs(field.critters[$0].distance - origin) <= 10 }
        }
        for victim in victims {
            var critter = field.critters[victim]
            let popped = min(critter.layers, max(1, tower.damage))
            critter.layers -= popped
            field.cash += popped
            if tower.kind == .frost {
                critter.slow = 1.4 + Double(tower.pathA) * 0.4
            }
            field.critters[victim] = critter
        }
        field.critters.removeAll { $0.layers <= 0 }
        return field
    }
}
