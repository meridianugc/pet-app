import PetCore
import SpriteKit
import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var session: PetSession
    @State private var showCollection = false
    @State private var showGames = false
    @State private var showShop = false
    @State private var showToday = false
#if DEBUG
    @State private var showDebug = false
#endif

    var body: some View {
        NavigationStack {
            ScrollView {
                if let pet = session.record?.pet {
                    VStack(alignment: .leading, spacing: 20) {
                        header(pet)
                        creature(pet)
                        Text(PetCopy.statusLine(pet))
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)

                        if pet.stage == .egg {
                            Text(PetCopy.stageLine(pet, now: session.currentDate))
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 12) {
                                StatMeterView(title: "Fed", value: pet.hunger, tint: StatTint.fed)
                                StatMeterView(title: "Happy", value: pet.happiness, tint: StatTint.happy)
                                StatMeterView(title: "Energy", value: pet.energy, tint: StatTint.energy)
                            }
                        }

                        if let note = session.note {
                            Text(note)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel(note)
                        }

                        actions(pet)

                        if shouldAskForReminders {
                            ReminderCard()
                        } else if session.reminderAccess == .denied {
                            deniedReminders
                        }

                        if !session.usesAppGroup {
                            Text("This install saves the pet in the app only, so the home screen widget can't see them. The normal scheme on the Simulator can share the pet with the widget.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(20)
                }
            }
            .background(PocketBackground(theme: session.record?.progress.backgroundID).ignoresSafeArea())
            .navigationTitle("Pocket Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showToday) {
                NavigationStack {
                    TodayView()
                }
            }
            .sheet(isPresented: $showShop) {
                NavigationStack {
                    ShopView()
                }
            }
            .fullScreenCover(isPresented: $showGames) {
                GamePicker(best: session.record?.progress.bestScores ?? [:])
            }
            .sheet(isPresented: $showCollection) {
                NavigationStack {
                    CollectionBookView()
                }
            }
#if DEBUG
            .sheet(isPresented: $showDebug) {
                NavigationStack {
                    DebugMenuView()
                }
            }
#endif
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                session.refresh(includeAlreadyLow: false)
            }
        }
    }

    private var shouldAskForReminders: Bool {
        session.reminderAccess == .notAsked && session.record?.notificationPromptDismissed != true
    }

    private func header(_ pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pet.name)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(PetCopy.stageLine(pet, now: session.currentDate))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Level \(session.level) · \(session.record?.progress.coins ?? 0) coins")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func creature(_ pet: Pet) -> some View {
        PetCreatureView(
            stage: pet.stage,
            mood: PetMood.resolve(pet),
            form: pet.displayForm,
            tint: pet.trait?.tint,
            outfit: session.record?.progress.outfitID,
            accessibilityLabel: PetCopy.summary(pet, now: session.currentDate)
        )
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity)
    }

    private func actions(_ pet: Pet) -> some View {
        VStack(spacing: 10) {
            careButton(
                title: "Feed",
                systemImage: "fork.knife",
                hint: "Gives a meal. A very full pet may not enjoy extra food.",
                disabled: !canCare(pet)
            ) {
                session.feed()
            }
            careButton(
                title: "Play",
                systemImage: "gamecontroller.fill",
                hint: playHint(pet),
                disabled: !canPlay(pet)
            ) {
                showGames = true
            }
            careButton(
                title: pet.isSleeping ? "Wake" : "Sleep",
                systemImage: pet.isSleeping ? "sun.max.fill" : "moon.fill",
                hint: pet.isSleeping ? "Wakes the pet up." : "Lets the pet rest and regain energy.",
                disabled: pet.stage == .egg
            ) {
                session.toggleSleep()
            }
            careButton(
                title: "Today",
                systemImage: "sun.max",
                hint: "Daily tasks, your streak, and achievements.",
                disabled: false
            ) {
                showToday = true
            }
            careButton(
                title: "Shop",
                systemImage: "bag",
                hint: "Spend coins on food, toys, outfits, and skies.",
                disabled: false
            ) {
                showShop = true
            }
            if pet.stage != .egg, !pet.isSleeping, pet.energy < 15 {
                Text("Too tired to play. A nap will help.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func careButton(
        title: String,
        systemImage: String,
        hint: String,
        disabled: Bool,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(PocketButton.tint)
        .disabled(disabled)
        .accessibilityHint(hint)
    }

    private func canCare(_ pet: Pet) -> Bool {
        pet.stage != .egg && !pet.isSleeping && !pet.hasGoneHome
    }

    private func canPlay(_ pet: Pet) -> Bool {
        canCare(pet) && pet.energy >= 15
    }

    private func playHint(_ pet: Pet) -> String {
        if pet.energy < 15, pet.stage != .egg, !pet.isSleeping {
            return "Unavailable until they have more energy."
        }
        return "Cheers them up and uses some energy."
    }

    private var deniedReminders: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminders are off, so Pocket Pet can't nudge you when they need you.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .accessibilityHint("Opens the iPhone Settings app.")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showCollection = true
            } label: {
                Image(systemName: "sparkles")
            }
            .accessibilityLabel("Collection")
            .accessibilityHint("Shows the forms you have raised and the letters left behind.")
        }
        if session.reminderAccess == .notAsked {
            ToolbarItem(placement: .topBarLeading) {
                Button("Reminders") {
                    Task { @MainActor in
                        await session.allowReminders()
                    }
                }
                .accessibilityHint("Asks to send reminders when the pet needs you.")
            }
        }
        if session.reminderAccess == .denied {
            ToolbarItem(placement: .topBarLeading) {
                Button("Reminders") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .accessibilityHint("Opens Settings so you can allow reminders.")
            }
        }
#if DEBUG
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showDebug = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Debug menu")
            .accessibilityHint("Moves the pet's clock for testing.")
        }
#endif
    }
}

struct CollectionBookView: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let collection = session.record?.collection ?? .empty
        List {
            Section("Forms") {
                formRow(title: "Star egg", found: collection.sawEgg, stage: .egg, form: nil)
                formRow(title: "Baby", found: collection.sawBaby, stage: .baby, form: nil)
                formRow(title: "Star", found: collection.raisedForms.contains(.star), stage: .adult, form: .star)
                formRow(title: "Cloud", found: collection.raisedForms.contains(.cloud), stage: .adult, form: .cloud)
                formRow(title: "Spiky", found: collection.raisedForms.contains(.spiky), stage: .adult, form: .spiky)
            }
            Section("Letters") {
                if collection.letters.isEmpty {
                    Text("When an alien flies home, their letter will stay here.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(collection.letters) { letter in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(letter.name)
                                .font(.headline)
                            Text(letter.form?.displayName ?? "Hatchling")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(letter.message)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .navigationTitle("Star book")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func formRow(title: String, found: Bool, stage: LifeStage, form: AdultForm?) -> some View {
        HStack(spacing: 12) {
            PetCreatureView(
                stage: stage,
                mood: found ? .joyful : .sleepy,
                form: form,
                animates: false,
                accessibilityLabel: found ? title : "\(title), not yet"
            )
            .frame(width: 56, height: 56)
            .opacity(found ? 1 : 0.35)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(found ? "Raised" : "Not yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension MiniGame: Identifiable {
    public var id: String { rawValue }
}

struct GamePicker: View {
    var best: [String: Int]
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var planet = false

    var body: some View {
        ZStack {
            PocketBackground().ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Text("Play")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .accessibilityLabel("Close games")
                }
                gameCard(
                    title: "Planet Merge",
                    blurb: "Drop planets. Twins become one bigger world.",
                    score: best[MiniGame.planetMerge.rawValue] ?? 0,
                    colors: [Color(red: 0.98, green: 0.75, blue: 0.55), Color(red: 0.62, green: 0.55, blue: 0.95)]
                ) {
                    planet = true
                }
                .offset(y: appeared ? 0 : 40)
                .opacity(appeared ? 1 : 0)
            }
            .padding(20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .fullScreenCover(isPresented: $planet) {
            PlanetMergeGame()
        }
    }

    private func gameCard(title: String, blurb: String, score: Int, colors: [Color], play: @escaping () -> Void) -> some View {
        Button(action: play) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(colors[0]).frame(width: 54, height: 54)
                    Circle().fill(colors[1]).frame(width: 34, height: 34).offset(x: 16, y: 10)
                }
                .frame(width: 84, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text(blurb)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(score > 0 ? "Best \(score)" : "No score yet")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white, lineWidth: 2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(score > 0 ? "Best score \(score)" : "No score yet")")
    }
}

final class PlanetMergeScene: SKScene, SKPhysicsContactDelegate {
    var onScore: ((Int) -> Void)?
    var onEnd: ((Int) -> Void)?
    private var score = 0
    private var combo = 0
    private var lastMerge: TimeInterval = 0
    private var current = 0
    private var upcoming = 1
    private var ready = true
    private var ended = false
    private var danger: TimeInterval = 0
    private let palette: [SKColor] = [
        SKColor(red: 1, green: 0.78, blue: 0.55, alpha: 1),
        SKColor(red: 1, green: 0.62, blue: 0.72, alpha: 1),
        SKColor(red: 0.72, green: 0.62, blue: 0.98, alpha: 1),
        SKColor(red: 0.55, green: 0.78, blue: 1, alpha: 1),
        SKColor(red: 0.62, green: 0.88, blue: 0.72, alpha: 1),
        SKColor(red: 0.95, green: 0.85, blue: 0.45, alpha: 1),
        SKColor(red: 0.55, green: 0.45, blue: 0.85, alpha: 1)
    ]

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.14, green: 0.11, blue: 0.26, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -3.6)
        physicsWorld.contactDelegate = self
        let bin = CGRect(x: 16, y: 12, width: size.width - 32, height: 20)
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 16, y: 12, width: size.width - 32, height: size.height))
        let floor = SKNode()
        floor.physicsBody = SKPhysicsBody(edgeLoopFrom: bin)
        addChild(floor)
        let line = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 3))
        line.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        line.strokeColor = SKColor(white: 1, alpha: 0.45)
        line.name = "line"
        addChild(line)
        current = Int.random(in: 0...2)
        upcoming = Int.random(in: 0...2)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let x = touches.first?.location(in: self).x else { return }
        drop(at: x)
    }

    private func drop(at x: CGFloat) {
        guard ready, !ended else { return }
        ready = false
        let node = planet(sizeIndex: current)
        let radius = node.frame.width / 2
        let clamped = min(size.width - 24 - radius, max(24 + radius, x))
        node.position = CGPoint(x: clamped, y: size.height - radius - 8)
        addChild(node)
        current = upcoming
        upcoming = Int.random(in: 0...2)
        run(.sequence([.wait(forDuration: 0.4), .run { [weak self] in self?.ready = true }]))
    }

    private func planet(sizeIndex: Int) -> SKShapeNode {
        let radius = CGFloat(PlanetMerge.radius(for: sizeIndex))
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = palette[sizeIndex % palette.count]
        node.strokeColor = SKColor(white: 1, alpha: 0.7)
        node.lineWidth = 3
        node.name = "planet"
        node.userData = ["size": sizeIndex]
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.restitution = 0.05
        body.friction = 0.4
        body.categoryBitMask = 1
        body.collisionBitMask = 1
        body.contactTestBitMask = 1
        node.physicsBody = body
        return node
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let nodes = [contact.bodyA.node, contact.bodyB.node].compactMap { $0 }
        guard nodes.count == 2,
              nodes.allSatisfy({ $0.name == "planet" && $0.parent != nil }),
              let first = sizeOf(nodes[0]),
              let second = sizeOf(nodes[1]),
              first == second,
              let next = PlanetMerge.nextSize(after: first) else { return }
        nodes.forEach { $0.removeFromParent() }
        let merged = planet(sizeIndex: next)
        merged.position = CGPoint(
            x: (nodes[0].position.x + nodes[1].position.x) / 2,
            y: (nodes[0].position.y + nodes[1].position.y) / 2
        )
        addChild(merged)
        let now = CACurrentMediaTime()
        combo = now - lastMerge < 0.9 ? combo + 1 : 1
        lastMerge = now
        score += PlanetMerge.points(forMerging: first, combo: combo)
        onScore?(score)
        UIImpactFeedbackGenerator(style: combo > 1 ? .medium : .light).impactOccurred()
        let pop = SKLabelNode(text: combo > 1 ? "Combo \(combo)" : "+\(PlanetMerge.points(forMerging: first, combo: 1))")
        pop.fontName = "AvenirNext-Bold"
        pop.fontSize = 18
        pop.fontColor = .white
        pop.position = merged.position
        addChild(pop)
        pop.run(.sequence([.moveBy(x: 0, y: 30, duration: 0.4), .fadeOut(withDuration: 0.2), .removeFromParent()]))
        burst(at: merged.position)
    }

    override func update(_ currentTime: TimeInterval) {
        guard !ended else { return }
        let limit = size.height * 0.78
        let crowded = children.contains { node in
            guard node.name == "planet", let body = node.physicsBody else { return false }
            return node.position.y > limit && hypot(body.velocity.dx, body.velocity.dy) < 12
        }
        if crowded {
            danger += 1.0 / 60.0
            if danger > 1.1 { end() }
        } else {
            danger = 0
        }
    }

    private func end() {
        ended = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        onEnd?(score)
    }

    private func sizeOf(_ node: SKNode) -> Int? {
        (node.userData?["size"] as? NSNumber)?.intValue ?? node.userData?["size"] as? Int
    }

    private func burst(at point: CGPoint) {
        let spark = SKEmitterNode()
        let dot = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        spark.particleTexture = SKTexture(image: dot)
        spark.particleBirthRate = 80
        spark.numParticlesToEmit = 16
        spark.particleLifetime = 0.35
        spark.particleSpeed = 90
        spark.particleScale = 0.4
        spark.particleColor = .white
        spark.particleAlphaSpeed = -2
        spark.position = point
        addChild(spark)
        spark.run(.sequence([.wait(forDuration: 0.4), .removeFromParent()]))
    }
}

struct PlanetMergeGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var scene: PlanetMergeScene = {
        let scene = PlanetMergeScene(size: CGSize(width: 390, height: 740))
        scene.scaleMode = .resizeFill
        return scene
    }()
    @State private var score = 0
    @State private var closed = false

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            Text("\(score)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 24)
                .accessibilityLabel("Score \(score)")
        }
        .onAppear {
            scene.onScore = { value in
                Task { @MainActor in score = value }
            }
            scene.onEnd = { final in
                Task { @MainActor in
                    guard !closed else { return }
                    closed = true
                    session.finishGame(points: final, gameID: MiniGame.planetMerge.rawValue, title: "Planet Merge")
                    dismiss()
                }
            }
        }
    }
}

private struct FallingBit: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var kind: Kind

    enum Kind {
        case star, snack, rock
    }
}

struct StarCatchGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var player: CGFloat = 0.5
    @State private var bits: [FallingBit] = []
    @State private var stars = 0
    @State private var snacks = 0
    @State private var rocks = 0
    @State private var secondsLeft = 40
    @State private var finished = false

    var body: some View {
        VStack(spacing: 12) {
            Text("\(secondsLeft)s · \(GameRewards.starCatchPoints(stars: stars, snacks: snacks, rocks: rocks)) points")
                .font(.headline)
                .accessibilityLabel("\(secondsLeft) seconds left")
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.25))
                    ForEach(bits) { bit in
                        bitView(bit.kind)
                            .position(x: bit.x * width, y: bit.y * geo.size.height)
                    }
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.62, green: 0.50, blue: 0.95))
                        .frame(width: 64, height: 18)
                        .position(x: player * width, y: geo.size.height - 24)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            player = min(0.92, max(0.08, value.location.x / max(width, 1)))
                        }
                )
                .accessibilityLabel("Catch field. Drag to move the basket.")
            }
            .frame(height: 320)
        }
        .padding()
        .background(PocketBackground().ignoresSafeArea())
        .navigationTitle("Star Catch")
        .navigationBarTitleDisplayMode(.inline)
        .task { await run() }
    }

    private func bitView(_ kind: FallingBit.Kind) -> some View {
        switch kind {
        case .star:
            return AnyView(Circle().fill(Color(red: 1, green: 0.86, blue: 0.45)).frame(width: 22, height: 22))
        case .snack:
            return AnyView(Circle().fill(Color(red: 1, green: 0.62, blue: 0.74)).frame(width: 20, height: 20))
        case .rock:
            return AnyView(Circle().fill(Color(red: 0.45, green: 0.40, blue: 0.55)).frame(width: 24, height: 24))
        }
    }

    private func run() async {
        var ticks = 0
        while ticks < 40 * 8, !finished {
            try? await Task.sleep(nanoseconds: 125_000_000)
            ticks += 1
            if ticks.isMultiple(of: 8) {
                secondsLeft = max(0, 40 - ticks / 8)
                spawn()
            }
            advanceBits()
        }
        finish()
    }

    private func spawn() {
        let roll = Int.random(in: 0..<10)
        let kind: FallingBit.Kind = roll < 4 ? .star : (roll < 8 ? .snack : .rock)
        bits.append(FallingBit(x: CGFloat.random(in: 0.1...0.9), y: 0, kind: kind))
    }

    private func advanceBits() {
        var next: [FallingBit] = []
        for var bit in bits {
            bit.y += bit.kind == .rock ? 0.045 : 0.035
            if bit.y > 0.86, abs(bit.x - player) < 0.12 {
                switch bit.kind {
                case .star: stars += 1
                case .snack: snacks += 1
                case .rock: rocks += 1
                }
            } else if bit.y < 1.05 {
                next.append(bit)
            }
        }
        bits = next
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let points = GameRewards.starCatchPoints(stars: stars, snacks: snacks, rocks: rocks)
        session.finishGame(points: points)
        dismiss()
    }
}

private struct MemoryCard: Identifiable {
    let id = UUID()
    let symbol: Int
    var faceUp = false
    var matched = false
}

struct MemoryMatchGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [MemoryCard] = MemoryMatchGame.deal()
    @State private var picks: [UUID] = []
    @State private var pairs = 0
    @State private var misses = 0
    @State private var secondsLeft = 45
    @State private var finished = false
    @State private var lock = false

    private static let colors: [Color] = [
        Color(red: 1, green: 0.86, blue: 0.45),
        Color(red: 0.72, green: 0.62, blue: 0.98),
        Color(red: 0.62, green: 0.82, blue: 1)
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("\(secondsLeft)s · \(pairs) pairs")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(cards) { card in
                    Button {
                        flip(card)
                    } label: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(card.faceUp || card.matched ? Self.colors[card.symbol] : Color.white.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.45, green: 0.35, blue: 0.7), lineWidth: 2)
                            )
                            .frame(height: 88)
                    }
                    .disabled(card.matched || card.faceUp || lock || finished)
                    .accessibilityLabel(card.faceUp || card.matched ? "Card showing color \(card.symbol + 1)" : "Face-down card")
                }
            }
        }
        .padding()
        .background(PocketBackground().ignoresSafeArea())
        .navigationTitle("Memory Match")
        .navigationBarTitleDisplayMode(.inline)
        .task { await countdown() }
    }

    private static func deal() -> [MemoryCard] {
        ([0, 0, 1, 1, 2, 2].shuffled()).map { MemoryCard(symbol: $0) }
    }

    private func flip(_ card: MemoryCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[index].faceUp = true
        picks.append(card.id)
        guard picks.count == 2 else { return }
        lock = true
        let first = cards.first { $0.id == picks[0] }
        let second = cards.first { $0.id == picks[1] }
        if first?.symbol == second?.symbol {
            for id in picks {
                if let match = cards.firstIndex(where: { $0.id == id }) {
                    cards[match].matched = true
                }
            }
            pairs += 1
            picks = []
            lock = false
            if pairs == 3 { finish() }
        } else {
            misses += 1
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                for id in picks {
                    if let match = cards.firstIndex(where: { $0.id == id }) {
                        cards[match].faceUp = false
                    }
                }
                picks = []
                lock = false
            }
        }
    }

    private func countdown() async {
        while secondsLeft > 0, !finished {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if finished { return }
            secondsLeft -= 1
        }
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        session.finishGame(points: GameRewards.memoryPoints(pairs: pairs, misses: misses))
        dismiss()
    }
}

struct HideAndSeekGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var round = 1
    @State private var hiding = Int.random(in: 0..<3)
    @State private var finds = 0
    @State private var reveal: Int?
    @State private var finished = false

    private let names = ["Lilac", "Butter", "Mist"]
    private let colors = [
        Color(red: 0.72, green: 0.62, blue: 0.98),
        Color(red: 1, green: 0.86, blue: 0.55),
        Color(red: 0.62, green: 0.82, blue: 1)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Round \(min(round, 3)) of 3")
                .font(.headline)
            Text(reveal == nil ? "Which planet is the alien behind?" : (reveal == hiding ? "Found!" : "Not that one."))
                .font(.body)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    Button {
                        guess(index)
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(colors[index])
                                .frame(width: 72, height: 72)
                                .overlay {
                                    if reveal != nil, index == hiding {
                                        Circle().fill(Color.white).frame(width: 16, height: 16)
                                    }
                                }
                            Text(names[index])
                                .font(.caption)
                        }
                    }
                    .disabled(reveal != nil || finished)
                    .accessibilityLabel("\(names[index]) planet")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketBackground().ignoresSafeArea())
        .navigationTitle("Hide and Seek")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guess(_ index: Int) {
        reveal = index
        if index == hiding { finds += 1 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            if round == 3 {
                finish()
            } else {
                round += 1
                hiding = Int.random(in: 0..<3)
                reveal = nil
            }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        session.finishGame(points: GameRewards.hideAndSeekPoints(finds: finds))
        dismiss()
    }
}
