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
    @State private var showDressing = false
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
                                StatMeterView(stat: .fed, value: pet.hunger, tint: StatTint.fed, pop: pop(for: .fed))
                                StatMeterView(stat: .happy, value: pet.happiness, tint: StatTint.happy, pop: pop(for: .happy))
                                StatMeterView(stat: .energy, value: pet.energy, tint: StatTint.energy, pop: pop(for: .energy))
                            }
                            .animation(.spring(duration: 0.35), value: session.meterPops.count)
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
            .overlay {
                if let reward = session.playReward {
                    RewardPopup(reward: reward) {
                        session.dismissReward()
                        showShop = true
                    } onClose: {
                        session.dismissReward()
                    }
                } else if session.careAsk != nil {
                    WakeConfirm(
                        onWake: { session.confirmCare() },
                        onLeave: { session.dismissCare() }
                    )
                }
            }
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
            .sheet(isPresented: $showDressing) {
                NavigationStack {
                    DressingRoomView()
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
            GemCounter(count: session.record?.progress.coins ?? 0, level: session.level)
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
            shell: session.record?.progress.wardrobe.shell ?? "shell.plain",
            eyes: session.record?.progress.wardrobe.eyes ?? "eyes.round",
            antenna: session.record?.progress.wardrobe.antenna ?? "antenna.ball",
            marking: session.record?.progress.wardrobe.marking ?? "marking.none",
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
                title: "Dress",
                systemImage: "paintpalette.fill",
                hint: "Change shell, eyes, antennae, and markings.",
                disabled: false
            ) {
                showDressing = true
            }
            careButton(
                title: "Shop",
                systemImage: "bag",
                hint: "Spend star gems on food, toys, outfits, and skies.",
                disabled: false
            ) {
                showShop = true
            }
            if pet.stage != .egg, pet.isSleeping {
                Text("They're napping. You can still play, shop, and look around.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pet.stage != .egg, pet.energy < 15 {
                Text("Too tired to play together. A nap will help, or play solo after they sleep.")
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

    private func pop(for stat: CareStat) -> Int? {
        session.meterPops.first { $0.stat == stat }?.amount
    }

    private func canCare(_ pet: Pet) -> Bool {
        pet.stage != .egg && !pet.isSleeping && !pet.hasGoneHome
    }

    private func canPlay(_ pet: Pet) -> Bool {
        pet.stage != .egg && !pet.hasGoneHome && (pet.isSleeping || pet.energy >= 15)
    }

    private func playHint(_ pet: Pet) -> String {
        if pet.isSleeping {
            return "Play on your own. They keep sleeping, and you still earn gems."
        }
        if pet.energy < 15, pet.stage != .egg {
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
        let progress = session.record?.progress ?? PlayerProgress()
        let status = StarDex.status(collection: collection, progress: progress)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GoalMeter(title: "\(status.found)/\(status.total)", fraction: status.fraction, ink: .primary)
                    .padding(.horizontal, 4)
                ForEach(setNames, id: \.self) { setName in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(setName)
                                .font(.system(.headline, design: .rounded))
                            Spacer()
                            if status.completedSets.contains(setName), !progress.claimedDexSets.contains(setName) {
                                Button("Gift") { session.claimDex(setName) }
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                            }
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                            ForEach(StarDex.entries.filter { $0.setName == setName }) { entry in
                                dexCard(entry, collection: collection, progress: progress)
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.5)))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Letters")
                        .font(.system(.headline, design: .rounded))
                    if collection.letters.isEmpty {
                        Text("When an alien flies home, their letter will stay here.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(collection.letters) { letter in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(letter.name)
                                    .font(.system(.headline, design: .rounded))
                                Text(letter.message)
                                    .font(.system(.body, design: .rounded))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.55)))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(PocketBackground().ignoresSafeArea())
        .navigationTitle("Star Dex")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var setNames: [String] {
        var seen: [String] = []
        for entry in StarDex.entries where !seen.contains(entry.setName) {
            seen.append(entry.setName)
        }
        return seen
    }

    private func dexCard(_ entry: DexEntry, collection: PetCollection, progress: PlayerProgress) -> some View {
        let found = StarDex.isFound(id: entry.id, collection: collection, progress: progress)
        return VStack(spacing: 6) {
            dexArt(entry, found: found)
                .frame(width: 54, height: 54)
                .opacity(found ? 1 : 0.28)
                .saturation(found ? 1 : 0)
            Text(found ? entry.title : "???")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .lineLimit(1)
            if !found {
                Text(entry.hint)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.7)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(found ? "\(entry.title), \(entry.rarity.rawValue)" : "Unknown. \(entry.hint)")
    }

    @ViewBuilder
    private func dexArt(_ entry: DexEntry, found: Bool) -> some View {
        switch entry.id {
        case "form.egg":
            PetCreatureView(stage: .egg, mood: .egging, animates: false, accessibilityLabel: "")
        case "form.baby":
            PetCreatureView(stage: .baby, mood: .joyful, animates: false, accessibilityLabel: "")
        case "form.star":
            PetCreatureView(stage: .adult, mood: .joyful, form: .star, animates: false, accessibilityLabel: "")
        case "form.cloud":
            PetCreatureView(stage: .adult, mood: .joyful, form: .cloud, animates: false, accessibilityLabel: "")
        case "form.spiky":
            PetCreatureView(stage: .adult, mood: .joyful, form: .spiky, animates: false, accessibilityLabel: "")
        default:
            CareGlyph(stat: entry.id.hasPrefix("outfit") ? .look : (entry.id.hasPrefix("look") ? .happy : .gems), side: 36)
                .grayscale(found ? 0 : 1)
        }
    }
}

struct GemCounter: View {
    var count: Int
    var level: Int

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color(red: 1, green: 0.84, blue: 0.35))
                Circle().fill(Color.white.opacity(0.7)).frame(width: 8, height: 8).offset(x: -3, y: -3)
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
            Text("\(count)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.35), value: count)
            Spacer()
            Text("Lv \(level)")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.45)))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) star gems, level \(level)")
    }
}

struct RewardPopup: View {
    var reward: PlayReward
    var onShop: () -> Void
    var onClose: () -> Void
    @State private var burst = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(reward.title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text("\(reward.score)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .accessibilityLabel("Score \(reward.score)")
                if reward.isBest {
                    Text("New best")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(red: 1, green: 0.84, blue: 0.4)))
                }
                ChipFace(chip: CareChip(stat: .gems, amount: reward.gems), side: 26)
                Text("+\(reward.xp) XP")
                    .font(.system(.body, design: .rounded))
                if reward.gamesPlayed > 0 {
                    Text("Games today: \(min(reward.gamesPlayed, 2))/2")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button("Shop", action: onShop)
                    Button("Yay!", action: onClose)
                }
                .font(.system(.headline, design: .rounded).weight(.bold))
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.55, green: 0.42, blue: 0.86))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.93, blue: 1))
            )
            .padding(28)
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(Color(red: 1, green: 0.84, blue: 0.4))
                    .frame(width: 14, height: 14)
                    .offset(x: burst ? CGFloat(index - 4) * 28 : 0, y: burst ? -220 : 20)
                    .opacity(burst ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { burst = true }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .accessibilityAddTraits(.isModal)
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
    @State private var hopper = false
    @State private var snacks = false

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
                gameCard(
                    title: "Star Hopper",
                    blurb: "Bounce upward. Steer, grab gems, don't fall.",
                    score: best[MiniGame.starHopper.rawValue] ?? 0,
                    colors: [Color(red: 0.55, green: 0.75, blue: 1), Color(red: 0.95, green: 0.9, blue: 1)]
                ) {
                    hopper = true
                }
                .offset(y: appeared ? 0 : 70)
                .opacity(appeared ? 1 : 0)
                gameCard(
                    title: "Snack Match",
                    blurb: "Swap snacks. Lines of three pop and tumble.",
                    score: best[MiniGame.snackMatch.rawValue] ?? 0,
                    colors: [Color(red: 1, green: 0.64, blue: 0.74), Color(red: 0.98, green: 0.84, blue: 0.45)]
                ) {
                    snacks = true
                }
                .offset(y: appeared ? 0 : 100)
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
        .fullScreenCover(isPresented: $hopper) {
            StarHopperGame()
        }
        .fullScreenCover(isPresented: $snacks) {
            SnackMatchGame()
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


final class StarHopperScene: SKScene, SKPhysicsContactDelegate {
    var onScore: ((Int) -> Void)?
    var onEnd: ((Int) -> Void)?
    private var score = 0
    private var ended = false
    private var started = false
    private var player = SKShapeNode(circleOfRadius: 18)
    private var pads: [SKNode] = []
    private var origins: [ObjectIdentifier: CGFloat] = [:]
    private var steer: CGFloat = 0
    private var lastBounce: TimeInterval = 0
    private var wantsStart = false

    func begin() {
        wantsStart = true
        launchIfReady()
    }

    private func launchIfReady() {
        guard wantsStart, !started, !ended, player.parent != nil else { return }
        started = true
        isPaused = false
        player.physicsBody?.isDynamic = true
        player.physicsBody?.velocity = CGVector(dx: 0, dy: 820)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.20, green: 0.12, blue: 0.38, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -14)
        physicsWorld.contactDelegate = self
        let cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        let course = HopperCourse.pads(seed: UInt64.random(in: 1...90_000), count: 90, spacing: 96)
        for pad in course {
            let width = max(86, CGFloat(pad.span) * size.width * 0.78)
            let node = SKShapeNode(rectOf: CGSize(width: width, height: 20), cornerRadius: 10)
            node.position = CGPoint(x: CGFloat(pad.x) * size.width, y: 140 + CGFloat(pad.y))
            node.name = pad.kind.rawValue
            switch pad.kind {
            case .steady: node.fillColor = SKColor(red: 0.78, green: 0.70, blue: 1, alpha: 1)
            case .moving: node.fillColor = SKColor(red: 0.55, green: 0.78, blue: 1, alpha: 1)
            case .crumbly: node.fillColor = SKColor(red: 0.98, green: 0.72, blue: 0.55, alpha: 1)
            case .spring: node.fillColor = SKColor(red: 0.55, green: 0.90, blue: 0.72, alpha: 1)
            }
            node.strokeColor = SKColor(white: 1, alpha: 0.85)
            node.lineWidth = 3
            let body = SKPhysicsBody(rectangleOf: CGSize(width: width, height: 20))
            body.isDynamic = false
            body.categoryBitMask = 2
            body.collisionBitMask = 0
            body.contactTestBitMask = 1
            node.physicsBody = body
            addChild(node)
            pads.append(node)
            origins[ObjectIdentifier(node)] = node.position.x
            if pad.kind == .spring {
                let coil = SKShapeNode(rectOf: CGSize(width: 16, height: 18), cornerRadius: 4)
                coil.fillColor = SKColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1)
                coil.strokeColor = .white
                coil.position = CGPoint(x: 0, y: 16)
                node.addChild(coil)
            }
            if Int(pad.y) % 288 == 0, pad.y > 0 {
                let gem = SKShapeNode(circleOfRadius: 9)
                gem.fillColor = SKColor(red: 1, green: 0.86, blue: 0.45, alpha: 1)
                gem.strokeColor = .white
                gem.lineWidth = 2
                gem.position = CGPoint(x: node.position.x, y: node.position.y + 34)
                gem.name = "gem"
                addChild(gem)
            }
        }
        player.fillColor = SKColor(red: 0.86, green: 0.78, blue: 1, alpha: 1)
        player.strokeColor = .white
        player.lineWidth = 3
        let launch = pads.first
        player.position = CGPoint(x: launch?.position.x ?? size.width / 2, y: (launch?.position.y ?? 140) + 32)
        let body = SKPhysicsBody(circleOfRadius: 18)
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        body.linearDamping = 0
        body.categoryBitMask = 1
        body.collisionBitMask = 0
        body.contactTestBitMask = 2
        body.isDynamic = false
        player.physicsBody = body
        addChild(player)
        cameraNode.position = CGPoint(x: size.width / 2, y: player.position.y + size.height * 0.18)
        isPaused = true
        launchIfReady()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        aim(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        aim(touches)
    }

    private func aim(_ touches: Set<UITouch>) {
        guard let point = touches.first?.location(in: self), let camera else { return }
        let viewX = point.x - camera.position.x + size.width / 2
        steer = viewX < size.width / 2 ? -1 : 1
    }

    override func update(_ currentTime: TimeInterval) {
        guard started, !ended, let body = player.physicsBody, let camera else { return }
        body.velocity.dx = steer * 280
        if player.position.x < -16 { player.position.x = size.width + 8 }
        if player.position.x > size.width + 16 { player.position.x = -8 }
        let targetY = player.position.y + size.height * 0.18
        if targetY > camera.position.y {
            camera.position.y = targetY
        }
        for pad in pads where pad.name == HopperPad.Kind.moving.rawValue {
            let origin = origins[ObjectIdentifier(pad)] ?? pad.position.x
            pad.position.x = origin + sin(currentTime * 1.5 + pad.position.y) * 34
        }
        let stretch = 1 + min(0.22, abs(body.velocity.dy) / 5000)
        if body.velocity.dy > 40 {
            player.yScale = stretch
            player.xScale = 1 / stretch
        } else {
            player.yScale = 1 / stretch
            player.xScale = stretch
        }
        if body.velocity.dy < 0 {
            landIfNeeded(at: currentTime)
        }
        let climbed = Int(max(0, player.position.y - 140) / 28)
        if climbed > score {
            score = climbed
            onScore?(score)
        }
        if player.position.y < camera.position.y - size.height * 0.62 {
            ended = true
            onEnd?(score)
        }
    }

    private func landIfNeeded(at time: TimeInterval) {
        guard time - lastBounce > 0.12, let body = player.physicsBody else { return }
        for pad in pads where pad.parent != nil {
            let half = pad.frame.width / 2
            let dx = abs(player.position.x - pad.position.x)
            let dy = player.position.y - pad.position.y
            if dx < half - 4, dy > 8, dy < 40 {
                bounce(on: pad, body: body, at: time)
                return
            }
        }
    }

    private func bounce(on pad: SKNode, body: SKPhysicsBody, at time: TimeInterval) {
        lastBounce = time
        let boost: CGFloat = pad.name == HopperPad.Kind.spring.rawValue ? 1080 : 790
        body.velocity = CGVector(dx: body.velocity.dx, dy: boost)
        player.position.y = pad.position.y + 34
        if pad.name == HopperPad.Kind.crumbly.rawValue {
            pad.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        }
        UIImpactFeedbackGenerator(style: pad.name == HopperPad.Kind.spring.rawValue ? .medium : .light).impactOccurred()
        for gem in children where gem.name == "gem" {
            if hypot(gem.position.x - player.position.x, gem.position.y - player.position.y) < 46 {
                score += 6
                onScore?(score)
                gem.removeFromParent()
            }
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {}
}

struct StarHopperGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var scene: StarHopperScene = {
        let scene = StarHopperScene(size: CGSize(width: 390, height: 740))
        scene.scaleMode = .resizeFill
        return scene
    }()
    @State private var score = 0
    @State private var closed = false
    @State private var countdown = 3
    @State private var showHowTo = !UserDefaults.standard.bool(forKey: "howto.starHopper")

    private let goal = 40

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene).ignoresSafeArea()
            VStack(spacing: 8) {
                HStack {
                    Button("?") { showHowTo = true }
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.85)))
                        .accessibilityLabel("How to play Star Hopper")
                    Spacer()
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .accessibilityLabel("Score \(score)")
                }
                GoalMeter(title: "Star \(min(score, goal))/\(goal)", fraction: min(1, Double(score) / Double(goal)))
            }
            .padding(16)
            if countdown > 0, !showHowTo {
                Text(countdown == 1 ? "Hop!" : "\(countdown)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                    .frame(maxHeight: .infinity)
                    .onTapGesture { skipCountdown() }
            }
            if showHowTo {
                HowToOverlay(
                    title: "Star Hopper",
                    pages: [
                        "Tap the left or right side to steer. You bounce on your own.",
                        "Green pads spring higher. Orange pads break after one landing.",
                        "Grab star gems on the way up. Falling off the screen ends the run."
                    ],
                    onDone: {
                        UserDefaults.standard.set(true, forKey: "howto.starHopper")
                        showHowTo = false
                        startCountdown()
                    }
                )
            }
        }
        .onAppear {
            scene.onScore = { value in Task { @MainActor in score = value } }
            scene.onEnd = { final in
                Task { @MainActor in
                    guard !closed else { return }
                    closed = true
                    session.finishGame(points: final, gameID: MiniGame.starHopper.rawValue, title: "Star Hopper")
                    dismiss()
                }
            }
            if !showHowTo { startCountdown() }
        }
    }

    private func startCountdown() {
        countdown = 3
        Task { @MainActor in
            for tick in stride(from: 3, through: 1, by: -1) {
                countdown = tick
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            countdown = 0
            scene.begin()
        }
    }

    private func skipCountdown() {
        countdown = 0
        scene.begin()
    }
}

struct WakeConfirm: View {
    var onWake: () -> Void
    var onLeave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                CareGlyph(stat: .sleep, side: 48)
                Text("They're asleep")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Wake them gently for this?")
                    .font(.system(.body, design: .rounded))
                HStack(spacing: 12) {
                    Button("Let them sleep", action: onLeave)
                    Button("Wake", action: onWake)
                }
                .font(.system(.headline, design: .rounded).weight(.bold))
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.55, green: 0.42, blue: 0.86))
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(red: 0.97, green: 0.94, blue: 1)))
            .padding(28)
        }
        .accessibilityAddTraits(.isModal)
    }
}

struct GoalMeter: View {
    var title: String
    var fraction: Double
    var ink: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(ink)
            Capsule()
                .fill(Color.white.opacity(0.25))
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color(red: 1, green: 0.84, blue: 0.4))
                            .frame(width: geo.size.width * min(1, max(0, fraction)))
                    }
                }
                .frame(height: 12)
        }
        .accessibilityElement(children: .combine)
    }
}

struct HowToOverlay: View {
    var title: String
    var pages: [String]
    var onDone: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text(pages[page])
                    .font(.system(.title3, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 90)
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Color(red: 0.55, green: 0.4, blue: 0.9) : Color.gray.opacity(0.35))
                            .frame(width: 8, height: 8)
                    }
                }
                Button(page + 1 == pages.count ? "Let's play" : "Next") {
                    if page + 1 == pages.count {
                        onDone()
                    } else {
                        page += 1
                    }
                }
                .font(.system(.headline, design: .rounded).weight(.bold))
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.55, green: 0.42, blue: 0.86))
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(red: 0.97, green: 0.94, blue: 1)))
            .padding(28)
        }
        .accessibilityAddTraits(.isModal)
    }
}

struct SnackMatchGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var cells: [Int] = (0..<42).map { _ in Int.random(in: 0..<SnackMatch.kinds) }
    @State private var selected: Int?
    @State private var score = 0
    @State private var moves = 18
    @State private var finished = false
    @State private var pop = ""

    private let columns = 6
    private let rows = 7
    private let paints: [Color] = [
        Color(red: 1, green: 0.62, blue: 0.72),
        Color(red: 1, green: 0.84, blue: 0.45),
        Color(red: 0.62, green: 0.78, blue: 1),
        Color(red: 0.72, green: 0.62, blue: 0.98),
        Color(red: 0.55, green: 0.88, blue: 0.72)
    ]

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Moves \(moves)")
                Spacer()
                Text("\(score)")
            }
            .font(.system(.title3, design: .rounded).weight(.bold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
                ForEach(cells.indices, id: \.self) { index in
                    let tile = cells[index]
                    let hue = SnackMatch.hue(of: tile)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(paints[hue % paints.count])
                        .overlay {
                            if SnackMatch.isStripe(tile) {
                                Capsule().fill(Color.white.opacity(0.8)).frame(height: 6)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selected == index ? Color.white : Color.clear, lineWidth: 3)
                        )
                        .frame(height: 46)
                        .onTapGesture { tap(index) }
                        .accessibilityLabel("Snack \(hue + 1)")
                }
            }
            if !pop.isEmpty {
                Text(pop)
                    .font(.system(.title2, design: .rounded).weight(.bold))
            }
            Button("Close") { finish() }
                .font(.system(.body, design: .rounded).weight(.bold))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketBackground().ignoresSafeArea())
    }

    private func tap(_ index: Int) {
        guard !finished else { return }
        guard let selected else {
            self.selected = index
            return
        }
        guard SnackMatch.areNeighbors(selected, index, width: columns) else {
            self.selected = index
            return
        }
        let first = selected
        self.selected = nil
        if let outcome = SnackMatch.swapAndResolve(cells: cells, width: columns, height: rows, a: first, b: index, refill: { Int.random(in: 0..<SnackMatch.kinds) }) {
            cells = outcome.cells
            score += outcome.points
            moves -= 1
            pop = outcome.madeStripe ? "Stripe!" : (outcome.cascades > 1 ? "Cascade \(outcome.cascades)" : "")
            UIImpactFeedbackGenerator(style: outcome.cascades > 1 ? .medium : .light).impactOccurred()
            if moves <= 0 { finish() }
        } else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        session.finishGame(points: score, gameID: MiniGame.snackMatch.rawValue, title: "Snack Match")
        dismiss()
    }
}
