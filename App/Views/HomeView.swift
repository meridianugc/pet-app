import PetCore
import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var session: PetSession
    @State private var showCollection = false
    @State private var showGames = false
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
            .background(PocketBackground().ignoresSafeArea())
            .navigationTitle("Pocket Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showGames) {
                NavigationStack {
                    GamesMenu()
                }
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

struct GamesMenu: View {
    var body: some View {
        List {
            NavigationLink("Star Catch") {
                StarCatchGame()
            }
            .accessibilityHint("Drag to catch stars and snacks. Avoid rocks. About 40 seconds.")
            NavigationLink("Memory Match") {
                MemoryMatchGame()
            }
            .accessibilityHint("Flip cards and find the pairs.")
            NavigationLink("Hide and Seek") {
                HideAndSeekGame()
            }
            .accessibilityHint("Find the alien hiding behind a planet. Three rounds.")
        }
        .navigationTitle("Games")
        .navigationBarTitleDisplayMode(.inline)
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
