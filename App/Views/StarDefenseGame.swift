import PetCore
import SpriteKit
import SwiftUI
import UIKit

enum ScreenshotDemo {
    static var shot: String {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-starDefenseShot") else { return "" }
        let next = index + 1
        if args.indices.contains(next), !args[next].hasPrefix("-") {
            return args[next]
        }
        return "map"
    }

    static var isOn: Bool { !shot.isEmpty }
}

struct StarDefenseGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sound.muted") private var soundMuted = false

    @State private var battle = DefensePlay.start(map: 1, difficulty: .medium)
    @State private var pickedMap: Int?
    @State private var difficulty: DefenseDifficulty = .medium
    @State private var scene = DefenseStage(size: DefenseStage.boardPixelSize)
    @State private var armed: DefenseGunKind?
    @State private var selected: Int?
    @State private var rate = 1
    @State private var autoPlay = false
    @State private var fieldFrame = CGRect.zero
    @State private var cardNudge: CGFloat = 0
    @State private var windowInsets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    @State private var playing = false
    @State private var paused = false
    @State private var bossBanner = false
    @State private var showHowTo = !UserDefaults.standard.bool(forKey: "howto.starDefense") && !ScreenshotDemo.isOn
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
            scene.backgroundColor = UIColor(red: 0.55, green: 0.78, blue: 0.48, alpha: 1)
            scene.petTexture = PetStamp.texture(session: session, mood: .joyful)
        }
        .task { await runScreenshotDemo() }
        .onAppear { PlayOrientation.landscape() }
        .onDisappear { PlayOrientation.portrait() }
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
            scene.allows = { point in
                guard let armed else { return DefensePlay.canPlace(point, in: battle) }
                return battle.cash >= armed.cost && DefensePlay.canPlace(point, in: battle)
            }
            if scene.takeReject() {
                armed = nil
                scene.arm(nil)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.easeOut(duration: 0.08)) { cardNudge = 18 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { cardNudge = 0 }
                }
            }
            guard playing, !paused, finale == nil, pickedMap != nil else { return }
            if scene.bossFreeze > 0 {
                scene.bossFreeze -= 1
                return
            }
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

    private func runScreenshotDemo() async {
        guard ScreenshotDemo.isOn else { return }
        showHowTo = false
        playing = false
        battle = DefensePlay.start(map: 1, difficulty: .easy)
        pickedMap = 1
        scene.load(DefensePlay.map(1))
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let level = max(session.level, 1)
        let path = DefensePlay.map(1).path
        switch ScreenshotDemo.shot {
        case "green":
            let choices = [
                DefensePoint(x: 0.2, y: 0.9),
                DefensePoint(x: 0.55, y: 0.9),
                DefensePoint(x: 0.8, y: 0.12)
            ]
            let grass = choices.first { DefensePlay.canPlace($0, in: battle) } ?? choices[0]
            scene.showPlacementGhost(.dart, at: grass, valid: true)
        case "red":
            let onRoad = DefensePlay.point(on: path, distance: 0.45)
            scene.showPlacementGhost(.dart, at: onRoad, valid: false)
        case "upgrade":
            battle = placeNear(0.4, path: path, level: level, in: battle) ?? battle
            selected = battle.guns.last?.id
            scene.apply(battle, events: [], selected: selected)
        default:
            battle = DefensePlay.beginRound(battle)
            battle = placeNear(0.32, path: path, level: level, in: battle) ?? battle
            battle = placeNear(0.62, path: path, level: level, in: battle) ?? battle
            var frame = battle
            for _ in 0..<360 {
                let next = DefensePlay.step(frame, dt: 1.0 / 60.0).0
                if next.round != battle.round { break }
                frame = next
                let visible = frame.blobs.contains { $0.distance > 0.18 && $0.distance < 0.8 }
                if visible, !frame.shots.isEmpty, frame.guns.count >= 2 { break }
            }
            battle = frame
            selected = nil
            scene.apply(battle, events: [], selected: nil)
        }
    }

    private func placeNear(_ distance: Double, path: [DefensePoint], level: Int, in battle: DefenseBattle) -> DefenseBattle? {
        let mid = DefensePlay.point(on: path, distance: distance)
        let seats = [
            DefensePoint(x: mid.x + 0.12, y: mid.y + 0.1),
            DefensePoint(x: mid.x - 0.12, y: mid.y - 0.08),
            DefensePoint(x: mid.x + 0.08, y: mid.y - 0.12),
            DefensePoint(x: mid.x - 0.08, y: mid.y + 0.12)
        ]
        for spot in seats {
            if let next = DefensePlay.place(.dart, at: spot, petLevel: level, in: battle) {
                return next
            }
        }
        return nil
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
        GeometryReader { geo in
            let side = max(windowInsets.left, windowInsets.right, windowInsets.top)
            let railWidth = max(176, (geo.size.width - side * 2) * 0.25)
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    DefenseCanvas(scene: scene)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            GeometryReader { field in
                                Color.clear.preference(key: FieldFrameKey.self, value: field.frame(in: .named("field")))
                            }
                        )
                        .onPreferenceChange(FieldFrameKey.self) { fieldFrame = $0 }
                    VStack {
                        HStack(spacing: 8) {
                            CosmicCloseButton(label: "Leave Star Defense") {
                                playing = false
                                askingLeave = true
                            }
                            Text(roundTitle)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.08, blue: 0.24))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 40)
                                .background(Capsule().fill(Color.white))
                            Spacer(minLength: 4)
                            Button {
                                paused = true
                                playing = false
                            } label: {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color(red: 0.2, green: 0.1, blue: 0.28))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color.white))
                            }
                            .accessibilityLabel("Pause")
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Spacer()
                            Button {
                                if battle.running {
                                    rate = rate == 1 ? 2 : 1
                                } else {
                                    battle = DefensePlay.beginRound(battle)
                                    playing = battle.running
                                }
                                PocketSound.shared.tap()
                            } label: {
                                Image(systemName: battle.running ? (rate == 1 ? "forward.fill" : "forward.end.fill") : "play.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(Color(red: 0.12, green: 0.28, blue: 0.16))
                                    .frame(width: 64, height: 64)
                                    .background(Circle().fill(Color(red: 0.55, green: 0.9, blue: 0.45)))
                            }
                            .accessibilityLabel(battle.running ? "Fast forward" : "Play")
                            Button {
                                autoPlay.toggle()
                            } label: {
                                Text(autoPlay ? "Auto" : "Auto")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(autoPlay ? Color(red: 0.12, green: 0.28, blue: 0.16) : .white)
                                    .frame(minWidth: 64, minHeight: 44)
                                    .background(Capsule().fill(autoPlay ? Color(red: 0.55, green: 0.9, blue: 0.45) : Color.black.opacity(0.35)))
                            }
                            iconButton("Pet blast", system: "sparkles") {
                                if let blasted = DefensePlay.heroBlast(battle) {
                                    battle = blasted.0
                                    scene.apply(battle, events: blasted.1, selected: selected)
                                    react(blasted.1)
                                }
                            }
                            .disabled(battle.heroCooldown > 0 || !battle.running)
                            iconButton("Maps", system: "map") {
                                playing = false
                                pickedMap = nil
                                armed = nil
                                selected = nil
                            }
                        }
                    }
                    .padding(10)
                    bossBar
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 56)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                shopRail
                    .frame(width: railWidth)
                    .frame(maxHeight: .infinity)
            }
            .padding(.leading, windowInsets.left)
            .padding(.trailing, windowInsets.right)
            .frame(width: geo.size.width, height: geo.size.height)
            .background(WindowInsetReader { insets in
                if insets != windowInsets { windowInsets = insets }
            })
        }
        .ignoresSafeArea()
        .background(Color(red: 0.36, green: 0.62, blue: 0.34).ignoresSafeArea())
        .coordinateSpace(name: "field")
    }

    private var roundTitle: String {
        battle.freeplay ? "Freeplay \(battle.round)" : "Round \(min(battle.round, battle.difficulty.authoredRounds))/\(battle.difficulty.authoredRounds)"
    }

    private func iconButton(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.black.opacity(0.4)))
        }
        .accessibilityLabel(title)
        .buttonStyle(.plain)
    }

    private var bossBar: some View {
        let boss = battle.blobs.first { $0.sort == .boss }
        let name = (boss?.layers ?? 0) > 18 ? "Nebula Queen" : "Moon Mothership"
        let full = max(1, boss?.cap ?? 1)
        return VStack(spacing: 4) {
            if boss != nil {
                Text(name)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color(red: 1, green: 0.45, blue: 0.55))
                            .frame(width: 180 * CGFloat(boss?.layers ?? 0) / CGFloat(full))
                    }
                    .frame(width: 180)
            } else if battle.bossSoon {
                Text("Boss on the way")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(red: 1, green: 0.55, blue: 0.62)))
            }
        }
        .padding(.top, 8)
        .allowsHitTesting(false)
    }

    private var shopRail: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("★ \(battle.cash)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.45))
                Text("♥ \(battle.lives)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let selected, let gun = battle.guns.first(where: { $0.id == selected }) {
                upgradePanel(gun)
            } else {
                shopGrid
            }
        }
        .padding(10)
        .frame(width: 168)
        .frame(maxHeight: .infinity, alignment: .top)
        .offset(x: cardNudge)
        .background(Color(red: 0.14, green: 0.08, blue: 0.24))
    }

    private var shopGrid: some View {
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
                                    .frame(width: 44, height: 44)
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
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8, coordinateSpace: .named("field"))
                                .onChanged { value in
                                    guard open else { return }
                                    let local = CGPoint(x: value.location.x - fieldFrame.minX, y: value.location.y - fieldFrame.minY)
                                    scene.drag(kind, at: local, in: fieldFrame.size, ended: false)
                                }
                                .onEnded { value in
                                    guard open else { return }
                                    let local = CGPoint(x: value.location.x - fieldFrame.minX, y: value.location.y - fieldFrame.minY)
                                    scene.drag(kind, at: local, in: fieldFrame.size, ended: true)
                                }
                        )
                    }
                }
        }
    }

    private func upgradePanel(_ gun: DefenseGun) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TowerGlyph(kind: gun.kind).frame(width: 36, height: 36)
                Text(gun.kind.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            Button("Sell \(Int(Double(gun.spent) * 0.7))") {
                if let next = DefensePlay.sell(gun.id, in: battle) {
                    battle = next
                    selected = nil
                    PocketSound.shared.tap()
                }
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.18, green: 0.08, blue: 0.28))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Capsule().fill(Color.white))
            HStack {
                pathColumn(gun, pathA: true, tint: Color(red: 0.45, green: 0.88, blue: 1))
                pathColumn(gun, pathA: false, tint: Color(red: 1, green: 0.62, blue: 0.82))
            }
            VStack(spacing: 6) {
                ForEach(TowerAim.allCases, id: \.self) { aim in
                    Button(aim.rawValue.capitalized) {
                        battle = DefensePlay.aim(gun.id, aim, in: battle)
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(gun.aim == aim ? Color(red: 0.18, green: 0.08, blue: 0.28) : Color.white)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(
                        Capsule().fill(gun.aim == aim ? Color(red: 1, green: 0.86, blue: 0.55) : Color.white.opacity(0.22))
                    )
                }
            }
            Text("Tap empty grass to close")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }

    private func pathColumn(_ gun: DefenseGun, pathA: Bool, tint: Color) -> some View {
        let rank = pathA ? gun.pathA : gun.pathB
        return VStack(alignment: .leading, spacing: 4) {
            Text(pathA ? "Cyan path" : "Pink path")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                ForEach(1..<5, id: \.self) { tier in
                    Circle()
                        .fill(tier <= rank ? tint : Color.white.opacity(0.28))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                }
            }
            Button(trainTitle(gun, pathA: pathA)) {
                if let next = DefensePlay.train(gun.id, pathA: pathA, in: battle) {
                    battle = next
                    PocketSound.shared.match()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.18, green: 0.08, blue: 0.28))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
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

struct GlorbStyle {
    var key: String
    var wide: CGFloat
    var fill: UIColor
    var eyes: UIColor
    var nub: Bool
}

enum DefenseBake {
    static var cache: [String: SKTexture] = [:]

    static func texture(_ key: String, pixels: CGFloat = 96, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let cached = cache[key] { return cached }
        let side = CGSize(width: pixels, height: pixels)
        let image = UIGraphicsImageRenderer(size: side).image { renderer in
            draw(renderer.cgContext, side)
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    static func glorb(_ ctx: CGContext, side: CGSize, style: GlorbStyle) {
        let rect = CGRect(x: 18, y: 22, width: 60, height: 52)
        ctx.setFillColor(UIColor(white: 0, alpha: 0.16).cgColor)
        ctx.fillEllipse(in: CGRect(x: 24, y: 10, width: 48, height: 14))
        ctx.setFillColor(UIColor(red: 0.15, green: 0.08, blue: 0.22, alpha: 1).cgColor)
        ctx.fillEllipse(in: rect.insetBy(dx: -4, dy: -4))
        ctx.setFillColor(style.fill.cgColor)
        ctx.fillEllipse(in: rect)
        ctx.setStrokeColor(UIColor(white: 1, alpha: 0.9).cgColor)
        ctx.setLineWidth(4)
        ctx.strokeEllipse(in: rect)
        ctx.setFillColor(UIColor(white: 1, alpha: 0.55).cgColor)
        ctx.fillEllipse(in: CGRect(x: 28, y: 52, width: 18, height: 10))
        ctx.setFillColor(style.eyes.cgColor)
        ctx.fillEllipse(in: CGRect(x: 36, y: 42, width: 7, height: 7))
        ctx.fillEllipse(in: CGRect(x: 52, y: 42, width: 7, height: 7))
        if style.nub {
            ctx.setFillColor(style.fill.cgColor)
            ctx.fillEllipse(in: CGRect(x: 44, y: 72, width: 8, height: 8))
        }
    }
}

struct WindowInsetReader: UIViewRepresentable {
    var onChange: (UIEdgeInsets) -> Void

    func makeUIView(context: Context) -> InsetProbe {
        let view = InsetProbe()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: InsetProbe, context: Context) {
        view.onChange = onChange
        view.publish()
    }
}

final class InsetProbe: UIView {
    var onChange: ((UIEdgeInsets) -> Void)?
    private var last = UIEdgeInsets(top: -1, left: 0, bottom: 0, right: 0)

    override func didMoveToWindow() {
        super.didMoveToWindow()
        publish()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        publish()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        publish()
    }

    func publish() {
        guard window != nil else { return }
        let insets = window?.safeAreaInsets ?? .zero
        let present = insets.top > 0 || insets.bottom > 0 || insets.left > 0
        guard present, insets != last else { return }
        last = insets
        DispatchQueue.main.async { [insets] in
            self.onChange?(insets)
        }
    }
}

struct DefenseCanvas: UIViewRepresentable {
    var scene: DefenseStage

    func makeUIView(context: Context) -> DefenseScreen {
        let view = DefenseScreen()
        view.presentScene(scene)
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        scene.scaleMode = .aspectFit
        scene.size = DefenseStage.boardPixelSize
        scene.backgroundColor = UIColor(red: 0.46, green: 0.74, blue: 0.42, alpha: 1)
        view.onLayout = { [weak view] in
            guard let view else { return }
            scene.noteView(view.bounds.size)
        }
        return view
    }

    func updateUIView(_ view: DefenseScreen, context: Context) {
        scene.scaleMode = .aspectFit
        if scene.size != DefenseStage.boardPixelSize {
            scene.size = DefenseStage.boardPixelSize
        }
        scene.noteView(view.bounds.size)
    }
}

final class DefenseScreen: SKView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

struct FieldFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct TowerGlyph: View {
    var kind: DefenseGunKind

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.28))
            Circle().stroke(Color.white, lineWidth: 2)
            Circle().fill(color).frame(width: 18, height: 18)
            mark
        }
    }

    @ViewBuilder
    private var mark: some View {
        switch kind {
        case .dart:
            Capsule().fill(Color.white).frame(width: 18, height: 5).offset(x: 8)
        case .laser:
            Rectangle().fill(Color.white).frame(width: 22, height: 3)
        case .bomb:
            Circle().stroke(Color.white, lineWidth: 3).frame(width: 14, height: 14)
        case .frost:
            Circle().stroke(Color.white, lineWidth: 2).frame(width: 16, height: 16)
        case .tack:
            Capsule().fill(Color.white).frame(width: 16, height: 3).rotationEffect(.degrees(40))
        case .sniper:
            Capsule().fill(Color.white).frame(width: 22, height: 3).offset(x: 6)
        case .farm:
            Circle().fill(Color.white).frame(width: 8, height: 8).offset(y: -6)
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
    static let boardPixelSize = CGSize(width: 1024, height: 576)
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
    private var boardSize = DefenseStage.boardPixelSize
    private var unit: CGFloat = 1
    private var shownMap: DefenseMap?
    private var road: [DefensePoint] = []
    private var blobs: [Int: SKNode] = [:]
    private var guns: [Int: SKNode] = [:]
    private var shots: [Int: SKNode] = [:]
    private var armedKind: DefenseGunKind?
    private let rangeRing = SKShapeNode(circleOfRadius: 40)
    private let ghost = SKNode()
    private let rejectFlash = SKSpriteNode(color: UIColor(red: 1, green: 0.22, blue: 0.28, alpha: 1), size: CGSize(width: 4, height: 4))
    private var pendingReject = false
    private var lastPlaceOK: Bool?
    private var shake = 0
    var bossFreeze = 0

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
        shownMap = map
        road = map.path
        board.removeAllChildren()
        blobs.removeAll()
        guns.removeAll()
        shots.removeAll()
        adoptSceneSize()
        drawGround(map)
        board.addChild(rangeRing)
        board.addChild(ghost)
        rejectFlash.alpha = 0
        rejectFlash.zPosition = 60
        rejectFlash.anchorPoint = CGPoint(x: 0, y: 0)
        board.addChild(rejectFlash)
        let hero = SKSpriteNode(texture: petTexture, color: UIColor(red: 0.73, green: 0.64, blue: 0.98, alpha: 1), size: CGSize(width: 64, height: 64))
        hero.name = "hero"
        let end = DefensePlay.point(on: map.path, distance: 1)
        hero.position = place(end)
        hero.position.y += 36
        hero.zPosition = 6
        board.addChild(hero)
    }

    func noteView(_ viewSize: CGSize) {
        guard viewSize.width > 2, viewSize.height > 2 else { return }
        let fit = min(viewSize.width / Self.boardPixelSize.width, viewSize.height / Self.boardPixelSize.height)
        let next: CGFloat = fit > 0.05 ? 1 / fit : 1
        guard abs(next - unit) > 0.04 else { return }
        unit = next
        guard let shownMap else { return }
        board.children.filter { $0.name == "ground" }.forEach { $0.removeFromParent() }
        drawGround(shownMap)
        if let hero = board.childNode(withName: "hero") as? SKSpriteNode {
            hero.size = CGSize(width: 48 * unit, height: 48 * unit)
        }
    }

    private func adoptSceneSize() {
        if board.parent == nil { addChild(board) }
        size = Self.boardPixelSize
        boardSize = Self.boardPixelSize
        board.setScale(1)
        board.position = .zero
        backgroundColor = UIColor(red: 0.46, green: 0.74, blue: 0.42, alpha: 1)
    }

    private func fitBoard() {
        adoptSceneSize()
    }

    func takeReject() -> Bool {
        let value = pendingReject
        pendingReject = false
        return value
    }

    func drag(_ kind: DefenseGunKind, at local: CGPoint, in viewSize: CGSize, ended: Bool) {
        if armedKind != kind { arm(kind) }
        let lifted = CGPoint(x: local.x, y: local.y - 60)
        let scenePoint = viewToScene(lifted, viewSize: viewSize)
        let boardPoint = board.convert(scenePoint, from: self)
        ghost.position = boardPoint
        ghost.alpha = 0.95
        rangeRing.position = boardPoint
        rangeRing.alpha = 0.95
        let spot = DefensePoint(x: Double(boardPoint.x / boardSize.width), y: Double(boardPoint.y / boardSize.height))
        let ok = allows?(spot) ?? false
        let tint = ok ? UIColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 1) : UIColor(red: 0.95, green: 0.22, blue: 0.28, alpha: 1)
        rangeRing.strokeColor = tint
        rangeRing.fillColor = tint.withAlphaComponent(0.18)
        if lastPlaceOK != ok {
            lastPlaceOK = ok
            UIImpactFeedbackGenerator(style: ok ? .soft : .rigid).impactOccurred()
        }
        guard ended else { return }
        if ok {
            pendingDrop = spot
        } else {
            rejectFlash.size = boardSize
            rejectFlash.position = .zero
            rejectFlash.alpha = 0.42
            rejectFlash.removeAllActions()
            rejectFlash.run(.fadeOut(withDuration: 0.28))
            pendingReject = true
        }
        ghost.alpha = 0
        rangeRing.alpha = 0
        armedKind = nil
        lastPlaceOK = nil
    }

    private func viewToScene(_ local: CGPoint, viewSize: CGSize) -> CGPoint {
        let sceneSize = size.width > 2 ? size : viewSize
        let matches = abs(sceneSize.width - viewSize.width) < 3 && abs(sceneSize.height - viewSize.height) < 3
        if matches {
            return CGPoint(x: local.x, y: viewSize.height - local.y)
        }
        let scale = min(viewSize.width / sceneSize.width, viewSize.height / sceneSize.height)
        let xOff = (viewSize.width - sceneSize.width * scale) / 2
        let yOff = (viewSize.height - sceneSize.height * scale) / 2
        return CGPoint(x: (local.x - xOff) / max(scale, 0.01), y: (viewSize.height - local.y - yOff) / max(scale, 0.01))
    }

    func arm(_ kind: DefenseGunKind?) {
        armedKind = kind
        lastPlaceOK = nil
        ghost.removeAllChildren()
        ghost.alpha = kind == nil ? 0 : 0.95
        rangeRing.alpha = kind == nil ? 0 : 0.9
        rangeRing.fillColor = UIColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 0.18)
        rangeRing.strokeColor = UIColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 1)
        rangeRing.lineWidth = 3
        if let kind {
            let preview = makeGun(DefenseGun(id: -1, kind: kind, x: 0, y: 0))
            preview.removeFromParent()
            preview.childNode(withName: "rank")?.removeFromParent()
            ghost.addChild(preview)
            let reach = DefensePlay.range(of: DefenseGun(id: 0, kind: kind, x: 0, y: 0))
            let radius = CGFloat(reach) * boardSize.width
            rangeRing.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        }
    }

    /// Holds the same drag ghost the finger uses, so a screenshot can show the red or green range.
    func showPlacementGhost(_ kind: DefenseGunKind, at spot: DefensePoint, valid: Bool) {
        arm(kind)
        let boardPoint = CGPoint(x: CGFloat(spot.x) * boardSize.width, y: CGFloat(spot.y) * boardSize.height)
        ghost.position = boardPoint
        ghost.alpha = 0.95
        ghost.zPosition = 80
        rangeRing.position = boardPoint
        rangeRing.alpha = 0.95
        rangeRing.zPosition = 70
        let tint = valid
            ? UIColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 1)
            : UIColor(red: 0.95, green: 0.22, blue: 0.28, alpha: 1)
        rangeRing.strokeColor = tint
        rangeRing.fillColor = tint.withAlphaComponent(0.22)
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
            node.zPosition = 20 + (boardSize.height - node.position.y) * 0.01
            let hop = CGFloat(1 + 0.04 * sin(CACurrentMediaTime() * 8 + Double(blob.id)))
            node.setScale(unit * hop)
            if blob.sort == .fast {
                for index in 0..<3 {
                    node.childNode(withName: "trail\(index)")?.position = CGPoint(x: CGFloat(index + 1) * -6, y: 0)
                }
            }
            if blob.sort == .armored, let plate = node.childNode(withName: "plate") {
                let cracked = blob.cap > 0 ? CGFloat(blob.layers) / CGFloat(blob.cap) : 1
                plate.setScale(max(0.4, cracked))
            }
            if blob.sort == .camo, let stripe = node.childNode(withName: "stripe") {
                stripe.alpha = 0.45 + 0.25 * abs(sin(CACurrentMediaTime() * 2))
            }
            if blob.sort == .regen, let heart = node.childNode(withName: "heart") {
                heart.setScale(1 + 0.15 * abs(sin(CACurrentMediaTime() * 3)))
            }
        }
        let aliveGuns = Set(battle.guns.map(\.id))
        for id in guns.keys where !aliveGuns.contains(id) {
            guns[id]?.removeFromParent()
            guns[id] = nil
        }
        for gun in battle.guns {
            let stamp = "\(gun.pathA)-\(gun.pathB)"
            if (guns[gun.id]?.userData?["stamp"] as? String) != stamp {
                guns[gun.id]?.removeFromParent()
                let fresh = makeGun(gun)
                fresh.userData = ["stamp": stamp]
                guns[gun.id] = fresh
            }
            guard let node = guns[gun.id] else { continue }
            node.position = place(DefensePoint(x: gun.x, y: gun.y))
            node.setScale(unit)
            node.zPosition = 12 + (boardSize.height - node.position.y) * 0.01
            node.alpha = selected == gun.id ? 1 : 0.95
            if let target = battle.blobs.max(by: { $0.distance < $1.distance }), let aim = node.childNode(withName: "aim") {
                let spot = place(DefensePlay.point(on: road, distance: target.distance))
                let desired = atan2(spot.y - node.position.y, spot.x - node.position.x)
                aim.zRotation += (desired - aim.zRotation) * 0.35
            }
            let firing = battle.shots.contains { hypot($0.x - gun.x, $0.y - gun.y) < 0.04 && $0.life > 0.18 }
            if firing, let aim = node.childNode(withName: "aim"), aim.action(forKey: "recoil") == nil {
                aim.run(.sequence([
                    .moveBy(x: -4, y: 0, duration: 0.04),
                    .moveBy(x: 4, y: 0, duration: 0.1)
                ]), withKey: "recoil")
                let flash = SKShapeNode(circleOfRadius: 5)
                flash.fillColor = .white
                flash.strokeColor = .clear
                flash.position = CGPoint(x: 18, y: 0)
                aim.addChild(flash)
                flash.run(.sequence([.fadeOut(withDuration: 0.08), .removeFromParent()]))
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
            node.setScale(unit)
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
        let pops = events.filter { $0.kind == .pop }
        for event in pops {
            spark(at: place(DefensePoint(x: event.x, y: event.y)), color: UIColor(red: 1, green: 0.7, blue: 0.82, alpha: 1))
        }
        let coins = events.filter { $0.kind == .coin && $0.amount > 0 }
        if let first = coins.first {
            let sum = coins.reduce(0) { $0 + $1.amount }
            floatCash(sum, at: place(DefensePoint(x: first.x, y: first.y)))
        }
        if events.contains(where: { $0.kind == .boss }) {
            bossFreeze = 3
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
        let tint = ok ? UIColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 1) : UIColor(red: 0.95, green: 0.22, blue: 0.28, alpha: 1)
        rangeRing.strokeColor = tint
        rangeRing.fillColor = tint.withAlphaComponent(0.18)
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
        let local = board.convert(point, from: self)
        let hit = guns.first { _, node in
            hypot(node.position.x - local.x, node.position.y - local.y) < 36
        }
        pendingSelect = .some(hit?.key)
    }

    private func drawGround(_ map: DefenseMap) {
        let wash = SKSpriteNode(color: meadowColor(map.id), size: boardSize)
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
        let shadow = SKShapeNode(path: path)
        shadow.strokeColor = UIColor(white: 0, alpha: 0.16)
        shadow.lineWidth = 58 * unit
        shadow.lineCap = .round
        shadow.lineJoin = .round
        shadow.position = CGPoint(x: 0, y: -4)
        shadow.name = "ground"
        shadow.zPosition = 1
        board.addChild(shadow)
        let border = SKShapeNode(path: path)
        border.strokeColor = pathBorder(map.id)
        border.lineWidth = 50 * unit
        border.lineCap = .round
        border.lineJoin = .round
        border.name = "ground"
        border.zPosition = 1
        board.addChild(border)
        let fill = SKShapeNode(path: path)
        fill.strokeColor = pathFill(map.id)
        fill.lineWidth = 40 * unit
        fill.lineCap = .round
        fill.lineJoin = .round
        fill.name = "ground"
        fill.zPosition = 2
        board.addChild(fill)
        let highlight = SKShapeNode(path: path)
        highlight.strokeColor = UIColor(white: 1, alpha: 0.22)
        highlight.lineWidth = 14 * unit
        highlight.lineCap = .round
        highlight.name = "ground"
        highlight.zPosition = 2
        board.addChild(highlight)
        addDecor(map.id)
    }

    private func makeBlob(_ blob: Blob) -> SKNode {
        let node = SKNode()
        node.name = "blob"
        let style = glorbStyle(blob)
        let texture = DefenseBake.texture(style.key) { ctx, side in
            DefenseBake.glorb(ctx, side: side, style: style)
        }
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: style.wide, height: style.wide * 0.92)
        node.addChild(sprite)
        if blob.sort == .fast {
            for index in 0..<3 {
                let ghost = SKSpriteNode(texture: texture)
                ghost.size = sprite.size
                ghost.alpha = 0.28 - CGFloat(index) * 0.08
                ghost.name = "trail\(index)"
                ghost.zPosition = -1
                node.addChild(ghost)
            }
        }
        if blob.sort == .armored {
            let plate = SKShapeNode(circleOfRadius: style.wide * 0.28)
            plate.fillColor = UIColor(red: 0.78, green: 0.81, blue: 0.86, alpha: 0.9)
            plate.strokeColor = UIColor(red: 0.53, green: 0.56, blue: 0.64, alpha: 1)
            plate.lineWidth = 2
            plate.name = "plate"
            plate.zPosition = 2
            node.addChild(plate)
        }
        if blob.sort == .camo {
            let stripe = SKShapeNode(rectOf: CGSize(width: style.wide * 0.7, height: 3))
            stripe.fillColor = UIColor(white: 0, alpha: 0.35)
            stripe.strokeColor = .clear
            stripe.zRotation = -0.6
            stripe.name = "stripe"
            node.addChild(stripe)
        }
        if blob.sort == .regen {
            let heart = SKLabelNode(text: "+")
            heart.fontName = "AvenirNext-Bold"
            heart.fontSize = 11
            heart.fontColor = UIColor(red: 0.3, green: 0.75, blue: 0.45, alpha: 1)
            heart.position = CGPoint(x: style.wide * 0.28, y: style.wide * 0.2)
            heart.name = "heart"
            node.addChild(heart)
        }
        board.addChild(node)
        return node
    }

    private func glorbStyle(_ blob: Blob) -> GlorbStyle {
        if blob.sort == .boss {
            let queen = blob.cap > 18
            return GlorbStyle(key: queen ? "queen" : "moth", wide: queen ? 120 : 96, fill: queen ? UIColor(red: 0.55, green: 0.28, blue: 0.7, alpha: 1) : UIColor(red: 0.45, green: 0.55, blue: 0.85, alpha: 1), eyes: .white, nub: true)
        }
        let tier = min(10, max(1, blob.layers))
        let row: (String, UIColor) = switch tier {
        case 1: ("pip", UIColor(red: 0.49, green: 0.88, blue: 0.71, alpha: 1))
        case 2: ("bloop", UIColor(red: 0.43, green: 0.76, blue: 1, alpha: 1))
        case 3: ("zib", UIColor(red: 1, green: 0.83, blue: 0.36, alpha: 1))
        case 4: ("zoom", UIColor(red: 1, green: 0.54, blue: 0.48, alpha: 1))
        case 5: ("dash", UIColor(red: 1, green: 0.48, blue: 0.82, alpha: 1))
        case 6: ("twin", UIColor(red: 0.72, green: 0.61, blue: 1, alpha: 1))
        case 7: ("shade", UIColor(red: 0.24, green: 0.18, blue: 0.36, alpha: 1))
        case 8: ("glint", UIColor(red: 0.97, green: 0.97, blue: 1, alpha: 1))
        case 9: ("prism", UIColor(red: 0.95, green: 0.55, blue: 0.7, alpha: 1))
        default: ("rock", UIColor(red: 0.56, green: 0.61, blue: 0.71, alpha: 1))
        }
        let wide: CGFloat = blob.sort == .boss ? 64 : 26
        return GlorbStyle(key: "\(row.0)-\(blob.sort.rawValue)", wide: wide, fill: row.1, eyes: tier == 7 ? .white : UIColor(red: 0.18, green: 0.1, blue: 0.25, alpha: 1), nub: tier != 10)
    }

    private func addDecor(_ mapID: Int) {
        let pond = SKShapeNode(ellipseOf: CGSize(width: 90 * unit, height: 52 * unit))
        pond.fillColor = UIColor(red: 0.45, green: 0.72, blue: 0.9, alpha: 1)
        pond.strokeColor = UIColor(red: 0.25, green: 0.5, blue: 0.7, alpha: 1)
        pond.lineWidth = 3 * unit
        pond.position = spot(0.22, 0.28)
        pond.zPosition = 3
        pond.name = "ground"
        board.addChild(pond)
        for (x, y) in [(0.12, 0.42), (0.78, 0.72), (0.58, 0.72)] as [(CGFloat, CGFloat)] {
            board.addChild(tree(at: spot(x, y)))
        }
        for (x, y) in [(0.40, 0.74), (0.86, 0.22)] as [(CGFloat, CGFloat)] {
            let rock = SKShapeNode(ellipseOf: CGSize(width: 28 * unit, height: 18 * unit))
            rock.fillColor = UIColor(red: 0.62, green: 0.64, blue: 0.68, alpha: 1)
            rock.strokeColor = UIColor(red: 0.35, green: 0.36, blue: 0.4, alpha: 1)
            rock.lineWidth = 2 * unit
            rock.position = spot(x, y)
            rock.zPosition = 3
            rock.name = "ground"
            board.addChild(rock)
        }
        for (x, y) in [(0.30, 0.62), (0.48, 0.58), (0.70, 0.22), (0.16, 0.18)] as [(CGFloat, CGFloat)] {
            let flower = SKShapeNode(circleOfRadius: 6 * unit)
            flower.fillColor = UIColor(red: 1, green: 0.55, blue: 0.7, alpha: 1)
            flower.strokeColor = .white
            flower.lineWidth = 1.5 * unit
            flower.position = spot(x, y)
            flower.zPosition = 3
            flower.name = "ground"
            let dot = SKShapeNode(circleOfRadius: 2 * unit)
            dot.fillColor = UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1)
            dot.strokeColor = .clear
            flower.addChild(dot)
            board.addChild(flower)
        }
        _ = mapID
    }

    private func tree(at point: CGPoint) -> SKNode {
        let node = SKNode()
        node.position = point
        node.zPosition = 3
        node.name = "ground"
        let trunk = SKShapeNode(rectOf: CGSize(width: 8 * unit, height: 16 * unit), cornerRadius: 2)
        trunk.fillColor = UIColor(red: 0.55, green: 0.36, blue: 0.22, alpha: 1)
        trunk.strokeColor = .clear
        trunk.position = CGPoint(x: 0, y: 4 * unit)
        node.addChild(trunk)
        let crown = SKShapeNode(circleOfRadius: 16 * unit)
        crown.fillColor = UIColor(red: 0.28, green: 0.62, blue: 0.32, alpha: 1)
        crown.strokeColor = UIColor(red: 0.16, green: 0.4, blue: 0.2, alpha: 1)
        crown.lineWidth = 2 * unit
        crown.position = CGPoint(x: 0, y: 20 * unit)
        node.addChild(crown)
        return node
    }

    private func spot(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * boardSize.width, y: y * boardSize.height)
    }

    private func makeGun(_ gun: DefenseGun) -> SKNode {
        let node = SKNode()
        node.name = "gun"
        node.zPosition = 5
        if let texture = SpriteArt.texture(towerArt(gun.kind)) {
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 46, height: 46)
            node.addChild(sprite)
        } else {
            let tone = towerColor(gun.kind)
            let deep = gun.pathA >= 4 || gun.pathB >= 4
            let shadow = SKShapeNode(ellipseOf: CGSize(width: 40, height: 14))
            shadow.fillColor = UIColor(white: 0, alpha: 0.22)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: -20)
            node.addChild(shadow)
            let pad = SKShapeNode(circleOfRadius: deep ? 26 : 22)
            pad.fillColor = tone.withAlphaComponent(0.45)
            pad.strokeColor = tone
            pad.lineWidth = 2
            node.addChild(pad)
            if gun.pathA >= 3 || gun.pathB >= 3 {
                let glow = SKShapeNode(circleOfRadius: deep ? 30 : 26)
                glow.strokeColor = gun.pathB >= 3 ? UIColor(red: 1, green: 0.44, blue: 0.75, alpha: 0.9) : UIColor(red: 0.35, green: 0.85, blue: 1, alpha: 0.9)
                glow.fillColor = .clear
                glow.lineWidth = 3
                node.addChild(glow)
            }
            let body = SKShapeNode(circleOfRadius: deep ? 20 : 18)
            body.fillColor = tone
            body.strokeColor = UIColor(white: 1, alpha: 0.9)
            body.lineWidth = 3
            body.position = CGPoint(x: 0, y: 8)
            node.addChild(body)
            for side in [-1, 1] as [CGFloat] {
                let ear = SKShapeNode(circleOfRadius: 6)
                ear.fillColor = tone
                ear.strokeColor = .white
                ear.lineWidth = 1.5
                ear.position = CGPoint(x: side * 14, y: 22)
                node.addChild(ear)
            }
            if gun.pathA >= 1 {
                let hat = SKShapeNode(circleOfRadius: 5)
                hat.fillColor = UIColor(red: 0.35, green: 0.85, blue: 1, alpha: 1)
                hat.strokeColor = .clear
                hat.position = CGPoint(x: 0, y: deep ? 32 : 28)
                node.addChild(hat)
            }
            if gun.pathB >= 1 {
                for side in [-1, 1] as [CGFloat] {
                    let goggle = SKShapeNode(circleOfRadius: 3)
                    goggle.fillColor = UIColor(red: 1, green: 0.44, blue: 0.75, alpha: 1)
                    goggle.strokeColor = .white
                    goggle.position = CGPoint(x: side * 7, y: 12)
                    node.addChild(goggle)
                }
            }
            if gun.pathB >= 2 {
                let shoulder = SKShapeNode(circleOfRadius: 5)
                shoulder.fillColor = tone
                shoulder.strokeColor = .white
                shoulder.position = CGPoint(x: -12, y: 4)
                node.addChild(shoulder)
            }
            let aim = SKNode()
            aim.name = "aim"
            let barrel = SKShapeNode(rectOf: CGSize(width: 26 + CGFloat(gun.pathA) * 3, height: deep ? 8 : 6), cornerRadius: 3)
            barrel.fillColor = gun.pathB > gun.pathA ? UIColor(red: 1, green: 0.45, blue: 0.75, alpha: 1) : UIColor(red: 0.35, green: 0.82, blue: 1, alpha: 1)
            barrel.strokeColor = .white
            barrel.lineWidth = 1
            barrel.position = CGPoint(x: 22, y: 0)
            aim.addChild(barrel)
            aim.position = CGPoint(x: 0, y: 8)
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
        let node: SKShapeNode
        switch kind {
        case .dart:
            node = SKShapeNode(rectOf: CGSize(width: 12, height: 4), cornerRadius: 2)
        case .laser:
            node = SKShapeNode(rectOf: CGSize(width: 22, height: 3), cornerRadius: 1)
        case .bomb:
            node = SKShapeNode(circleOfRadius: 8)
        case .frost:
            node = SKShapeNode(circleOfRadius: 7)
            node.fillColor = .clear
            node.lineWidth = 2
        case .tack:
            node = SKShapeNode(rectOf: CGSize(width: 10, height: 2), cornerRadius: 1)
        case .sniper:
            node = SKShapeNode(rectOf: CGSize(width: 16, height: 1.5), cornerRadius: 0)
        case .farm:
            node = SKShapeNode(circleOfRadius: 3)
        }
        if kind != .frost {
            node.fillColor = towerColor(kind)
        }
        node.strokeColor = .white
        node.name = "shot"
        node.zPosition = 7
        board.addChild(node)
        return node
    }

    private func pathFill(_ id: Int) -> UIColor {
        switch id {
        case 2: return UIColor(red: 1, green: 0.89, blue: 0.95, alpha: 1)
        case 3: return UIColor(white: 1, alpha: 1)
        case 4: return UIColor(red: 1, green: 0.95, blue: 0.84, alpha: 1)
        case 5: return UIColor(red: 0.3, green: 0.27, blue: 0.5, alpha: 1)
        default: return UIColor(red: 0.96, green: 0.91, blue: 0.76, alpha: 1)
        }
    }

    private func pathBorder(_ id: Int) -> UIColor {
        switch id {
        case 2: return UIColor(red: 0.91, green: 0.7, blue: 0.81, alpha: 1)
        case 3: return UIColor(red: 0.73, green: 0.84, blue: 0.92, alpha: 1)
        case 4: return UIColor(red: 0.91, green: 0.75, blue: 0.6, alpha: 1)
        case 5: return UIColor(red: 0.16, green: 0.15, blue: 0.28, alpha: 1)
        default: return UIColor(red: 0.85, green: 0.75, blue: 0.56, alpha: 1)
        }
    }

    private func floatCash(_ amount: Int, at point: CGPoint) {
        let label = SKLabelNode(text: "+\(amount)")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 16
        label.fontColor = UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1)
        label.position = point
        label.zPosition = 40
        board.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 24, duration: 0.7), .fadeOut(withDuration: 0.7)]),
            .removeFromParent()
        ]))
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
        for index in 0..<7 {
            let bit = SKShapeNode(circleOfRadius: 3)
            bit.fillColor = color
            bit.strokeColor = .clear
            bit.position = point
            bit.zPosition = 8
            board.addChild(bit)
            let angle = CGFloat(index) / 7 * .pi * 2
            bit.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * 28, y: sin(angle) * 28, duration: 0.28),
                    .fadeOut(withDuration: 0.28)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func place(_ point: DefensePoint) -> CGPoint {
        CGPoint(x: point.x * boardSize.width, y: point.y * boardSize.height)
    }

    private func normalized(_ point: CGPoint) -> DefensePoint {
        let local = board.convert(point, from: self)
        return DefensePoint(x: Double(local.x / boardSize.width), y: Double(local.y / boardSize.height))
    }

    private func meadowColor(_ id: Int) -> UIColor {
        switch id {
        case 2: return UIColor(red: 0.45, green: 0.62, blue: 0.78, alpha: 1)
        case 3: return UIColor(red: 0.62, green: 0.7, blue: 0.42, alpha: 1)
        case 4: return UIColor(red: 0.42, green: 0.72, blue: 0.48, alpha: 1)
        case 5: return UIColor(red: 0.28, green: 0.32, blue: 0.55, alpha: 1)
        default: return UIColor(red: 0.46, green: 0.74, blue: 0.42, alpha: 1)
        }
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
