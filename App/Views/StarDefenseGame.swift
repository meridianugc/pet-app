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
                    onHome: { dismiss() }
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
            scene.scaleMode = .resizeFill
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
            let stepped = DefensePlay.step(battle, dt: (1.0 / 60.0) * Double(rate))
            battle = stepped.0
            scene.apply(battle, events: stepped.1, selected: selected)
            react(stepped.1)
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
        VStack(spacing: 8) {
            HStack {
                CosmicCloseButton(label: "Leave Star Defense") {
                    playing = false
                    askingLeave = true
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lives \(battle.lives)")
                    Text("Cash \(battle.cash)")
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                Spacer()
                Text("Round \(min(battle.round, DefenseBattle.roundCount))/\(DefenseBattle.roundCount)")
                    .font(.system(.headline, design: .rounded).weight(.bold))
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DefensePlay.guns(forPetLevel: session.level), id: \.self) { kind in
                        Button {
                            armed = kind
                            selected = nil
                            scene.arm(kind)
                            PocketSound.shared.tap()
                        } label: {
                            VStack(spacing: 2) {
                                Text(kind.title)
                                Text("\(kind.cost)")
                            }
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(armed == kind ? Color(red: 1, green: 0.8, blue: 0.45) : Color.white.opacity(0.72)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
        .padding(12)
    }

    private func upgradePanel(_ gun: DefenseGun) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(gun.kind.title) · \(gun.aim.rawValue)")
                .font(.system(.caption, design: .rounded).weight(.bold))
            HStack {
                Button(trainTitle(gun, pathA: true)) {
                    if let next = DefensePlay.train(gun.id, pathA: true, in: battle) {
                        battle = next
                        PocketSound.shared.match()
                    }
                }
                .disabled(!DefensePlay.canTrain(gun, pathA: true))
                Button(trainTitle(gun, pathA: false)) {
                    if let next = DefensePlay.train(gun.id, pathA: false, in: battle) {
                        battle = next
                        PocketSound.shared.match()
                    }
                }
                .disabled(!DefensePlay.canTrain(gun, pathA: false))
            }
            HStack {
                ForEach(TowerAim.allCases, id: \.self) { aim in
                    Button(aim.rawValue) {
                        battle = DefensePlay.aim(gun.id, aim, in: battle)
                    }
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                }
                Spacer()
                Button("Sell") {
                    if let next = DefensePlay.sell(gun.id, in: battle) {
                        battle = next
                        selected = nil
                        PocketSound.shared.tap()
                    }
                }
            }
        }
        .font(.system(.caption2, design: .rounded).weight(.bold))
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.78)))
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
        finale = bankedFinale(
            session: session,
            title: "Star Defense",
            score: points,
            stars: stars,
            detail: won ? "The lane is quiet." : "The blobs got through.",
            gameID: MiniGame.starDefense.rawValue
        )
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
        rangeRing.strokeColor = .white
        rangeRing.lineWidth = 2
        rangeRing.alpha = 0
        rangeRing.zPosition = 8
        ghost.zPosition = 9
        ghost.alpha = 0
        addChild(rangeRing)
        addChild(ghost)
        if road.isEmpty {
            load(DefensePlay.map(1))
        }
    }

    func load(_ map: DefenseMap) {
        road = map.path
        removeChildren(in: children.filter { $0.name == "ground" || $0.name == "hero" })
        blobs.removeAll()
        guns.removeAll()
        shots.removeAll()
        enumerateChildNodes(withName: "blob") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "gun") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "shot") { node, _ in node.removeFromParent() }
        drawGround(map)
        let hero = SKSpriteNode(texture: petTexture, color: UIColor(red: 0.73, green: 0.64, blue: 0.98, alpha: 1), size: CGSize(width: 64, height: 64))
        hero.name = "hero"
        let end = DefensePlay.point(on: map.path, distance: 1)
        hero.position = place(end)
        hero.position.y += 36
        hero.zPosition = 6
        addChild(hero)
    }

    func arm(_ kind: DefenseGunKind?) {
        armedKind = kind
        ghost.alpha = kind == nil ? 0 : 0.9
        rangeRing.alpha = kind == nil ? 0 : 0.9
        if let kind {
            ghost.fillColor = towerColor(kind)
            let reach = CGFloat(DefensePlay.range(of: DefenseGun(id: 0, kind: kind, x: 0, y: 0))) * max(size.width, 1)
            rangeRing.path = CGPath(ellipseIn: CGRect(x: -reach, y: -reach, width: reach * 2, height: reach * 2), transform: nil)
        }
    }

    func apply(_ battle: DefenseBattle, events: [DefenseEvent], selected: Int?) {
        let aliveBlobs = Set(battle.blobs.map(\.id))
        for id in blobs.keys where !aliveBlobs.contains(id) {
            blobs[id]?.removeFromParent()
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
            if let target = battle.blobs.max(by: { $0.distance < $1.distance }) {
                let spot = place(DefensePlay.point(on: road, distance: target.distance))
                node.zRotation = atan2(spot.y - node.position.y, spot.x - node.position.x)
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
        ghost.position = point
        rangeRing.position = point
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
        let wash = SKSpriteNode(color: themeColor(map.id), size: size == .zero ? CGSize(width: 390, height: 760) : size)
        wash.anchorPoint = .zero
        wash.zPosition = 0
        wash.name = "ground"
        addChild(wash)
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
        addChild(outer)
        let inner = SKShapeNode(path: path)
        inner.strokeColor = themeColor(map.id).withAlphaComponent(0.85)
        inner.lineWidth = 16
        inner.lineCap = .round
        inner.name = "ground"
        inner.zPosition = 2
        addChild(inner)
        for index in 0..<8 {
            let dot = SKShapeNode(circleOfRadius: index.isMultiple(of: 2) ? 7 : 4)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.alpha = 0.7
            dot.position = CGPoint(x: CGFloat(index) * 48 + 20, y: CGFloat((index * 37) % 180) + 40)
            dot.name = "ground"
            dot.zPosition = 1
            addChild(dot)
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
            let body = SKShapeNode(circleOfRadius: 12)
            body.fillColor = blobColor(blob.sort)
            body.strokeColor = .white
            body.lineWidth = 2
            node.addChild(body)
            let eye = SKShapeNode(circleOfRadius: 2.5)
            eye.fillColor = UIColor(red: 0.25, green: 0.15, blue: 0.35, alpha: 1)
            eye.strokeColor = .clear
            eye.position = CGPoint(x: 4, y: 3)
            node.addChild(eye)
        }
        addChild(node)
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
            let body = SKShapeNode(circleOfRadius: 15)
            body.fillColor = towerColor(gun.kind)
            body.strokeColor = .white
            body.lineWidth = 2
            node.addChild(body)
            let barrel = SKShapeNode(rectOf: CGSize(width: 18, height: 6), cornerRadius: 3)
            barrel.fillColor = UIColor(white: 1, alpha: 0.9)
            barrel.strokeColor = .clear
            barrel.position = CGPoint(x: 14, y: 0)
            node.addChild(barrel)
        }
        let badge = SKLabelNode(text: "0/0")
        badge.name = "rank"
        badge.fontName = "AvenirNext-Bold"
        badge.fontSize = 9
        badge.fontColor = UIColor(red: 0.25, green: 0.15, blue: 0.35, alpha: 1)
        badge.position = CGPoint(x: 0, y: -24)
        node.addChild(badge)
        addChild(node)
        return node
    }

    private func makeShot(_ kind: DefenseGunKind) -> SKNode {
        let node = SKShapeNode(circleOfRadius: kind == .bomb ? 7 : 4)
        node.name = "shot"
        node.fillColor = kind == .laser ? UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 1) : towerColor(kind)
        node.strokeColor = .white
        node.zPosition = 7
        addChild(node)
        return node
    }

    private func spark(at point: CGPoint, color: UIColor) {
        let star = SKShapeNode(circleOfRadius: 5)
        star.fillColor = color
        star.strokeColor = .clear
        star.position = point
        star.zPosition = 8
        addChild(star)
        star.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
    }

    private func place(_ point: DefensePoint) -> CGPoint {
        CGPoint(x: point.x * max(size.width, 1), y: point.y * max(size.height, 1))
    }

    private func normalized(_ point: CGPoint) -> DefensePoint {
        DefensePoint(x: Double(point.x / max(size.width, 1)), y: Double(point.y / max(size.height, 1)))
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
