import Foundation

public enum BlobSort: String, Equatable, Sendable {
    case plain
    case fast
    case armored
    case camo
    case regen
    case boss
}

public enum DefenseGunKind: String, Equatable, CaseIterable, Sendable {
    case dart
    case laser
    case bomb
    case frost
    case tack
    case sniper
    case farm

    public var title: String {
        switch self {
        case .dart: return "Star dart"
        case .laser: return "Laser"
        case .bomb: return "Rocket"
        case .frost: return "Freeze"
        case .tack: return "Burst ring"
        case .sniper: return "Sniper"
        case .farm: return "Gem farm"
        }
    }

    public var cost: Int {
        switch self {
        case .dart: return 90
        case .laser: return 180
        case .bomb: return 220
        case .frost: return 140
        case .tack: return 160
        case .sniper: return 280
        case .farm: return 200
        }
    }

    public var unlockLevel: Int {
        switch self {
        case .dart, .farm: return 1
        case .frost: return 2
        case .bomb: return 3
        case .tack: return 4
        case .laser: return 5
        case .sniper: return 7
        }
    }
}

public enum TowerAim: String, Equatable, CaseIterable, Sendable {
    case first
    case last
    case strong
    case close
}

public enum DefenseDifficulty: String, Equatable, CaseIterable, Sendable {
    case easy
    case medium
    case hard

    public var cash: Int {
        switch self {
        case .easy: return 260
        case .medium: return 200
        case .hard: return 150
        }
    }

    public var lives: Int {
        switch self {
        case .easy: return 200
        case .medium: return 150
        case .hard: return 80
        }
    }

    public var pace: Double {
        switch self {
        case .easy: return 0.85
        case .medium: return 1
        case .hard: return 1.25
        }
    }
}

public struct DefensePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct DefenseMap: Equatable, Identifiable, Sendable {
    public var id: Int
    public var name: String
    public var theme: String
    public var unlockLevel: Int
    public var path: [DefensePoint]

    public init(id: Int, name: String, theme: String, unlockLevel: Int, path: [DefensePoint]) {
        self.id = id
        self.name = name
        self.theme = theme
        self.unlockLevel = unlockLevel
        self.path = path
    }
}

public struct Blob: Equatable, Identifiable, Sendable {
    public var id: Int
    public var sort: BlobSort
    public var layers: Int
    public var cap: Int
    public var distance: Double
    public var regen: Double
    public var chill: Double

    public init(id: Int, sort: BlobSort, layers: Int, cap: Int? = nil, distance: Double = 0, regen: Double = 0, chill: Double = 0) {
        self.id = id
        self.sort = sort
        self.layers = layers
        self.cap = cap ?? layers
        self.distance = distance
        self.regen = regen
        self.chill = chill
    }

    public var speed: Double {
        switch sort {
        case .fast: return 0.16
        case .boss: return 0.045
        case .armored: return 0.07
        default: return 0.09
        }
    }

    public var pace: Double {
        chill > 0 ? speed * 0.4 : speed
    }
}

public struct DefenseGun: Equatable, Identifiable, Sendable {
    public var id: Int
    public var kind: DefenseGunKind
    public var x: Double
    public var y: Double
    public var pathA: Int
    public var pathB: Int
    public var aim: TowerAim
    public var cooldown: Double
    public var spent: Int

    public init(
        id: Int,
        kind: DefenseGunKind,
        x: Double,
        y: Double,
        pathA: Int = 0,
        pathB: Int = 0,
        aim: TowerAim = .first,
        cooldown: Double = 0,
        spent: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
        self.pathA = pathA
        self.pathB = pathB
        self.aim = aim
        self.cooldown = cooldown
        self.spent = spent == 0 ? kind.cost : spent
    }
}

public struct DefenseShot: Equatable, Identifiable, Sendable {
    public var id: Int
    public var kind: DefenseGunKind
    public var x: Double
    public var y: Double
    public var target: Int
    public var life: Double

    public init(id: Int, kind: DefenseGunKind, x: Double, y: Double, target: Int, life: Double) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
        self.target = target
        self.life = life
    }
}

public struct DefenseEvent: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case pop
        case coin
        case shoot
        case leak
        case boss
        case shake
    }

    public var kind: Kind
    public var x: Double
    public var y: Double
    public var amount: Int

    public init(kind: Kind, x: Double, y: Double, amount: Int = 0) {
        self.kind = kind
        self.x = x
        self.y = y
        self.amount = amount
    }
}

public struct DefenseBattle: Equatable, Sendable {
    public static let roundCount = 42

    public var map: Int
    public var difficulty: DefenseDifficulty
    public var cash: Int
    public var lives: Int
    public var livesAtStart: Int
    public var round: Int
    public var blobs: [Blob]
    public var queue: [Blob]
    public var guns: [DefenseGun]
    public var shots: [DefenseShot]
    public var heroCooldown: Double
    public var spawnIn: Double
    public var running: Bool
    public var won: Bool
    public var lost: Bool
    public var bossSoon: Bool
    public var nextID: Int

    public init(
        map: Int,
        difficulty: DefenseDifficulty,
        cash: Int,
        lives: Int,
        livesAtStart: Int,
        round: Int = 1,
        blobs: [Blob] = [],
        queue: [Blob] = [],
        guns: [DefenseGun] = [],
        shots: [DefenseShot] = [],
        heroCooldown: Double = 0,
        spawnIn: Double = 0.4,
        running: Bool = false,
        won: Bool = false,
        lost: Bool = false,
        bossSoon: Bool = false,
        nextID: Int = 1
    ) {
        self.map = map
        self.difficulty = difficulty
        self.cash = cash
        self.lives = lives
        self.livesAtStart = livesAtStart
        self.round = round
        self.blobs = blobs
        self.queue = queue
        self.guns = guns
        self.shots = shots
        self.heroCooldown = heroCooldown
        self.spawnIn = spawnIn
        self.running = running
        self.won = won
        self.lost = lost
        self.bossSoon = bossSoon
        self.nextID = nextID
    }
}

public enum DefensePlay {
    public static let heroWait = 16.0

    public static let maps: [DefenseMap] = [
        DefenseMap(id: 1, name: "Moon garden", theme: "Soft moons and flower craters", unlockLevel: 1, path: curve([
            (0.02, 0.18), (0.28, 0.18), (0.48, 0.42), (0.3, 0.68), (0.62, 0.78), (0.92, 0.55)
        ])),
        DefenseMap(id: 2, name: "Nebula river", theme: "A glowing river of dust", unlockLevel: 3, path: curve([
            (0.08, 0.9), (0.12, 0.55), (0.4, 0.48), (0.42, 0.18), (0.7, 0.28), (0.78, 0.7), (0.96, 0.62)
        ])),
        DefenseMap(id: 3, name: "Asteroid canyon", theme: "Rocks stacked into a canyon", unlockLevel: 6, path: curve([
            (0.05, 0.12), (0.22, 0.12), (0.22, 0.55), (0.55, 0.55), (0.55, 0.22), (0.82, 0.22), (0.82, 0.82)
        ])),
        DefenseMap(id: 4, name: "Comet orchard", theme: "Trees that grow little comets", unlockLevel: 10, path: curve([
            (0.1, 0.15), (0.5, 0.12), (0.86, 0.28), (0.7, 0.55), (0.35, 0.5), (0.18, 0.78), (0.72, 0.88)
        ])),
        DefenseMap(id: 5, name: "Crystal dock", theme: "A pier of pink crystal", unlockLevel: 14, path: curve([
            (0.5, 0.05), (0.5, 0.28), (0.18, 0.4), (0.18, 0.7), (0.55, 0.62), (0.84, 0.78), (0.6, 0.95)
        ]))
    ]

    public static func start(map: Int, difficulty: DefenseDifficulty) -> DefenseBattle {
        DefenseBattle(
            map: map,
            difficulty: difficulty,
            cash: difficulty.cash,
            lives: difficulty.lives,
            livesAtStart: difficulty.lives
        )
    }

    public static func map(_ id: Int) -> DefenseMap {
        maps.first { $0.id == id } ?? maps[0]
    }

    public static func isOpen(map id: Int, petLevel: Int, stars: [Int: Int]) -> Bool {
        guard let map = maps.first(where: { $0.id == id }) else { return false }
        guard petLevel >= map.unlockLevel else { return false }
        if id <= 1 { return true }
        return (stars[id - 1] ?? 0) > 0
    }

    public static func guns(forPetLevel level: Int) -> [DefenseGunKind] {
        DefenseGunKind.allCases.filter { level >= $0.unlockLevel }
    }

    public static func stars(lives: Int, livesAtStart: Int, won: Bool) -> Int {
        guard won, livesAtStart > 0 else { return 0 }
        if lives * 5 >= livesAtStart * 4 { return 3 }
        if lives * 5 >= livesAtStart * 2 { return 2 }
        return 1
    }

    public static func canPlace(_ point: DefensePoint, in battle: DefenseBattle) -> Bool {
        guard point.x > 0.05, point.x < 0.95, point.y > 0.08, point.y < 0.93 else { return false }
        if distance(point, to: map(battle.map).path) < 0.07 { return false }
        if battle.guns.contains(where: { hypot($0.x - point.x, $0.y - point.y) < 0.08 }) { return false }
        return true
    }

    public static func place(_ kind: DefenseGunKind, at point: DefensePoint, petLevel: Int, in battle: DefenseBattle) -> DefenseBattle? {
        guard !battle.won, !battle.lost else { return nil }
        guard petLevel >= kind.unlockLevel, battle.cash >= kind.cost, canPlace(point, in: battle) else { return nil }
        var battle = battle
        battle.cash -= kind.cost
        battle.guns.append(DefenseGun(id: battle.nextID, kind: kind, x: point.x, y: point.y))
        battle.nextID += 1
        return battle
    }

    public static func canTrain(_ gun: DefenseGun, pathA: Bool) -> Bool {
        if pathA {
            if gun.pathA >= 4 { return false }
            if gun.pathB >= 3, gun.pathA >= 2 { return false }
        } else {
            if gun.pathB >= 4 { return false }
            if gun.pathA >= 3, gun.pathB >= 2 { return false }
        }
        return true
    }

    public static func trainCost(_ gun: DefenseGun, pathA: Bool) -> Int {
        let rank = pathA ? gun.pathA : gun.pathB
        return gun.kind.cost / 2 + rank * 45
    }

    public static func train(_ id: Int, pathA: Bool, in battle: DefenseBattle) -> DefenseBattle? {
        guard let index = battle.guns.firstIndex(where: { $0.id == id }) else { return nil }
        let gun = battle.guns[index]
        guard canTrain(gun, pathA: pathA) else { return nil }
        let price = trainCost(gun, pathA: pathA)
        guard battle.cash >= price else { return nil }
        var battle = battle
        battle.cash -= price
        if pathA { battle.guns[index].pathA += 1 } else { battle.guns[index].pathB += 1 }
        battle.guns[index].spent += price
        return battle
    }

    public static func sell(_ id: Int, in battle: DefenseBattle) -> DefenseBattle? {
        guard let index = battle.guns.firstIndex(where: { $0.id == id }) else { return nil }
        var battle = battle
        battle.cash += Int(Double(battle.guns[index].spent) * 0.7)
        battle.guns.remove(at: index)
        return battle
    }

    public static func aim(_ id: Int, _ aim: TowerAim, in battle: DefenseBattle) -> DefenseBattle {
        var battle = battle
        if let index = battle.guns.firstIndex(where: { $0.id == id }) {
            battle.guns[index].aim = aim
        }
        return battle
    }

    public static func beginRound(_ battle: DefenseBattle) -> DefenseBattle {
        guard !battle.running, !battle.won, !battle.lost, battle.round <= DefenseBattle.roundCount else { return battle }
        var battle = battle
        let script = spawns(forRound: battle.round)
        battle.queue = script.enumerated().map { offset, sort in
            let layers = sort == .boss ? 10 + battle.round / 8 : 1 + battle.round / 7
            return Blob(id: -(offset + 1), sort: sort, layers: layers)
        }
        battle.spawnIn = 0.35
        battle.running = true
        battle.bossSoon = script.contains(.boss)
        return battle
    }

    public static func spawns(forRound round: Int) -> [BlobSort] {
        var list: [BlobSort] = []
        let count = min(28, 6 + round)
        for index in 0..<count {
            if round.isMultiple(of: 10), index == 0 {
                list.append(.boss)
            } else if round >= 18, index.isMultiple(of: 7) {
                list.append(.regen)
            } else if round >= 12, index.isMultiple(of: 5) {
                list.append(.armored)
            } else if round >= 8, index.isMultiple(of: 4) {
                list.append(.camo)
            } else if round >= 4, index.isMultiple(of: 3) {
                list.append(.fast)
            } else {
                list.append(.plain)
            }
        }
        return list
    }

    public static func heroBlast(_ battle: DefenseBattle) -> (DefenseBattle, [DefenseEvent])? {
        guard battle.running, battle.heroCooldown <= 0 else { return nil }
        var battle = battle
        battle.heroCooldown = heroWait
        var events: [DefenseEvent] = []
        for index in battle.blobs.indices {
            let popped = battle.blobs[index].sort == .boss ? 4 : 2
            let result = hurt(&battle, index: index, damage: popped, armorOK: true, camoOK: true)
            events.append(contentsOf: result)
        }
        battle.blobs.removeAll { $0.layers <= 0 }
        return (battle, events)
    }

    public static func step(_ battle: DefenseBattle, dt: Double) -> (DefenseBattle, [DefenseEvent]) {
        guard battle.running, !battle.won, !battle.lost, dt > 0 else { return (battle, []) }
        var battle = battle
        var events: [DefenseEvent] = []
        let pace = battle.difficulty.pace
        battle.heroCooldown = max(0, battle.heroCooldown - dt)
        battle.spawnIn -= dt
        let crowded = battle.blobs.contains { $0.distance < 0.03 }
        if battle.spawnIn <= 0, !battle.queue.isEmpty, !crowded {
            var blob = battle.queue.removeFirst()
            blob.id = battle.nextID
            battle.nextID += 1
            if blob.sort == .boss {
                events.append(DefenseEvent(kind: .boss, x: 0.5, y: 0.1, amount: battle.round))
            }
            battle.blobs.append(blob)
            battle.spawnIn = 0.42
            battle.bossSoon = battle.queue.contains { $0.sort == .boss }
        }
        let road = map(battle.map).path
        for index in battle.blobs.indices {
            battle.blobs[index].regen += dt
            if battle.blobs[index].sort == .regen, battle.blobs[index].regen >= 1.6, battle.blobs[index].layers < battle.blobs[index].cap {
                battle.blobs[index].layers += 1
                battle.blobs[index].regen = 0
            }
            battle.blobs[index].chill = max(0, battle.blobs[index].chill - dt)
            battle.blobs[index].distance += battle.blobs[index].pace * pace * dt
        }
        var leaked: [Int] = []
        for blob in battle.blobs where blob.distance >= 1 {
            let spot = point(on: road, distance: 1)
            events.append(DefenseEvent(kind: .leak, x: spot.x, y: spot.y, amount: blob.sort == .boss ? 8 : blob.layers))
            battle.lives -= blob.sort == .boss ? 8 : max(1, blob.layers)
            leaked.append(blob.id)
        }
        battle.blobs.removeAll { leaked.contains($0.id) }
        if battle.lives <= 0 {
            battle.lives = 0
            battle.lost = true
            battle.running = false
            battle.blobs = []
            battle.queue = []
            return (battle, events)
        }
        for index in battle.guns.indices {
            battle.guns[index].cooldown = max(0, battle.guns[index].cooldown - dt)
            let gun = battle.guns[index]
            guard gun.cooldown <= 0, gun.kind != .farm else { continue }
            guard let target = chooseTarget(gun, blobs: battle.blobs, path: road) else { continue }
            let fired = fire(gun, at: target, battle: &battle)
            events.append(contentsOf: fired)
            if let gunIndex = battle.guns.firstIndex(where: { $0.id == gun.id }) {
                battle.guns[gunIndex].cooldown = reload(gun)
            }
        }
        for index in battle.shots.indices {
            battle.shots[index].life -= dt
        }
        battle.shots.removeAll { $0.life <= 0 }
        if battle.queue.isEmpty, battle.blobs.isEmpty {
            battle.running = false
            for index in battle.guns.indices where battle.guns[index].kind == .farm {
                let bonus = 25 + battle.guns[index].pathA * 18 + battle.guns[index].pathB * 8
                battle.cash += bonus
                events.append(DefenseEvent(kind: .coin, x: battle.guns[index].x, y: battle.guns[index].y, amount: bonus))
            }
            battle.round += 1
            if battle.round > DefenseBattle.roundCount {
                battle.won = true
            }
        }
        return (battle, events)
    }

    public static func range(of gun: DefenseGun) -> Double {
        let base: Double
        switch gun.kind {
        case .dart: base = 0.16
        case .laser: base = 0.2
        case .bomb: base = 0.15
        case .frost: base = 0.14
        case .tack: base = 0.1
        case .sniper: base = 0.46
        case .farm: base = 0
        }
        return base + Double(gun.pathB) * 0.025
    }

    public static func seesCamo(_ gun: DefenseGun) -> Bool {
        switch gun.kind {
        case .sniper: return gun.pathA >= 1
        case .dart: return gun.pathB >= 1
        default: return gun.pathB >= 2
        }
    }

    public static func breaksArmor(_ gun: DefenseGun) -> Bool {
        switch gun.kind {
        case .bomb: return true
        case .tack: return gun.pathA >= 3
        case .sniper: return gun.pathB >= 2
        default: return false
        }
    }

    public static func point(on path: [DefensePoint], distance: Double) -> DefensePoint {
        guard path.count >= 2 else { return path.first ?? DefensePoint(x: 0, y: 0) }
        let lengths = segmentLengths(path)
        let total = lengths.reduce(0, +)
        var remain = min(1, max(0, distance)) * total
        for index in 0..<(path.count - 1) {
            let span = lengths[index]
            if remain <= span || index == path.count - 2 {
                let t = span <= 0 ? 0 : remain / span
                let a = path[index]
                let b = path[index + 1]
                return DefensePoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
            remain -= span
        }
        return path[path.count - 1]
    }

    public static func distance(_ point: DefensePoint, to path: [DefensePoint]) -> Double {
        guard path.count >= 2 else { return 1 }
        var best = 1.0
        for index in 0..<(path.count - 1) {
            best = min(best, segmentDistance(point, path[index], path[index + 1]))
        }
        return best
    }

    /// Smooth designer knots into one polyline. The scene draws this same list.
    public static func smooth(_ knots: [DefensePoint], samplesPerSpan: Int = 24) -> [DefensePoint] {
        guard knots.count >= 2 else { return knots }
        var result: [DefensePoint] = []
        for index in 0..<(knots.count - 1) {
            let p0 = knots[max(0, index - 1)]
            let p1 = knots[index]
            let p2 = knots[index + 1]
            let p3 = knots[min(knots.count - 1, index + 2)]
            for step in 0..<samplesPerSpan {
                let t = Double(step) / Double(samplesPerSpan)
                result.append(catmull(p0, p1, p2, p3, t))
            }
        }
        result.append(knots[knots.count - 1])
        return result
    }

    public static func catmull(_ p0: DefensePoint, _ p1: DefensePoint, _ p2: DefensePoint, _ p3: DefensePoint, _ t: Double) -> DefensePoint {
        let t2 = t * t
        let t3 = t2 * t
        func mix(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
            0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
        }
        return DefensePoint(x: mix(p0.x, p1.x, p2.x, p3.x), y: mix(p0.y, p1.y, p2.y, p3.y))
    }

    private static func curve(_ spots: [(Double, Double)]) -> [DefensePoint] {
        smooth(spots.map { DefensePoint(x: $0.0, y: $0.1) })
    }

    private static func segmentLengths(_ path: [DefensePoint]) -> [Double] {
        (0..<(path.count - 1)).map { hypot(path[$0 + 1].x - path[$0].x, path[$0 + 1].y - path[$0].y) }
    }

    private static func segmentDistance(_ point: DefensePoint, _ a: DefensePoint, _ b: DefensePoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = dx * dx + dy * dy
        let t = length <= 0 ? 0 : min(1, max(0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / length))
        return hypot(point.x - (a.x + dx * t), point.y - (a.y + dy * t))
    }

    private static func chooseTarget(_ gun: DefenseGun, blobs: [Blob], path: [DefensePoint]) -> Blob? {
        let here = DefensePoint(x: gun.x, y: gun.y)
        let reach = range(of: gun)
        let seen = blobs.filter { blob in
            if blob.sort == .camo, !seesCamo(gun) { return false }
            if blob.sort == .armored, !breaksArmor(gun) { return false }
            let spot = point(on: path, distance: blob.distance)
            return hypot(spot.x - here.x, spot.y - here.y) <= reach
        }
        switch gun.aim {
        case .first: return seen.max { $0.distance < $1.distance }
        case .last: return seen.min { $0.distance < $1.distance }
        case .strong: return seen.max { $0.layers < $1.layers }
        case .close:
            return seen.min { left, right in
                let a = point(on: path, distance: left.distance)
                let b = point(on: path, distance: right.distance)
                return hypot(a.x - here.x, a.y - here.y) < hypot(b.x - here.x, b.y - here.y)
            }
        }
    }

    private static func reload(_ gun: DefenseGun) -> Double {
        let base: Double
        switch gun.kind {
        case .dart: base = 0.48
        case .laser: base = 0.16
        case .bomb: base = 1.05
        case .frost: base = 0.85
        case .tack: base = 0.72
        case .sniper: base = 1.35
        case .farm: base = 99
        }
        return max(0.12, base - Double(gun.pathA) * 0.04)
    }

    private static func fire(_ gun: DefenseGun, at target: Blob, battle: inout DefenseBattle) -> [DefenseEvent] {
        let road = map(battle.map).path
        let spot = point(on: road, distance: target.distance)
        var events = [DefenseEvent(kind: .shoot, x: gun.x, y: gun.y, amount: target.id)]
        battle.shots.append(DefenseShot(id: battle.nextID, kind: gun.kind, x: gun.x, y: gun.y, target: target.id, life: gun.kind == .laser ? 0.12 : 0.28))
        battle.nextID += 1
        guard let index = battle.blobs.firstIndex(where: { $0.id == target.id }) else { return events }
        let damage = harm(gun)
        let present = Set(battle.blobs.map(\.id))
        if gun.kind == .tack {
            for blobIndex in battle.blobs.indices where present.contains(battle.blobs[blobIndex].id) && battle.blobs[blobIndex].layers > 0 {
                let place = point(on: road, distance: battle.blobs[blobIndex].distance)
                if hypot(place.x - gun.x, place.y - gun.y) <= range(of: gun) {
                    events.append(contentsOf: hurt(&battle, index: blobIndex, damage: damage, armorOK: breaksArmor(gun), camoOK: seesCamo(gun)))
                }
            }
        } else if gun.kind == .bomb {
            events.append(contentsOf: hurt(&battle, index: index, damage: damage, armorOK: true, camoOK: seesCamo(gun)))
            let splash = 0.08 + Double(gun.pathA) * 0.015
            for blobIndex in battle.blobs.indices where present.contains(battle.blobs[blobIndex].id) && battle.blobs[blobIndex].id != target.id && battle.blobs[blobIndex].layers > 0 {
                if abs(battle.blobs[blobIndex].distance - target.distance) <= splash {
                    events.append(contentsOf: hurt(&battle, index: blobIndex, damage: max(1, damage - 1), armorOK: true, camoOK: seesCamo(gun)))
                }
            }
            events.append(DefenseEvent(kind: .shake, x: spot.x, y: spot.y, amount: 1))
        } else {
            events.append(contentsOf: hurt(&battle, index: index, damage: damage, armorOK: breaksArmor(gun), camoOK: seesCamo(gun)))
            if gun.kind == .frost, battle.blobs.indices.contains(index), battle.blobs[index].layers > 0 {
                battle.blobs[index].chill = 1.3 + Double(gun.pathA) * 0.35
            }
        }
        battle.blobs.removeAll { $0.layers <= 0 }
        return events
    }

    private static func harm(_ gun: DefenseGun) -> Int {
        switch gun.kind {
        case .dart: return 1 + gun.pathA
        case .laser: return 2 + gun.pathA
        case .bomb: return 2 + gun.pathA
        case .frost: return 1 + gun.pathB
        case .tack: return 1 + gun.pathA
        case .sniper: return 4 + gun.pathA * 2 + (gun.pathB >= 2 ? 3 : 0)
        case .farm: return 0
        }
    }

    @discardableResult
    private static func hurt(_ battle: inout DefenseBattle, index: Int, damage: Int, armorOK: Bool, camoOK: Bool) -> [DefenseEvent] {
        guard battle.blobs.indices.contains(index), damage > 0, battle.blobs[index].layers > 0 else { return [] }
        var blob = battle.blobs[index]
        if blob.sort == .armored, !armorOK { return [] }
        if blob.sort == .camo, !camoOK { return [] }
        let before = blob.layers
        blob.layers -= damage
        battle.cash += min(before, damage)
        let spot = point(on: map(battle.map).path, distance: blob.distance)
        var events = [
            DefenseEvent(kind: .pop, x: spot.x, y: spot.y, amount: min(before, damage)),
            DefenseEvent(kind: .coin, x: spot.x, y: spot.y, amount: min(before, damage))
        ]
        if blob.layers <= 0 {
            let children = offspring(of: blob, before: before, nextID: &battle.nextID)
            battle.blobs.append(contentsOf: children)
        } else {
            battle.blobs[index] = blob
        }
        if blob.layers <= 0 {
            battle.blobs[index].layers = 0
        }
        return events
    }

    private static func offspring(of blob: Blob, before: Int, nextID: inout Int) -> [Blob] {
        let count: Int
        let layers: Int
        let sort: BlobSort
        if blob.sort == .boss {
            count = 4
            layers = 2
            sort = .plain
        } else if before >= 2 {
            count = 2
            layers = 1
            sort = blob.sort == .armored ? .plain : blob.sort
        } else {
            return []
        }
        return (0..<count).map { offset in
            let child = Blob(id: nextID, sort: sort, layers: layers, distance: max(0, blob.distance - 0.01 * Double(offset)))
            nextID += 1
            return child
        }
    }
}
