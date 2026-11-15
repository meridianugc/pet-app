import PetCore
import SpriteKit
import SwiftUI
import UIKit

struct StarDefenseGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sound.muted") private var soundMuted = false

    @State private var battle = DefensePlay.start(map: 1, difficulty: .medium)
    @State private var pickedMap: Int?
    @State private var difficulty: DefenseDifficulty = .medium
    @State private var scene = DefenseStage(size: CGSize(width: 390, height: 760))
    @State private var armed: DefenseGunKind?
    @State private var selected: Int?
    @State private var rate = 1
    @State private var autoPlay = false
    @State private var playing = false
    @State private var paused = false
    @State private var bossBanner = false
    @State private var showHowTo = !UserDefaults.standard.bool(forKey: "howto.starDefense")
    @State private var askingLeave = false
    @State private var finale: GameFinale?

    var body: some View {
        ZStack {
            PocketBackground(theme: "bg_hopper").ignoresSafeArea()
            if pickedMap == nil {
                mapList
            } else {
                match
            }
            if askingLeave {
                LeaveGamePrompt(onStay: { askingLeave = false }, onLeave: { finish(won: false) })
            }
            if paused {
                pauseCard
            }
            if bossBanner {
                Text("Boss blob incoming")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(red: 1, green: 0.55, blue: 0.62)))
                    .padding(.top, 70)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }
            if let finale {
                GameEndCard(
                    finale: finale,
                    onAgain: { replay(next: false) },
                    onNext: { replay(next: true) },
                    onShop: {
                        session.openShopAfterGame = true
                        dismiss()
                    },
                    onHome: { dismiss() },
                    extraTitle: battle.won ? "Freeplay" : nil,
                    onExtra: battle.won ? { startFreeplay() } : nil
                )
            }
            if showHowTo {
                HowToOverlay(
                    title: "Star Defense",
                    pages: [
                        "Pick a map and a difficulty. Drag a tower onto the grass. Red means the path is in the way.",
                        "Blobs walk the lane. Big ones split. Armored blobs need rockets. Camo blobs need a detector upgrade.",
                        "Each tower has two upgrade paths. Your pet is the hero: tap Pet blast when the lane gets crowded."
                    ],
                    onDone: {
                        UserDefaults.standard.set(true, forKey: "howto.starDefense")
                        showHowTo = false
                    }
                )
            }
        }
        .onAppear {
            scene.scaleMode = .aspectFit
            scene.petTexture = PetStamp.texture(session: session, mood: .joyful)
        }
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
            if let drop = scene.takeDrop(), let armed {
                if let next = DefensePlay.place(armed, at: drop, petLevel: session.level, in: battle) {
                    battle = next
                    selected = battle.guns.last?.id
                    self.armed = nil
                    scene.arm(nil)
                    PocketSound.shared.tap()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            if let pick = scene.takeSelect() {
                selected = pick
                if pick != nil {
                    armed = nil
                    scene.arm(nil)
                }
            }
            scene.allows = { DefensePlay.canPlace($0, in: battle) }
            guard playing, !paused, finale == nil, pickedMap != nil else { return }
            let wasRunning = battle.running
            let stepped = DefensePlay.step(battle, dt: (1.0 / 60.0) * Double(rate))
            battle = stepped.0
            scene.apply(battle, events: stepped.1, selected: selected)
            react(stepped.1)
            if wasRunning, !battle.running, !battle.won, !battle.lost {
                noteBestRound()
                if autoPlay {
                    battle = DefensePlay.beginRound(battle)
                }
            }
            if battle.won || battle.lost {
                playing = false
                finish(won: battle.won)
            }
        }
    }

    private var mapList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CosmicCloseButton(label: "Leave Star Defense") { dismiss() }
                Text("Star Defense")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Spacer()
                Button("?") { showHowTo = true }
                    .font(.system(.headline, design: .rounded).weight(.bold))
            }
            Picker("Difficulty", selection: $difficulty) {
                ForEach(DefenseDifficulty.allCases, id: \.self) { item in
                    Text(item.rawValue.capitalized).tag(item)
                }
            }
            .pickerStyle(.segmented)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(DefensePlay.maps) { map in
                        let stars = session.record?.progress.bestScores["starDefense.level.\(map.id)"] ?? 0
                        let open = DefensePlay.isOpen(map: map.id, petLevel: session.level, stars: starMap)
                        Button {
                            guard open else { return }
                            battle = DefensePlay.start(map: map.id, difficulty: difficulty)
                            pickedMap = map.id
                            scene.load(DefensePlay.map(map.id))
                            playing = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(map.name)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                Text(map.theme)
                                    .font(.system(.caption, design: .rounded))
                                Text(open ? "Lv \(map.unlockLevel) · \(stars) stars · \(difficulty.rawValue)" : "Locked · Lv \(map.unlockLevel)")
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(open ? 0.7 : 0.3)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!open)
                    }
                }
            }
        }
        .padding(16)
    }

    private var match: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    CosmicCloseButton(label: "Leave Star Defense") {
                        playing = false
                        askingLeave = true
                    }
                    Text(battle.freeplay ? "Freeplay \(battle.round)" : "Round \(min(battle.round, battle.difficulty.authoredRounds))/\(battle.difficulty.authoredRounds)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    Spacer()
                    Button {
                        paused = true
                        playing = false
                    } label: {
                        Image(systemName: "pause.fill")
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.85)))
                    }
                    .accessibilityLabel("Pause")
                }
                SpriteView(scene: scene)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white, lineWidth: 2))
                if let selected, let gun = battle.guns.first(where: { $0.id == selected }) {
                    upgradePanel(gun)
                }
                HStack {
                Button(battle.running ? "In wave" : "Start round") {
                    battle = DefensePlay.beginRound(battle)
                    playing = battle.running
                    PocketSound.shared.tap()
                }
                .disabled(battle.running || battle.won || battle.lost)
                Button(rate == 1 ? "1x" : "\(rate)x") {
                    rate = rate == 1 ? 2 : (rate == 2 ? 3 : 1)
                }
                Button(autoPlay ? "Auto on" : "Auto") { autoPlay.toggle() }
                Button(battle.heroCooldown <= 0 ? "Pet blast" : "Pet \(Int(battle.heroCooldown.rounded()))") {
                    if let blasted = DefensePlay.heroBlast(battle) {
                        battle = blasted.0
                        scene.apply(battle, events: blasted.1, selected: selected)
                        react(blasted.1)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                .disabled(battle.heroCooldown > 0 || !battle.running)
            }
                .font(.system(.caption, design: .rounded).weight(.bold))
                Button("Maps") {
                    playing = false
                    pickedMap = nil
                    armed = nil
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
            }
            .padding(10)
            shopRail
        }
    }

    private var shopRail: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("★ \(battle.cash)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("♥ \(battle.lives)")
                    .font(.system(.headline, design: .rounded).weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(DefenseGunKind.allCases, id: \.self) { kind in
                        let open = session.level >= kind.unlockLevel
                        let affordable = battle.cash >= kind.cost
                        Button {
                            guard open else { return }
                            armed = kind
                            selected = nil
                            scene.arm(kind)
                            PocketSound.shared.tap()
                        } label: {
                            VStack(spacing: 4) {
                                TowerGlyph(kind: kind)
                                    .frame(width: 36, height: 36)
                                    .opacity(open ? 1 : 0.35)
                                Text(open ? "\(kind.cost)" : "Lock")
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .foregroundStyle(affordable || !open ? Color(red: 0.28, green: 0.16, blue: 0.42) : Color(red: 0.85, green: 0.25, blue: 0.35))
                            }
                            .frame(maxWidth: .infinity, minHeight: 74)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(armed == kind ? Color(red: 1, green: 0.86, blue: 0.55) : Color.white.opacity(open ? 0.9 : 0.45))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!open)
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 168)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(.ultraThinMaterial)
        )
    }

    private func upgradePanel(_ gun: DefenseGun) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TowerGlyph(kind: gun.kind).frame(width: 28, height: 28)
                Text(gun.kind.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Spacer()
                Button("Sell \(Int(Double(gun.spent) * 0.7))") {
                    if let next = DefensePlay.sell(gun.id, in: battle) {
                        battle = next
                        selected = nil
                        PocketSound.shared.tap()
                    }
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
            }
            HStack {
                pathColumn(gun, pathA: true, tint: Color(red: 0.35, green: 0.82, blue: 1))
                pathColumn(gun, pathA: false, tint: Color(red: 1, green: 0.45, blue: 0.75))
            }
            HStack {
                ForEach(TowerAim.allCases, id: \.self) { aim in
                    Button(aim.rawValue) {
                        battle = DefensePlay.aim(gun.id, aim, in: battle)
                    }
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(gun.aim == aim ? Color(red: 1, green: 0.86, blue: 0.55) : Color.white.opacity(0.7)))
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }

    private func pathColumn(_ gun: DefenseGun, pathA: Bool, tint: Color) -> some View {
        let rank = pathA ? gun.pathA : gun.pathB
        return VStack(alignment: .leading, spacing: 4) {
            Text(pathA ? "Cyan path" : "Pink path")
                .font(.system(.caption2, design: .rounded).weight(.bold))
            HStack(spacing: 4) {
                ForEach(1..<5, id: \.self) { tier in
                    Circle()
                        .fill(tier <= rank ? tint : Color.white.opacity(0.45))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                }
            }
            Button(trainTitle(gun, pathA: pathA)) {
                if let next = DefensePlay.train(gun.id, pathA: pathA, in: battle) {
                    battle = next
                    PocketSound.shared.match()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .disabled(!DefensePlay.canTrain(gun, pathA: pathA))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pauseCard: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Paused")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Button(soundMuted ? "Sound off" : "Sound on") {
                    soundMuted.toggle()
                    PocketSound.shared.muted = soundMuted
                    if soundMuted { PocketSound.shared.stopTune() }
                }
                Button("Resume") { paused = false }
                Button("Give up") { finish(won: false) }
            }
            .font(.system(.headline, design: .rounded).weight(.bold))
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white))
        }
    }

    private func trainTitle(_ gun: DefenseGun, pathA: Bool) -> String {
        let rank = pathA ? gun.pathA : gun.pathB
        let name = pathA ? "Path A" : "Path B"
        guard DefensePlay.canTrain(gun, pathA: pathA) else { return "\(name) \(rank)" }
        return "\(name) \(rank) · \(DefensePlay.trainCost(gun, pathA: pathA))"
    }

    private func react(_ events: [DefenseEvent]) {
        if events.contains(where: { $0.kind == .boss }) {
            bossBanner = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                bossBanner = false
            }
        }
        if events.contains(where: { $0.kind == .pop }) {
            PocketSound.shared.match()
        } else if events.contains(where: { $0.kind == .shake }) {
            PocketSound.shared.reward()
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    private var starMap: [Int: Int] {
        var map: [Int: Int] = [:]
        for item in DefensePlay.maps {
            map[item.id] = session.record?.progress.bestScores["starDefense.level.\(item.id)"] ?? 0
        }
        return map
    }

    private func finish(won: Bool) {
        guard finale == nil else { return }
        playing = false
        paused = false
        let stars = DefensePlay.stars(lives: battle.lives, livesAtStart: battle.livesAtStart, won: won)
        if let pickedMap {
            session.recordStars(id: "starDefense.level.\(pickedMap)", stars: stars)
            session.recordStars(id: "starDefense.map.\(pickedMap).\(battle.difficulty.rawValue)", stars: stars)
        }
        let points = won ? stars * 60 + battle.round * 3 : max(0, battle.round - 1) * 5
        noteBestRound()
        finale = bankedFinale(
            session: session,
            title: "Star Defense",
            score: points,
            stars: stars,
            detail: won ? "The lane is quiet." : "The blobs got through.",
            gameID: MiniGame.starDefense.rawValue
        )
    }

    private func noteBestRound() {
        guard let pickedMap else { return }
        let reached = battle.won ? max(1, battle.round - 1) : battle.round
        session.recordStars(id: "starDefense.best.\(pickedMap)", stars: reached)
    }

    private func startFreeplay() {
        battle.freeplay = true
        battle.won = false
        finale = nil
        playing = true
        battle = DefensePlay.beginRound(battle)
    }

    private func replay(next: Bool) {
        let current = pickedMap ?? 1
        let following = next ? min(DefensePlay.maps.count, current + 1) : current
        battle = DefensePlay.start(map: following, difficulty: difficulty)
        pickedMap = following
        selected = nil
        armed = nil
        rate = 1
        finale = nil
        scene.load(DefensePlay.map(following))
    }
}

struct TowerGlyph: View {
    var kind: DefenseGunKind

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.35))
            Circle().fill(color).frame(width: 18, height: 18).offset(y: -2)
            Capsule().fill(Color.white).frame(width: 12, height: 4).offset(x: 8)
        }
    }

    private var color: Color {
        switch kind {
        case .dart: return Color(red: 0.45, green: 0.82, blue: 0.55)
        case .laser: return Color(red: 0.98, green: 0.82, blue: 0.28)
        case .bomb: return Color(red: 1, green: 0.55, blue: 0.35)
        case .frost: return Color(red: 0.55, green: 0.82, blue: 0.98)
        case .tack: return Color(red: 1, green: 0.55, blue: 0.75)
        case .sniper: return Color(red: 0.55, green: 0.4, blue: 0.85)
        case .farm: return Color(red: 0.55, green: 0.75, blue: 0.45)
        }
    }
}

final class DefenseStage: SKScene {
    var allows: ((DefensePoint) -> Bool)?
    var petTexture: SKTexture?
    private var pendingDrop: DefensePoint?
    private var pendingSelect: Int??

    func takeDrop() -> DefensePoint? {
        let value = pendingDrop
        pendingDrop = nil
        return value
    }

    func takeSelect() -> Int?? {
        let value = pendingSelect
        pendingSelect = nil
        return value
    }

    private let board = SKNode()
    private let boardSize = CGSize(width: 1000, height: 700)
    private var road: [DefensePoint] = []
    private var blobs: [Int: SKNode] = [:]
    private var guns: [Int: SKNode] = [:]
    private var shots: [Int: SKNode] = [:]
    private var armedKind: DefenseGunKind?
    private let rangeRing = SKShapeNode(circleOfRadius: 40)
    private let ghost = SKShapeNode(circleOfRadius: 16)
    private var shake = 0

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        anchorPoint = .zero
        if board.parent == nil { addChild(board) }
        rangeRing.strokeColor = .white
        rangeRing.lineWidth = 2
        rangeRing.alpha = 0
        rangeRing.zPosition = 8
        ghost.zPosition = 9
        ghost.alpha = 0
        fitBoard()
        if road.isEmpty {
            load(DefensePlay.map(1))
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        fitBoard()
    }

    func load(_ map: DefenseMap) {
        road = map.path
        board.removeAllChildren()
        blobs.removeAll()
        guns.removeAll()
        shots.removeAll()
        fitBoard()
        drawGround(map)
        board.addChild(rangeRing)
        board.addChild(ghost)
        let hero = SKSpriteNode(texture: petTexture, color: UIColor(red: 0.73, green: 0.64, blue: 0.98, alpha: 1), size: CGSize(width: 64, height: 64))
        hero.name = "hero"
        let end = DefensePlay.point(on: map.path, distance: 1)
        hero.position = place(end)
        hero.position.y += 36
        hero.zPosition = 6
        board.addChild(hero)
    }

    private func fitBoard() {
        if board.parent == nil { addChild(board) }
        let sceneSize = size.width > 2 ? size : CGSize(width: 1000, height: 700)
        let scale = min(sceneSize.width / boardSize.width, sceneSize.height / boardSize.height)
        board.setScale(scale)
        board.position = CGPoint(
            x: (sceneSize.width - boardSize.width * scale) / 2,
            y: (sceneSize.height - boardSize.height * scale) / 2
        )
    }

    func arm(_ kind: DefenseGunKind?) {
        armedKind = kind
        ghost.alpha = kind == nil ? 0 : 0.9
        rangeRing.alpha = kind == nil ? 0 : 0.9
        if let kind {
            ghost.fillColor = towerColor(kind)
            let reach = CGFloat(DefensePlay.range(of: DefenseGun(id: 0, kind: kind, x: 0, y: 0))) * boardSize.width
            rangeRing.path = CGPath(ellipseIn: CGRect(x: -reach, y: -reach, width: reach * 2, height: reach * 2), transform: nil)
        }
    }

    func apply(_ battle: DefenseBattle, events: [DefenseEvent], selected: Int?) {
        let aliveBlobs = Set(battle.blobs.map(\.id))
        for id in blobs.keys where !aliveBlobs.contains(id) {
            if let node = blobs[id] {
                node.removeAllActions()
                let bits = node.position
                node.run(.sequence([
                    .group([.scale(to: 1.35, duration: 0.08), .fadeOut(withDuration: 0.16)]),
                    .removeFromParent()
                ]))
                spark(at: bits, color: UIColor(red: 1, green: 0.7, blue: 0.8, alpha: 1))
            }
            blobs[id] = nil
        }
        for blob in battle.blobs {
            let node = blobs[blob.id] ?? makeBlob(blob)
            blobs[blob.id] = node
            let spot = DefensePlay.point(on: road, distance: blob.distance)
            node.position = place(spot)
            let hop = CGFloat(1 + 0.06 * sin(CACurrentMediaTime() * 8 + Double(blob.id)))
            node.setScale((0.75 + CGFloat(blob.layers) * 0.08) * hop)
        }
        let aliveGuns = Set(battle.guns.map(\.id))
        for id in guns.keys where !aliveGuns.contains(id) {
            guns[id]?.removeFromParent()
            guns[id] = nil
        }
        for gun in battle.guns {
            let node = guns[gun.id] ?? makeGun(gun)
            guns[gun.id] = node
            node.position = place(DefensePoint(x: gun.x, y: gun.y))
            node.alpha = selected == gun.id ? 1 : 0.95
            if let target = battle.blobs.max(by: { $0.distance < $1.distance }), let aim = node.childNode(withName: "aim") {
                let spot = place(DefensePlay.point(on: road, distance: target.distance))
                aim.zRotation = atan2(spot.y - node.position.y, spot.x - node.position.x)
            }
            if let badge = node.childNode(withName: "rank") as? SKLabelNode {
                badge.text = "\(gun.pathA)/\(gun.pathB)"
            }
        }
        let aliveShots = Set(battle.shots.map(\.id))
        for id in shots.keys where !aliveShots.contains(id) {
            shots[id]?.removeFromParent()
            shots[id] = nil
        }
        for shot in battle.shots {
            let node = shots[shot.id] ?? makeShot(shot.kind)
            shots[shot.id] = node
            if let blob = battle.blobs.first(where: { $0.id == shot.target }) {
                let spot = place(DefensePlay.point(on: road, distance: blob.distance))
                let origin = place(DefensePoint(x: shot.x, y: shot.y))
                let travel = CGFloat(min(1, max(0, 1 - shot.life)))
                node.position = CGPoint(
                    x: origin.x + (spot.x - origin.x) * travel,
                    y: origin.y + (spot.y - origin.y) * travel
                )
            }
        }
        for event in events where event.kind == .pop {
            spark(at: place(DefensePoint(x: event.x, y: event.y)), color: .white)
        }
        if events.contains(where: { $0.kind == .shake }) {
            shake = 8
        }
        if shake > 0 {
            position = CGPoint(x: CGFloat.random(in: -3...3), y: CGFloat.random(in: -3...3))
            shake -= 1
            if shake == 0 { position = .zero }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard armedKind != nil, let point = touches.first?.location(in: self) else { return }
        let local = board.convert(point, from: self)
        ghost.position = local
        rangeRing.position = local
        let spot = normalized(point)
        let ok = allows?(spot) ?? false
        ghost.fillColor = (ok ? UIColor(red: 0.55, green: 0.9, blue: 0.7, alpha: 0.9) : UIColor(red: 1, green: 0.45, blue: 0.5, alpha: 0.9))
        rangeRing.strokeColor = ghost.fillColor
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        if armedKind != nil {
            let spot = normalized(point)
            if allows?(spot) == true {
                pendingDrop = spot
            }
            ghost.alpha = 0
            rangeRing.alpha = 0
            armedKind = nil
            return
        }
        let hit = guns.first { _, node in
            hypot(node.position.x - point.x, node.position.y - point.y) < 28
        }
        pendingSelect = hit?.key
    }

    private func drawGround(_ map: DefenseMap) {
        let wash = SKSpriteNode(color: themeColor(map.id), size: boardSize)
        wash.anchorPoint = .zero
        wash.zPosition = 0
        wash.name = "ground"
        board.addChild(wash)
        guard map.path.count >= 2 else { return }
        let path = CGMutablePath()
        let first = place(map.path[0])
        path.move(to: first)
        for point in map.path.dropFirst() {
            path.addLine(to: place(point))
        }
        let outer = SKShapeNode(path: path)
        outer.strokeColor = .white
        outer.lineWidth = 28
        outer.lineCap = .round
        outer.name = "ground"
        outer.zPosition = 1
        board.addChild(outer)
        let inner = SKShapeNode(path: path)
        inner.strokeColor = themeColor(map.id).withAlphaComponent(0.85)
        inner.lineWidth = 16
        inner.lineCap = .round
        inner.name = "ground"
        inner.zPosition = 2
        board.addChild(inner)
        for index in 0..<8 {
            let dot = SKShapeNode(circleOfRadius: index.isMultiple(of: 2) ? 7 : 4)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.alpha = 0.7
            dot.position = CGPoint(x: CGFloat(index) * 48 + 20, y: CGFloat((index * 37) % 180) + 40)
            dot.name = "ground"
            dot.zPosition = 1
            board.addChild(dot)
            dot.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.3, duration: 0.8),
                .fadeAlpha(to: 0.8, duration: 0.8)
            ])))
        }
    }

    private func makeBlob(_ blob: Blob) -> SKNode {
        let node = SKNode()
        node.name = "blob"
        node.zPosition = 4
        if let texture = SpriteArt.texture(blobArt(blob.sort)) {
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 36, height: 36)
            node.addChild(sprite)
        } else {
            let tone = blobColor(blob.sort)
            let shadow = SKShapeNode(ellipseOf: CGSize(width: 22, height: 8))
            shadow.fillColor = UIColor(white: 0, alpha: 0.18)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: -10)
            node.addChild(shadow)
            let body = SKShapeNode(ellipseOf: CGSize(width: 18 + CGFloat(min(blob.layers, 6)) * 2, height: 16 + CGFloat(min(blob.layers, 6)) * 1.6))
            body.fillColor = tone
            body.strokeColor = tone.withAlphaComponent(0.65)
            body.lineWidth = 2
            node.addChild(body)
            let shine = SKShapeNode(ellipseOf: CGSize(width: 7, height: 4))
            shine.fillColor = UIColor(white: 1, alpha: 0.55)
            shine.strokeColor = .clear
            shine.position = CGPoint(x: -4, y: 4)
            node.addChild(shine)
            for side in [-1, 1] as [CGFloat] {
                let eye = SKShapeNode(circleOfRadius: 2.2)
                eye.fillColor = UIColor(red: 0.2, green: 0.12, blue: 0.28, alpha: 1)
                eye.strokeColor = .clear
                eye.position = CGPoint(x: side * 4, y: 1)
                node.addChild(eye)
            }
            let nub = SKShapeNode(circleOfRadius: 2)
            nub.fillColor = tone
            nub.strokeColor = .clear
            nub.position = CGPoint(x: 0, y: 12)
            node.addChild(nub)
        }
        board.addChild(node)
        return node
    }

    private func makeGun(_ gun: DefenseGun) -> SKNode {
        let node = SKNode()
        node.name = "gun"
        node.zPosition = 5
        if let texture = SpriteArt.texture(towerArt(gun.kind)) {
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 48, height: 48)
            node.addChild(sprite)
        } else {
            let tone = towerColor(gun.kind)
            let shadow = SKShapeNode(ellipseOf: CGSize(width: 28, height: 10))
            shadow.fillColor = UIColor(white: 0, alpha: 0.18)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: -16)
            node.addChild(shadow)
            let pad = SKShapeNode(circleOfRadius: 16)
            pad.fillColor = tone.withAlphaComponent(0.45)
            pad.strokeColor = tone
            pad.lineWidth = 2
            node.addChild(pad)
            let body = SKShapeNode(circleOfRadius: gun.pathA >= 4 || gun.pathB >= 4 ? 16 : 12)
            body.fillColor = tone
            body.strokeColor = UIColor(white: 1, alpha: 0.85)
            body.lineWidth = 2
            body.position = CGPoint(x: 0, y: 6)
            node.addChild(body)
            let aim = SKNode()
            aim.name = "aim"
            let barrel = SKShapeNode(rectOf: CGSize(width: 16 + CGFloat(gun.pathA) * 2, height: 5), cornerRadius: 2)
            barrel.fillColor = gun.pathB > gun.pathA ? UIColor(red: 1, green: 0.45, blue: 0.75, alpha: 1) : UIColor(red: 0.35, green: 0.82, blue: 1, alpha: 1)
            barrel.strokeColor = .clear
            barrel.position = CGPoint(x: 14, y: 0)
            aim.addChild(barrel)
            aim.position = CGPoint(x: 0, y: 6)
            node.addChild(aim)
            let eye = SKShapeNode(circleOfRadius: 2)
            eye.fillColor = .white
            eye.strokeColor = .clear
            eye.position = CGPoint(x: 4, y: 8)
            node.addChild(eye)
        }
        let badge = SKLabelNode(text: "0/0")
        badge.name = "rank"
        badge.fontName = "AvenirNext-Bold"
        badge.fontSize = 9
        badge.fontColor = UIColor(red: 0.25, green: 0.15, blue: 0.35, alpha: 1)
        badge.position = CGPoint(x: 0, y: -24)
        node.addChild(badge)
        board.addChild(node)
        return node
    }

    private func makeShot(_ kind: DefenseGunKind) -> SKNode {
        let node = SKShapeNode(circleOfRadius: kind == .bomb ? 7 : 4)
        node.name = "shot"
        node.fillColor = kind == .laser ? UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 1) : towerColor(kind)
        node.strokeColor = .white
        node.zPosition = 7
        board.addChild(node)
        return node
    }

    private func spark(at point: CGPoint, color: UIColor) {
        let star = SKShapeNode(circleOfRadius: 5)
        star.fillColor = color
        star.strokeColor = .clear
        star.position = point
        star.zPosition = 8
        board.addChild(star)
        star.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
    }

    private func place(_ point: DefensePoint) -> CGPoint {
        CGPoint(x: point.x * boardSize.width, y: point.y * boardSize.height)
    }

    private func normalized(_ point: CGPoint) -> DefensePoint {
        let local = board.convert(point, from: self)
        return DefensePoint(x: Double(local.x / boardSize.width), y: Double(local.y / boardSize.height))
    }

    private func themeColor(_ id: Int) -> UIColor {
        switch id {
        case 2: return UIColor(red: 0.62, green: 0.55, blue: 0.95, alpha: 1)
        case 3: return UIColor(red: 0.95, green: 0.72, blue: 0.55, alpha: 1)
        case 4: return UIColor(red: 0.55, green: 0.85, blue: 0.72, alpha: 1)
        case 5: return UIColor(red: 0.95, green: 0.7, blue: 0.85, alpha: 1)
        default: return UIColor(red: 0.72, green: 0.78, blue: 0.98, alpha: 1)
        }
    }

    private func towerColor(_ kind: DefenseGunKind) -> UIColor {
        switch kind {
        case .dart: return UIColor(red: 0.98, green: 0.72, blue: 0.45, alpha: 1)
        case .laser: return UIColor(red: 0.55, green: 0.75, blue: 1, alpha: 1)
        case .bomb: return UIColor(red: 0.95, green: 0.45, blue: 0.55, alpha: 1)
        case .frost: return UIColor(red: 0.7, green: 0.9, blue: 0.98, alpha: 1)
        case .tack: return UIColor(red: 0.85, green: 0.7, blue: 1, alpha: 1)
        case .sniper: return UIColor(red: 0.45, green: 0.4, blue: 0.7, alpha: 1)
        case .farm: return UIColor(red: 0.98, green: 0.86, blue: 0.4, alpha: 1)
        }
    }

    private func blobColor(_ sort: BlobSort) -> UIColor {
        switch sort {
        case .fast: return UIColor(red: 0.45, green: 0.85, blue: 0.7, alpha: 1)
        case .armored: return UIColor(red: 0.55, green: 0.5, blue: 0.65, alpha: 1)
        case .camo: return UIColor(red: 0.55, green: 0.7, blue: 0.4, alpha: 1)
        case .regen: return UIColor(red: 0.95, green: 0.55, blue: 0.75, alpha: 1)
        case .boss: return UIColor(red: 0.85, green: 0.35, blue: 0.55, alpha: 1)
        case .plain: return UIColor(red: 1, green: 0.62, blue: 0.7, alpha: 1)
        }
    }

    private func blobArt(_ sort: BlobSort) -> String {
        switch sort {
        case .fast: return GameArt.blobFast
        case .armored: return GameArt.blobArmor
        case .camo: return GameArt.blobCamo
        case .regen: return GameArt.blobRegen
        case .boss: return GameArt.blobBoss
        case .plain: return GameArt.blobPlain
        }
    }

    private func towerArt(_ kind: DefenseGunKind) -> String {
        switch kind {
        case .dart: return GameArt.towerDart
        case .laser: return GameArt.towerLaser
        case .bomb: return GameArt.towerBomb
        case .frost: return GameArt.towerFrost
        case .tack: return GameArt.towerTack
        case .sniper: return GameArt.towerSniper
        case .farm: return GameArt.towerFarm
        }
    }
}
