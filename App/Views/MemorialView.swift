import PetCore
import SwiftUI

/// The alien waves from a little ship, leaves a letter, and a new star egg is already waiting.
struct FarewellView: View {
    @EnvironmentObject private var session: PetSession
    @State private var name = ""

    private var letter: HomeLetter? { session.record?.farewell }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let letter {
                    VStack(spacing: 20) {
                        DepartureArtwork(form: letter.form)
                            .frame(maxWidth: 280)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("\(letter.name) waving from a little spaceship")

                        Text("\(letter.name) is flying home")
                            .font(.largeTitle.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .lineLimit(3)

                        Text(letter.message)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("A new star egg is here. It carries \(letter.trait.tint.phrase) from \(letter.trait.fromName).")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("Name the new egg", text: $name, prompt: Text("Mochi"))
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .accessibilityLabel("Name for the new egg")
                            .onChange(of: name) { _, newValue in
                                if newValue.count > 24 {
                                    name = String(newValue.prefix(24))
                                }
                            }

                        Button {
                            session.dismissFarewell(naming: name)
                        } label: {
                            Text("Meet the new egg")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PocketButton.tint)
                        .accessibilityHint("Closes the letter and shows the new egg.")
                    }
                    .padding(24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PocketBackground().ignoresSafeArea())
            .navigationTitle("Pocket Pet")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// A small ship and a waving alien, drawn with the same shapes as the pet.
struct DepartureArtwork: View {
    var form: AdultForm?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lift = false

    var body: some View {
        ZStack {
            PetCreatureView(
                stage: form == nil ? .baby : .adult,
                mood: .joyful,
                form: form,
                animates: false,
                accessibilityLabel: "Waving alien"
            )
            .frame(width: 140, height: 140)
            .offset(y: lift ? -36 : 8)
            ship
                .offset(y: lift ? -8 : 70)
        }
        .frame(height: 260)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                lift = true
            }
        }
        .accessibilityHidden(true)
    }

    private var ship: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.72, green: 0.62, blue: 0.95))
                .frame(width: 120, height: 36)
            Circle()
                .fill(Color(red: 0.85, green: 0.93, blue: 1))
                .frame(width: 22, height: 22)
                .offset(y: -10)
            Ellipse()
                .fill(Color(red: 1, green: 0.78, blue: 0.55))
                .frame(width: 16, height: 22)
                .offset(y: 24)
        }
    }
}

struct DressingRoomView: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let pet = session.record?.pet
        let wardrobe = session.record?.progress.wardrobe ?? .plain
        let stage = pet?.stage ?? .egg
        let form = pet?.displayForm
        ScrollView {
            VStack(spacing: 16) {
                PetCreatureView(
                    stage: stage,
                    mood: pet.map { PetMood.resolve($0) } ?? .egging,
                    form: form,
                    tint: pet?.trait?.tint,
                    outfit: session.record?.progress.outfitID,
                    shell: wardrobe.shell,
                    eyes: wardrobe.eyes,
                    antenna: wardrobe.antenna,
                    marking: wardrobe.marking,
                    accessibilityLabel: "Your alien in the dressing room"
                )
                .frame(width: 220, height: 220)
                ForEach(LookSlot.allCases, id: \.self) { slot in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(slot.spoken)
                            .font(.system(.headline, design: .rounded))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(LookBook.options.filter { $0.slot == slot }) { option in
                                    lookCard(option, wardrobe: wardrobe, stage: stage, form: form)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(PocketBackground().ignoresSafeArea())
        .navigationTitle("Dressing room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CosmicCloseButton(label: "Close dressing room") { dismiss() }
            }
        }
    }

    private func lookCard(_ option: LookOption, wardrobe: Wardrobe, stage: LifeStage, form: AdultForm?) -> some View {
        let owned = wardrobe.owned.contains(option.id)
        let worn = wardrobe.equipped(in: option.slot) == option.id
        let fits = LookBook.fits(option, stage: stage, form: form)
        return VStack(spacing: 6) {
            Circle()
                .fill(swatch(option.id))
                .frame(width: 46, height: 46)
                .overlay(Circle().stroke(worn ? Color.white : Color.clear, lineWidth: 3))
                .opacity(owned ? 1 : 0.45)
            Text("Lv \(option.level)")
                .font(.system(size: 10, design: .rounded).weight(.bold))
            if owned {
                Button(worn ? "On" : "Wear") { session.wearLook(option.id) }
                    .disabled(!fits || worn)
            } else {
                Button {
                    session.buyLook(option.id)
                } label: {
                    HStack(spacing: 3) {
                        CareGlyph(stat: .gems, side: 12)
                        Text("\(option.price)")
                    }
                }
            }
        }
        .font(.system(.caption, design: .rounded).weight(.bold))
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.55)))
        .accessibilityLabel(option.id)
    }

    private func swatch(_ id: String) -> Color {
        switch id {
        case "shell.stripes": return Color(red: 0.75, green: 0.65, blue: 0.95)
        case "shell.stars": return Color(red: 0.95, green: 0.85, blue: 0.45)
        case "eyes.star": return Color(red: 1, green: 0.9, blue: 0.5)
        case "eyes.soft": return Color(red: 1, green: 0.7, blue: 0.8)
        case "antenna.star": return Color(red: 0.7, green: 0.6, blue: 1)
        case "antenna.heart": return Color(red: 1, green: 0.55, blue: 0.7)
        case "marking.freckles": return Color(red: 0.85, green: 0.7, blue: 0.6)
        case "marking.belly": return Color(red: 1, green: 0.86, blue: 0.4)
        default: return Color(red: 0.9, green: 0.86, blue: 1)
        }
    }
}

struct ShopView: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var pending: Goods?
    @State private var pendingPrice: Int?
    @State private var buyingDeal = false
    @State private var tab = 0
    @State private var sparkle = false

    private let tabs = ["Snacks", "Toys", "Looks", "Skies"]

    var body: some View {
        let progress = session.record?.progress ?? PlayerProgress()
        let day = DayStamp.capture(session.currentDate, calendar: .current)
        let offer = DailyDeal.offer(on: day)
        let stamp = "\(day.year)-\(day.month)-\(day.day)"
        let dealTaken = progress.dealStamp == stamp && progress.dealBought
        let seconds = Int(DailyDeal.secondsLeft(now: session.currentDate))
        ZStack {
            PocketBackground(theme: "bg_shop").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 78)
                    shelfDecor
                    HStack {
                        PetCreatureView(
                            stage: .adult,
                            mood: .joyful,
                            form: .star,
                            animates: true,
                            accessibilityLabel: "Shopkeeper"
                        )
                        .frame(width: 92, height: 92)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Station shop")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                            HStack(spacing: 6) {
                                CareGlyph(stat: .gems, side: 18)
                                Text("\(progress.coins)")
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                            }
                        }
                        Spacer()
                    }
                    if let offer {
                        Button {
                            pending = offer.0
                            pendingPrice = offer.1
                            buyingDeal = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Daily deal")
                                    .font(.system(.headline, design: .rounded))
                                Text(offer.0.name)
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                ChipStrip(chips: offer.0.chips)
                                HStack {
                                    CareGlyph(stat: .gems, side: 16)
                                    Text("\(offer.1)")
                                    Spacer()
                                    Text(dealTaken ? "Taken" : String(format: "%d:%02d", seconds / 3600, (seconds % 3600) / 60))
                                }
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.55)))
                        }
                        .buttonStyle(.plain)
                        .disabled(dealTaken)
                    }
                    HStack(spacing: 8) {
                        ForEach(tabs.indices, id: \.self) { index in
                            Button(tabs[index]) { tab = index }
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .frame(width: 70, height: 70)
                                .background(Circle().fill(tab == index ? Color(red: 1, green: 0.78, blue: 0.86) : Color.white.opacity(0.45)))
                        }
                    }
                    TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        VStack(spacing: 12) {
                            ForEach(Array(shelf.enumerated()), id: \.element.id) { index, item in
                                shelfCard(item, progress: progress, bob: sin(time * 1.8 + Double(index)) * 5)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.22))
                                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.7), lineWidth: 2))
                        )
                    }
                    if progress.outfitID != nil {
                        Button("Take the outfit off") { session.equipOutfit(nil) }
                    }
                    if progress.backgroundID != nil {
                        Button("Use the usual sky") { session.equipBackground(nil) }
                    }
                }
                .padding(16)
            }
            if sparkle {
                ForEach(0..<6, id: \.self) { index in
                    CareGlyph(stat: .gems, side: 16)
                        .offset(x: CGFloat(index - 3) * 18, y: sparkle ? -160 : 40)
                        .opacity(sparkle ? 0 : 1)
                }
                .allowsHitTesting(false)
            }
        }
        .onChange(of: sparkle) { _, flying in
            guard flying else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                sparkle = false
            }
        }
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CosmicCloseButton(label: "Close shop") { dismiss() }
            }
        }
        .overlay {
            if let pending {
                BuyConfirm(item: pending, price: pendingPrice) {
                    if buyingDeal {
                        session.buyDeal()
                    } else {
                        session.buy(pending.id)
                    }
                    withAnimation(.easeOut(duration: 0.8)) { sparkle = true }
                    self.pending = nil
                    buyingDeal = false
                } onClose: {
                    self.pending = nil
                    buyingDeal = false
                }
            }
        }
    }

    private var shelfDecor: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 14) {
                ForEach(Array([GameArt.gemStar, GameArt.gemMoon, GameArt.gemHeart, GameArt.gemDonut, GameArt.planet(4)].enumerated()), id: \.offset) { index, name in
                    CatalogImage(name: name) { Color.clear.frame(width: 48, height: 48) }
                        .frame(width: 52, height: 52)
                        .offset(y: sin(time * 1.5 + Double(index)) * 5)
                        .shadow(color: .white.opacity(0.35), radius: 6)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityHidden(true)
    }

    private var shelf: [Goods] {
        Shop.catalog.filter { item in
            switch tab {
            case 1: if case .toy = item.kind { return true } else { return false }
            case 2: if case .outfit = item.kind { return true } else { return false }
            case 3: if case .background = item.kind { return true } else { return false }
            default: return !item.isDurable && { if case .toy = item.kind { return false } else { return true } }()
            }
        }
    }

    private func shelfCard(_ item: Goods, progress: PlayerProgress, bob: Double) -> some View {
        let locked = session.level < item.unlockLevel
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(.headline, design: .rounded))
                ChipStrip(chips: item.chips)
                HStack(spacing: 4) {
                    CareGlyph(stat: .gems, side: 14)
                    Text("\(item.price)")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                }
            }
            Spacer()
            VStack(spacing: 6) {
                Button("Buy") {
                    pending = item
                    pendingPrice = item.price
                    buyingDeal = false
                }
                .disabled(locked)
                if !item.isDurable, (progress.stock[item.id] ?? 0) > 0 {
                    Button("Use") { session.useItem(item.id) }
                }
                if item.isDurable, progress.ownedIDs.contains(item.id) {
                    Button(progress.outfitID == item.id || progress.backgroundID == item.id ? "On" : "Use") {
                        if case .outfit = item.kind { session.equipOutfit(item.id) }
                        else { session.equipBackground(item.id) }
                    }
                }
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(locked ? 0.28 : 0.62))
                .overlay {
                    if locked {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                    }
                }
        )
        .offset(y: bob)
        .opacity(locked ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }
}

struct ChipStrip: View {
    var chips: [CareChip]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                ChipFace(chip: chip)
            }
        }
    }
}

struct BuyConfirm: View {
    var item: Goods
    var price: Int?
    var onBuy: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(item.name)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                ChipStrip(chips: item.chips)
                HStack(spacing: 6) {
                    CareGlyph(stat: .gems, side: 22)
                    Text("\(price ?? item.price)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                }
                HStack(spacing: 12) {
                    Button("Not now", action: onClose)
                    Button("Buy", action: onBuy)
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

struct TodayView: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let progress = session.record?.progress ?? PlayerProgress()
        let level = session.level
        let into = progress.xp - LevelTable.xpToReach(level)
        let span = max(1, LevelTable.xpToReach(level + 1) - LevelTable.xpToReach(level))
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                panel {
                    Text("Level \(level)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    GoalMeter(title: "\(into) / \(span)", fraction: Double(into) / Double(span), ink: .primary)
                    Text(progress.streak.count == 1 ? "1 day of good care" : "\(progress.streak.count) days of good care")
                        .font(.system(.body, design: .rounded))
                }
                panel {
                    Text("Today")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    ForEach(DailyTask.allCases, id: \.self) { task in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(task.title)
                                .font(.system(.headline, design: .rounded))
                            Text(taskLine(task, progress: progress))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            if progress.daily.isComplete(task), !progress.daily.claimed.contains(task) {
                                Button {
                                    session.claim(task)
                                } label: {
                                    HStack(spacing: 4) {
                                        CareGlyph(stat: .gems, side: 14)
                                        Text("\(task.reward)")
                                    }
                                }
                                .font(.system(.caption, design: .rounded).weight(.bold))
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.55)))
                        .accessibilityElement(children: .combine)
                    }
                }
                panel {
                    Text("Achievements")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    if progress.achievements.isEmpty {
                        Text("Look after your alien and these will fill in.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(progress.achievements, id: \.self) { item in
                            Text(item.title)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Capsule().fill(Color.white.opacity(0.55)))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(PocketBackground())
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CosmicCloseButton(label: "Close today") { dismiss() }
            }
        }
    }

    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.38))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white, lineWidth: 2))
            )
    }

    private func taskLine(_ task: DailyTask, progress: PlayerProgress) -> String {
        if progress.daily.claimed.contains(task) { return "Collected" }
        switch task {
        case .playGames: return "\(min(progress.daily.gamesPlayed, 2)) / 2"
        case .healthyMeal: return progress.daily.healthyMeals > 0 ? "Done" : "Not yet"
        case .tuckIn: return progress.daily.tuckedIn ? "Done" : "Not yet"
        }
    }
}

struct AwaySummaryCard: View {
    var report: AwayReport
    var onOpen: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text("While you were away")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                ForEach(report.lines, id: \.self) { line in
                    Text(line)
                        .font(.system(.body, design: .rounded))
                }
                if report.gift > 0 {
                    ChipFace(chip: CareChip(stat: .gems, amount: report.gift))
                }
                HStack {
                    Button("Look", action: onOpen)
                    Button("Yay!", action: onClose)
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

struct AwayView: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let world = session.record?.world ?? AwayWorld.fresh(at: session.currentDate)
        let now = session.currentDate
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(world.doodle.isEmpty ? "The room is tidy." : roomLine(world.doodle))
                    .font(.system(.body, design: .rounded))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Star garden")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    if world.seeds.isEmpty {
                        Text("Plant a star seed from the shop.")
                            .font(.system(.body, design: .rounded))
                    }
                    ForEach(world.seeds) { seed in
                        Text(stageName(seed.stage(at: now)))
                            .font(.system(.headline, design: .rounded))
                    }
                    HStack {
                        Button("Plant") { session.plantSeed() }
                        Button("Harvest") { session.harvestGarden() }
                    }
                    .font(.system(.headline, design: .rounded).weight(.bold))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.45)))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gem tree")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    ChipFace(chip: CareChip(stat: .gems, amount: max(AwayLife.pendingGems(world, at: now), 0)))
                    Button("Collect") { session.collectTree() }
                        .font(.system(.headline, design: .rounded).weight(.bold))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.45)))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Space trip")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    if let trip = world.trip, !trip.isBack(at: now) {
                        Text("Traveling")
                            .font(.system(.body, design: .rounded))
                    } else if world.trip != nil {
                        Button("Welcome home") { session.collectTrip() }
                            .font(.system(.headline, design: .rounded).weight(.bold))
                    } else {
                        HStack {
                            Button("1h") { session.launchTrip(hours: 1) }
                            Button("4h") { session.launchTrip(hours: 4) }
                            Button("8h") { session.launchTrip(hours: 8) }
                        }
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    }
                    ForEach(world.postcards) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.system(.headline, design: .rounded))
                            Text(card.message)
                                .font(.system(.body, design: .rounded))
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.45)))
            }
            .padding(16)
        }
        .background(PocketBackground().ignoresSafeArea())
        .navigationTitle("While you were away")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CosmicCloseButton(label: "Close away") { dismiss() }
            }
        }
    }

    private func stageName(_ stage: Int) -> String {
        switch stage {
        case 1: return "Sprout"
        case 2: return "Bud"
        case 3: return "Ready"
        default: return "Seed"
        }
    }

    private func roomLine(_ doodle: String) -> String {
        switch doodle {
        case "doodle": return "There are new doodles on the wall."
        case "toys": return "A toy is out of place."
        case "nap": return "The bed is rumpled from an extra nap."
        default: return "The room is tidy."
        }
    }
}
