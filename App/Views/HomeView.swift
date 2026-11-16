import Combine
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
    @State private var inRoom = false
    @StateObject private var homeWorld = BedroomWorld()
    @State private var showVisit = false
    @AppStorage("visit.card") private var visitCard = ""
    @AppStorage("sound.muted") private var soundMuted = false
    @State private var showAway = false
#if DEBUG
    @State private var showDebug = false
#endif

    var body: some View {
        NavigationStack {
            Group {
            if let pet = session.record?.pet, pet.stage != .egg {
                livingRoom(pet)
            } else {
            ScrollView {
                if let pet = session.record?.pet {
                    VStack(alignment: .leading, spacing: 20) {
                        header(pet)
                        creature(pet)
                        if !session.speech.isEmpty {
                            Text(session.speech)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.75)))
                                .accessibilityLabel(session.speech)
                        }
                        if let wish = session.record?.world.requestText, !wish.isEmpty {
                            Text(wish)
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        if pet.isSleeping {
                            NappingBubble()
                        } else {
                            Text(PetCopy.statusLine(pet))
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityAddTraits(.isHeader)
                        }

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
                            itemTray
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
                } else if let report = session.awayReport, !report.lines.isEmpty {
                    AwaySummaryCard(report: report) {
                        session.dismissAway()
                        showAway = true
                    } onClose: {
                        session.dismissAway()
                    }
                } else if session.careAsk != nil {
                    WakeConfirm(
                        onWake: { session.confirmCare() },
                        onLeave: { session.dismissCare() }
                    )
                }
            }
            .onAppear {
                PocketSound.shared.startTune()
                if ScreenshotDemo.isOn { showGames = true }
                let roomArgs = ProcessInfo.processInfo.arguments
                if roomArgs.contains("-roomShot") || roomArgs.contains("-roomWalk") { inRoom = true }
                bootHome()
            }
            .onChange(of: session.record?.pet.stage) { _, _ in
                bootHome()
            }
            .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
                guard !inRoom else { return }
                homeWorld.tick(dt: 1.0 / 60.0, closet: false)
            }
            .navigationTitle("Pocket Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(inRoom || !HomeFrame.current.isEmpty ? .hidden : .visible, for: .navigationBar)
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
            .sheet(isPresented: $showVisit) {
                VisitSheet(card: visitCard) { visitCard = $0 }
            }
            .sheet(isPresented: $showDressing) {
                NavigationStack {
                    DressingRoomView()
                }
            }
            .sheet(isPresented: $showAway) {
                NavigationStack {
                    AwayView()
                }
            }
            .onChange(of: session.openShopAfterGame) { _, open in
                if open {
                    session.openShopAfterGame = false
                    showShop = true
                }
            }
            .overlay {
                if inRoom, session.record?.pet != nil {
                    BedroomView(
                        onExit: { withAnimation(.spring(duration: 0.45)) { inRoom = false } },
                        onVisit: { showVisit = true },
                        visitor: visitCard
                    )
                    .transition(.scale(scale: 0.72, anchor: .center).combined(with: .opacity))
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
            Text(PetCopy.stageLine(pet, now: session.currentDate, level: session.level))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            GemCounter(count: session.record?.progress.coins ?? 0, level: session.level)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func livingRoom(_ pet: Pet) -> some View {
        ZStack(alignment: .top) {
            BedroomCanvas(world: homeWorld) { kind in
                greetHome(kind)
            }
            .ignoresSafeArea()
            VStack(spacing: 8) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pet.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.42))
                        Text(PetCopy.stageLine(pet, now: session.currentDate, level: session.level))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(homeWorld.wing == "kitchen" ? "Bedroom" : "Kitchen") {
                        if homeWorld.wing == "kitchen" {
                            homeWorld.showBedroom()
                        } else {
                            homeWorld.showKitchen()
                        }
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.92)))
                    .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.42))
                }
                .padding(.horizontal, 16)
                if !homeWorld.hello.isEmpty {
                    Text(homeWorld.hello)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.42))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.95)))
                        .accessibilityLabel(homeWorld.hello)
                }
                Spacer()
                    .allowsHitTesting(false)
                VStack(spacing: 8) {
                    StatMeterView(stat: .fed, value: pet.hunger, tint: StatTint.fed, pop: pop(for: .fed))
                    StatMeterView(stat: .happy, value: pet.happiness, tint: StatTint.happy, pop: pop(for: .happy))
                    StatMeterView(stat: .energy, value: pet.energy, tint: StatTint.energy, pop: pop(for: .energy))
                    itemTray
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            roomChip("Feed", "fork.knife") { session.feed() }
                            roomChip("Play", "gamecontroller.fill") { showGames = true }
                            roomChip(pet.isSleeping ? "Wake" : "Sleep", pet.isSleeping ? "sun.max.fill" : "moon.fill") { session.toggleSleep() }
                            roomChip("Room", "house.fill") { withAnimation(.spring(duration: 0.45)) { inRoom = true } }
                            roomChip("Shop", "bag") { showShop = true }
                            roomChip("Today", "sun.max") { showToday = true }
                        }
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 10)
            }
            .safeAreaPadding(.top, 6)
            .safeAreaPadding(.bottom, 6)
        }
        .onAppear { bootHome() }
    }

    private func roomChip(_ title: String, _ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: system)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.9)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.42))
    }

    private func greetHome(_ kind: String) {
        let name = session.record?.pet.name ?? "friend"
        homeWorld.notice(kind, name: name)
        PocketSound.shared.speak(homeWorld.hello)
        switch kind {
        case "giggle":
            session.react(to: .tickle)
        case "purr":
            session.react(to: .pet)
        default:
            session.react(to: .poke)
        }
        homeWorld.nudge()
    }

    private func bootHome() {
        guard let pet = session.record?.pet, pet.stage != .egg else { return }
        homeWorld.autonomous = HomeFrame.current.isEmpty
        homeWorld.boot(
            room: session.currentRoom(),
            stage: pet.stage,
            form: pet.displayForm,
            outfit: session.record?.progress.outfitID,
            guestName: "",
            guestForm: ""
        )
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
            level: session.level,
            accessibilityLabel: PetCopy.summary(pet, now: session.currentDate)
        )
            .frame(maxWidth: 260)
            .frame(height: 260)
            .overlay(alignment: .bottomLeading) {
                if !(session.record?.world.looseToy.isEmpty ?? true) {
                    LooseToy()
                        .frame(width: 54, height: 54)
                        .offset(x: 8, y: 8)
                        .onTapGesture { session.putToyAway() }
                        .accessibilityLabel("Toy outside the bin")
                }
            }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { session.react(to: .tickle) }
        .onTapGesture { session.react(to: .poke) }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { _ in session.react(to: .pet) }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to poke, double tap to tickle, swipe to pet")
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
                title: "Away",
                systemImage: "leaf.fill",
                hint: "Garden, trips, and the gem tree.",
                disabled: pet.stage == .egg
            ) {
                showAway = true
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
                title: "Room",
                systemImage: "house.fill",
                hint: "Walk around your pet's room.",
                disabled: pet.stage == .egg
            ) {
                withAnimation(.spring(duration: 0.45)) { inRoom = true }
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
        Button {
            PocketSound.shared.tap()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(PocketButton.tint)
        .disabled(disabled)
        .accessibilityHint(hint)
    }

    private var itemTray: some View {
        let stock = session.record?.progress.stock ?? [:]
        let ids = stock.keys.sorted().filter { key in
            guard let item = Shop.item(key) else { return false }
            return !item.isDurable && (stock[key] ?? 0) > 0
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ids, id: \.self) { id in
                    if let item = Shop.item(id) {
                        Button {
                            session.useItem(id)
                        } label: {
                            VStack(spacing: 4) {
                                Text(item.name)
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                ChipStrip(chips: item.chips)
                                Text("×\(stock[id] ?? 0)")
                                    .font(.system(.caption2, design: .rounded))
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.72)))
                        }
                        .buttonStyle(CosmicPressStyle())
                    }
                }
            }
        }
        .opacity(ids.isEmpty ? 0 : 1)
        .frame(height: ids.isEmpty ? 0 : nil)
    }

    private func pop(for stat: CareStat) -> Int? {
        session.meterPops.first { $0.stat == stat }?.amount
    }

    private func canCare(_ pet: Pet) -> Bool {
        pet.stage != .egg && !pet.isSleeping && !pet.hasGoneHome
    }

    private func canPlay(_ pet: Pet) -> Bool {
        pet.stage != .egg && !pet.hasGoneHome && !session.isTraveling && (pet.isSleeping || pet.energy >= 15)
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
                soundMuted.toggle()
                PocketSound.shared.muted = soundMuted
                if soundMuted { PocketSound.shared.stopTune() } else { PocketSound.shared.startTune() }
            } label: {
                Image(systemName: soundMuted ? "speaker.slash" : "speaker.wave.2")
            }
            .accessibilityLabel(soundMuted ? "Unmute" : "Mute")
        }
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
        let status = StarDex.status(collection: collection, progress: progress, world: session.record?.world ?? .fresh(at: session.currentDate))
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
            ToolbarItem(placement: .topBarTrailing) {
                CosmicCloseButton(label: "Close star dex") { dismiss() }
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
        let found = StarDex.isFound(id: entry.id, collection: collection, progress: progress, world: session.record?.world ?? .fresh(at: session.currentDate))
        return VStack(spacing: 6) {
            dexArt(entry, found: found)
                .frame(width: 54, height: 54)
                .opacity(found ? 1 : 0.28)
                .saturation(found ? 1 : 0)
            Text(found ? entry.title : "???")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .lineLimit(1)
            Text("Lv \(entry.unlockLevel)")
                .font(.system(size: 10, design: .rounded).weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color(red: 1, green: 0.84, blue: 0.45)))
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
            if let form = AdultForm(rawValue: String(entry.id.dropFirst(5))), entry.id.hasPrefix("form.") {
                PetCreatureView(stage: .adult, mood: .joyful, form: form, animates: false, accessibilityLabel: "")
            } else {
                CareGlyph(stat: entry.id.hasPrefix("outfit") ? .look : (entry.id.hasPrefix("look") ? .happy : .gems), side: 36)
                    .grayscale(found ? 0 : 1)
            }
        }
    }
}

struct LooseToy: View {
    var body: some View {
        CatalogImage(name: GameArt.toyComet) {
            ZStack {
                Circle().fill(Color(red: 0.98, green: 0.72, blue: 0.45))
                Circle().fill(Color.white.opacity(0.7)).frame(width: 10, height: 10).offset(x: -6, y: -6)
            }
        }
    }
}

struct ToyBin: View {
    var body: some View {
        CatalogImage(name: GameArt.toyBin) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.55, green: 0.42, blue: 0.86))
                .overlay(alignment: .top) {
                    Capsule().fill(Color(red: 0.4, green: 0.28, blue: 0.7)).frame(height: 10).padding(.horizontal, 8).offset(y: -4)
                }
        }
    }
}

struct NappingBubble: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 8) {
                Text("zZz napping...")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .offset(y: sin(time * 2 + Double(index)) * 4)
                        .opacity(0.5 + 0.5 * abs(sin(time + Double(index))))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.72)))
            .accessibilityLabel("zZz napping")
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
            CosmicCloseButton(label: "Close reward", action: onClose)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 16)
                .padding(.top, 8)
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
    @State private var defense = false
    @State private var solitaire = false
    @State private var sudoku = false
    @State private var ship = false

    var body: some View {
        ZStack {
            PocketBackground().ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Text("Play")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Spacer()
                    CosmicCloseButton(label: "Close games") { dismiss() }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        galleryRow("Big Games", games: GameLibrary.big)
                        galleryRow("Mini Games", games: GameLibrary.mini)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                }
            }
            .padding(20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
            if ScreenshotDemo.isOn { defense = true }
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
        .fullScreenCover(isPresented: $defense) {
            StarDefenseGame()
        }
        .fullScreenCover(isPresented: $solitaire) {
            CosmicSolitaireGame()
        }
        .fullScreenCover(isPresented: $sudoku) {
            StarSudokuGame()
        }
        .fullScreenCover(isPresented: $ship) {
            ShipDuoGame()
        }
    }

    private func galleryRow(_ title: String, games: [MiniGame]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(games) { game in
                        galleryTile(game)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func galleryTile(_ game: MiniGame) -> some View {
        let score = best[game.rawValue] ?? 0
        let stars = starCount(game)
        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                GamePreview(game: game)
                    .frame(width: 230, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                if howToKey(game) != nil {
                    Button {
                        if let key = howToKey(game) {
                            UserDefaults.standard.set(false, forKey: key)
                        }
                        open(game)
                    } label: {
                        Text("?")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.92)))
                    }
                    .padding(8)
                    .accessibilityLabel("How to play \(game.title)")
                }
            }
            Text(game.title)
                .font(.system(.headline, design: .rounded).weight(.bold))
            Text(score > 0 ? "Best \(score)" : "No score yet")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            if stars > 0 {
                Text(String(repeating: "★", count: min(5, stars)))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.3))
            }
        }
        .padding(10)
        .frame(width: 250, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.62))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white, lineWidth: 2))
        )
        .onTapGesture { open(game) }
        .accessibilityLabel("\(game.title). \(score > 0 ? "Best score \(score)" : "No score yet")")
    }

    private func open(_ game: MiniGame) {
        switch game {
        case .planetMerge: planet = true
        case .starHopper: hopper = true
        case .snackMatch: snacks = true
        case .starDefense:
            PlayOrientation.mask = .landscape
            defense = true
        case .cosmicSolitaire: solitaire = true
        case .starSudoku: sudoku = true
        case .shipDuo: ship = true
        case .starCatch, .memoryMatch, .hideAndSeek: break
        }
    }

    private func howToKey(_ game: MiniGame) -> String? {
        switch game {
        case .planetMerge: return "howto.planetMerge"
        case .starHopper: return "howto.starHopper"
        case .snackMatch: return "howto.snackMatch"
        case .starDefense: return "howto.starDefense"
        case .cosmicSolitaire: return "howto.solitaire"
        case .starSudoku: return "howto.sudoku"
        default: return nil
        }
    }

    private func starCount(_ game: MiniGame) -> Int {
        switch game {
        case .starDefense:
            return (1...8).reduce(0) { $0 + (best["starDefense.level.\($1)"] ?? 0) }
        case .cosmicSolitaire:
            return (1...8).reduce(0) { $0 + (best["solitaire.level.\($1)"] ?? 0) }
        case .starSudoku:
            return SudokuDifficulty.allCases.reduce(0) { $0 + (best["sudoku.\($1.rawValue)"] ?? 0) }
        default:
            return 0
        }
    }
}

struct GamePreview: View {
    var game: MiniGame

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let sky = Path(CGRect(origin: .zero, size: size))
                context.fill(sky, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.55, green: 0.45, blue: 0.9),
                        Color(red: 0.95, green: 0.78, blue: 0.9)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ))
                switch game {
                case .starHopper:
                    for index in 0..<4 {
                        let y = size.height * (0.28 + CGFloat(index) * 0.16)
                        let rect = CGRect(x: 24 + CGFloat(index) * 8, y: y, width: size.width * 0.42, height: 10)
                        context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(.white.opacity(0.85)))
                    }
                case .planetMerge:
                    let pulse = CGFloat(sin(time * 2)) * 6
                    context.fill(Path(ellipseIn: CGRect(x: 40, y: 40, width: 36 + pulse, height: 36 + pulse)), with: .color(Color(red: 1, green: 0.7, blue: 0.45)))
                    context.fill(Path(ellipseIn: CGRect(x: 70, y: 58, width: 48, height: 48)), with: .color(Color(red: 0.65, green: 0.55, blue: 0.95)))
                case .snackMatch:
                    for index in 0..<6 {
                        let x = 18 + CGFloat(index % 3) * 36
                        let y = 28 + CGFloat(index / 3) * 36 + CGFloat(sin(time * 3 + Double(index))) * 3
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 26, height: 26)), with: .color(index % 2 == 0 ? Color(red: 1, green: 0.55, blue: 0.7) : Color(red: 0.45, green: 0.75, blue: 1)))
                    }
                case .starDefense:
                    var path = Path()
                    path.move(to: CGPoint(x: 16, y: 20))
                    path.addCurve(to: CGPoint(x: size.width - 20, y: size.height - 24), control1: CGPoint(x: size.width * 0.2, y: size.height * 0.7), control2: CGPoint(x: size.width * 0.8, y: 30))
                    context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 10)
                    let blobX = 20 + CGFloat((time * 30).truncatingRemainder(dividingBy: Double(size.width - 40)))
                    context.fill(Path(ellipseIn: CGRect(x: blobX, y: 48, width: 16, height: 16)), with: .color(Color(red: 0.95, green: 0.45, blue: 0.55)))
                case .cosmicSolitaire:
                    for index in 0..<4 {
                        let rect = CGRect(x: 16 + CGFloat(index) * 28, y: 36 + CGFloat(sin(time + Double(index))) * 4, width: 22, height: 32)
                        context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(.white.opacity(0.9)))
                    }
                case .starSudoku:
                    for row in 0..<3 {
                        for column in 0..<3 {
                            let rect = CGRect(x: 20 + CGFloat(column) * 28, y: 24 + CGFloat(row) * 28, width: 24, height: 24)
                            context.stroke(Path(rect), with: .color(.white.opacity(0.8)), lineWidth: 1)
                        }
                    }
                case .shipDuo:
                    let sway = CGFloat(sin(time * 1.5)) * 16
                    context.fill(Path(ellipseIn: CGRect(x: size.width * 0.35 + sway, y: size.height * 0.45, width: 54, height: 22)), with: .color(Color(red: 0.75, green: 0.65, blue: 0.98)))
                    context.fill(Path(ellipseIn: CGRect(x: 30, y: 30, width: 22, height: 22)), with: .color(Color(red: 0.95, green: 0.55, blue: 0.45)))
                case .starCatch, .memoryMatch, .hideAndSeek:
                    break
                }
            }
            .overlay(alignment: .bottomTrailing) {
                RaisedPet(side: 48, bounce: true)
                    .padding(6)
            }
        }
    }
}

enum SpriteArt {
    private static var cache: [String: SKTexture] = [:]

    static func texture(_ name: String) -> SKTexture? {
        if let cached = cache[name] { return cached }
        guard let image = GameArt.uiImage(name) else { return nil }
        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        cache[name] = texture
        return texture
    }
}

enum PlanetArt {
    static func texture(index: Int, radius: CGFloat) -> SKTexture {
        let side = radius * 2 + 16
        let colors: [UIColor] = [
            UIColor(red: 1, green: 0.78, blue: 0.55, alpha: 1),
            UIColor(red: 1, green: 0.55, blue: 0.7, alpha: 1),
            UIColor(red: 0.7, green: 0.58, blue: 1, alpha: 1),
            UIColor(red: 0.5, green: 0.75, blue: 1, alpha: 1),
            UIColor(red: 0.55, green: 0.88, blue: 0.72, alpha: 1),
            UIColor(red: 0.98, green: 0.86, blue: 0.4, alpha: 1),
            UIColor(red: 0.55, green: 0.42, blue: 0.85, alpha: 1)
        ]
        let fill = colors[index % colors.count]
        if let packed = SpriteArt.texture(GameArt.planet(index + 1)) {
            return packed
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let cg = context.cgContext
            let rect = CGRect(x: 8, y: 8, width: radius * 2, height: radius * 2)
            cg.setFillColor(fill.cgColor)
            cg.fillEllipse(in: rect)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            cg.fillEllipse(in: CGRect(x: rect.minX + radius * 0.35, y: rect.minY + radius * 0.25, width: radius * 0.7, height: radius * 0.45))
            cg.setFillColor(fill.withAlphaComponent(0.45).cgColor)
            cg.fillEllipse(in: CGRect(x: rect.midX, y: rect.midY, width: radius * 0.35, height: radius * 0.28))
            if index % 2 == 0 {
                cg.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
                cg.setLineWidth(3)
                cg.strokeEllipse(in: rect.insetBy(dx: -4, dy: radius * 0.35))
            }
            if index >= 2 {
                cg.setFillColor(UIColor(white: 0.15, alpha: 0.8).cgColor)
                cg.fillEllipse(in: CGRect(x: rect.midX - radius * 0.28, y: rect.midY - radius * 0.05, width: radius * 0.16, height: radius * 0.2))
                cg.fillEllipse(in: CGRect(x: rect.midX + radius * 0.1, y: rect.midY - radius * 0.05, width: radius * 0.16, height: radius * 0.2))
            }
        }
        return SKTexture(image: image)
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
        backgroundColor = .clear
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
        let radius = (node.userData?["radius"] as? CGFloat) ?? node.frame.width / 2
        let clamped = min(size.width - 24 - radius, max(24 + radius, x))
        node.position = CGPoint(x: clamped, y: size.height - radius - 8)
        addChild(node)
        current = upcoming
        upcoming = Int.random(in: 0...2)
        run(.sequence([.wait(forDuration: 0.4), .run { [weak self] in self?.ready = true }]))
    }

    func wearMascot(_ texture: SKTexture) {
        childNode(withName: "mascot")?.removeFromParent()
        let node = SKSpriteNode(texture: texture)
        node.name = "mascot"
        node.size = CGSize(width: 72, height: 72)
        node.position = CGPoint(x: size.width / 2, y: size.height - 86)
        node.zPosition = 30
        addChild(node)
    }

    private func cheerMascot() {
        childNode(withName: "mascot")?.run(.sequence([
            .scale(to: 1.18, duration: 0.08),
            .scale(to: 1, duration: 0.12)
        ]))
    }

    func restart() {
        children.filter { $0.name == "planet" }.forEach { $0.removeFromParent() }
        score = 0
        combo = 0
        ended = false
        ready = true
        danger = 0
        isPaused = false
        onScore?(0)
    }

    func blastOne() -> Bool {
        let planets = children.filter { $0.name == "planet" }
        guard let target = planets.min(by: { sizeOf($0) ?? 0 < sizeOf($1) ?? 0 }) else { return false }
        burst(at: target.position)
        target.removeFromParent()
        score += 8
        onScore?(score)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    private func planet(sizeIndex: Int) -> SKSpriteNode {
        let index = min(7, max(0, sizeIndex))
        let canvas: CGFloat = 148
        let bodyScale: [CGFloat] = [0.34, 0.42, 0.50, 0.58, 0.66, 0.74, 0.84, 0.94]
        let painted = SpriteArt.texture(GameArt.planet(index + 1))
        let radius = painted == nil
            ? CGFloat(PlanetMerge.radius(for: sizeIndex))
            : canvas * 0.5 * bodyScale[index] * 0.86
        let node = SKSpriteNode(texture: painted ?? PlanetArt.texture(index: sizeIndex, radius: radius))
        node.size = painted == nil
            ? CGSize(width: radius * 2.2, height: radius * 2.2)
            : CGSize(width: canvas, height: canvas)
        node.name = "planet"
        node.userData = ["size": sizeIndex, "radius": radius]
        if painted == nil {
            let glow = SKSpriteNode(texture: node.texture)
            glow.size = CGSize(width: radius * 2.8, height: radius * 2.8)
            glow.alpha = 0.35
            glow.blendMode = .add
            glow.zPosition = -1
            node.addChild(glow)
        }
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
        cheerMascot()
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
    @State private var showHowTo = !UserDefaults.standard.bool(forKey: "howto.planetMerge")
    @State private var askingLeave = false
    @State private var finale: GameFinale?
    @State private var run = 1

    private var goal: Int { 60 + run * 20 }

    var body: some View {
        ZStack(alignment: .top) {
            PocketBackground(theme: "bg_merge").ignoresSafeArea()
            SpriteView(scene: scene, options: [.allowsTransparency])
                .ignoresSafeArea()
            VStack(spacing: 8) {
                HStack {
                    CosmicCloseButton(label: "Leave Planet Merge") {
                        scene.isPaused = true
                        askingLeave = true
                    }
                    Button("?") { showHowTo = true }
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.85)))
                        .accessibilityLabel("How to play Planet Merge")
                    Spacer()
                    Button("Blast \(session.powerCount(.blast))") {
                        guard session.spendPower(.blast) else {
                            session.buyPower(.blast)
                            return
                        }
                        _ = scene.blastOne()
                    }
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.85)))
                    .accessibilityLabel("Blast, \(session.powerCount(.blast)) charges")
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .accessibilityLabel("Score \(score)")
                }
                GoalMeter(title: "\(min(score, goal))/\(goal)", fraction: Double(min(score, goal)) / Double(goal))
            }
            .padding(16)
            if askingLeave {
                LeaveGamePrompt(onStay: {
                    askingLeave = false
                    scene.isPaused = false
                }, onLeave: {
                    presentEnd(score: score, detail: "You stepped away from the jar.")
                })
            }
            if let finale {
                GameEndCard(finale: finale, onAgain: { replay(next: false) }, onNext: { replay(next: true) }, onShop: shopOut, onHome: { dismiss() })
            }
            if showHowTo {
                HowToOverlay(
                    title: "Planet Merge",
                    pages: [
                        "Tap to drop the planet in your hand.",
                        "Two of the same size melt into the next planet.",
                        "If the stack rests above the line, the round ends."
                    ],
                    onDone: {
                        UserDefaults.standard.set(true, forKey: "howto.planetMerge")
                        showHowTo = false
                    }
                )
            }
        }
        .onAppear {
            scene.wearMascot(PetStamp.texture(session: session, mood: .joyful))
            scene.onScore = { value in
                Task { @MainActor in score = value }
            }
            scene.onEnd = { final in
                Task { @MainActor in
                    presentEnd(score: final, detail: final >= goal ? "The jar is glowing." : "The stack crossed the line.")
                }
            }
        }
    }

    private func presentEnd(score: Int, detail: String) {
        guard finale == nil else { return }
        closed = true
        scene.isPaused = true
        finale = bankedFinale(session: session, title: "Planet Merge", score: score, detail: "Run \(run). \(detail)", gameID: MiniGame.planetMerge.rawValue)
    }

    private func replay(next: Bool) {
        if next { run += 1 }
        closed = false
        finale = nil
        score = 0
        scene.restart()
    }

    private func shopOut() {
        session.openShopAfterGame = true
        dismiss()
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
    private let starfield = SKNode()

    func restart() {
        ended = false
        started = false
        wantsStart = false
        score = 0
        steer = 0
        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        if let launch = pads.first {
            player.position = CGPoint(x: launch.position.x, y: launch.position.y + 32)
        }
        if let camera {
            camera.position = CGPoint(x: size.width / 2, y: player.position.y + size.height * 0.18)
        }
        isPaused = true
        onScore?(0)
    }

    func boost() {
        guard started, !ended else { return }
        player.physicsBody?.velocity.dy = 1100
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

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
        backgroundColor = .clear
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
            let artName: String
            switch pad.kind {
            case .moving: artName = GameArt.platformAsteroid
            case .crumbly: artName = GameArt.platformBreaking
            default: artName = GameArt.platformCloud
            }
            if let texture = SpriteArt.texture(artName) {
                let sprite = SKSpriteNode(texture: texture)
                sprite.size = CGSize(width: width, height: width)
                node.addChild(sprite)
                node.fillColor = .clear
                node.strokeColor = .clear
            }
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
                if let texture = SpriteArt.texture(GameArt.spring) {
                    let coil = SKSpriteNode(texture: texture)
                    coil.size = CGSize(width: 42, height: 42)
                    coil.position = CGPoint(x: 0, y: 24)
                    node.addChild(coil)
                } else {
                    let coil = SKShapeNode(rectOf: CGSize(width: 16, height: 18), cornerRadius: 4)
                    coil.fillColor = SKColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1)
                    coil.strokeColor = .white
                    coil.position = CGPoint(x: 0, y: 16)
                    node.addChild(coil)
                }
            }
            if Int(pad.y) % 288 == 0, pad.y > 0 {
                let gem = SKShapeNode(circleOfRadius: 9)
                gem.fillColor = SKColor(red: 1, green: 0.86, blue: 0.45, alpha: 1)
                gem.strokeColor = .white
                gem.lineWidth = 2
                gem.position = CGPoint(x: node.position.x, y: node.position.y + 34)
                gem.name = "gem"
                if let texture = SpriteArt.texture(GameArt.gemPickup) {
                    let sprite = SKSpriteNode(texture: texture)
                    sprite.size = CGSize(width: 30, height: 30)
                    gem.addChild(sprite)
                    gem.fillColor = .clear
                    gem.strokeColor = .clear
                    addSparkle(to: sprite)
                }
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
        for index in 0..<24 {
            let star = SKShapeNode(circleOfRadius: index % 4 == 0 ? 2.4 : 1.3)
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = 0.8
            star.position = CGPoint(x: CGFloat((index * 53) % Int(size.width)), y: CGFloat(index * 140))
            starfield.addChild(star)
        }
        starfield.zPosition = -5
        addChild(starfield)
        isPaused = true
        launchIfReady()
    }

    func wearJumper(_ texture: SKTexture) {
        player.fillColor = .clear
        player.strokeColor = .clear
        player.childNode(withName: "face")?.removeFromParent()
        let face = SKSpriteNode(texture: texture)
        face.name = "face"
        face.size = CGSize(width: 46, height: 46)
        player.addChild(face)
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
        starfield.position.y = camera.position.y * 0.4
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

    private func addSparkle(to node: SKNode) {
        for index in 0..<5 {
            let dot = SKShapeNode(circleOfRadius: 1.6)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.alpha = 0.15
            dot.position = CGPoint(x: CGFloat(index - 2) * 5, y: index % 2 == 0 ? 7 : -5)
            node.addChild(dot)
            let twinkle = SKAction.sequence([
                .fadeAlpha(to: 0.95, duration: 0.35),
                .fadeAlpha(to: 0.12, duration: 0.45)
            ])
            dot.run(.sequence([.wait(forDuration: 0.12 * Double(index)), .repeatForever(twinkle)]))
        }
    }
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
    @State private var askingLeave = false
    @State private var finale: GameFinale?
    @State private var run = 1

    private var goal: Int { 30 + run * 15 }

    var body: some View {
        ZStack(alignment: .top) {
            PocketBackground(theme: "bg_hopper").ignoresSafeArea()
            SpriteView(scene: scene, options: [.allowsTransparency]).ignoresSafeArea()
            VStack(spacing: 8) {
                HStack {
                    CosmicCloseButton(label: "Leave Star Hopper") {
                        scene.isPaused = true
                        askingLeave = true
                    }
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
                HStack {
                    Button("Jet \(session.powerCount(.jet))") {
                        guard session.spendPower(.jet) else {
                            session.buyPower(.jet)
                            return
                        }
                        scene.boost()
                    }
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.85)))
                    .accessibilityLabel("Jet, \(session.powerCount(.jet)) charges")
                    Spacer()
                }
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
            if askingLeave {
                LeaveGamePrompt(onStay: {
                    askingLeave = false
                    if countdown == 0 { scene.isPaused = false }
                }, onLeave: {
                    presentEnd(score: score, detail: "You hopped away.")
                })
            }
            if let finale {
                GameEndCard(finale: finale, onAgain: { replay(next: false) }, onNext: { replay(next: true) }, onShop: {
                    session.openShopAfterGame = true
                    dismiss()
                }, onHome: { dismiss() })
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
            scene.wearJumper(PetStamp.texture(session: session, mood: .joyful))
            scene.onScore = { value in Task { @MainActor in score = value } }
            scene.onEnd = { final in
                Task { @MainActor in
                    presentEnd(score: final, detail: final >= goal ? "You reached the star." : "You slipped off the clouds.")
                }
            }
            if !showHowTo { startCountdown() }
        }
    }

    private func presentEnd(score: Int, detail: String) {
        guard finale == nil else { return }
        closed = true
        scene.isPaused = true
        finale = bankedFinale(session: session, title: "Star Hopper", score: score, detail: "Run \(run). \(detail)", gameID: MiniGame.starHopper.rawValue)
    }

    private func replay(next: Bool) {
        if next { run += 1 }
        closed = false
        countdown = 3
        finale = nil
        score = 0
        scene.restart()
        startCountdown()
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

struct CosmicPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(duration: 0.16), value: configuration.isPressed)
    }
}

struct CosmicCloseButton: View {
    var label: String = "Close"
    var action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white, Color(red: 0.73, green: 0.64, blue: 0.98)],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 32
                        )
                    )
                Circle().stroke(Color.white, lineWidth: 2)
                CloseMark()
                    .stroke(Color(red: 0.38, green: 0.26, blue: 0.62), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 16, height: 16)
            }
            .frame(width: 46, height: 46)
            .shadow(color: Color(red: 0.5, green: 0.35, blue: 0.9).opacity(0.55), radius: 8, y: 3)
        }
        .buttonStyle(CosmicPressStyle())
        .accessibilityLabel(label)
    }
}

struct CloseMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

@MainActor
func bankedFinale(session: PetSession, title: String, score: Int, stars: Int = 0, detail: String, gameID: String) -> GameFinale {
    let solo = session.record?.pet.isSleeping == true
    let reward = GameRewards.reward(points: max(0, score), solo: solo)
    let gems = session.record?.progress.gemPayout(base: reward.coins, now: session.currentDate) ?? reward.coins
    if score > 0 {
        session.finishGame(points: score, gameID: gameID, title: title, showPopup: false)
    }
    return GameFinale(title: title, score: score, gems: score > 0 ? gems : 0, xp: score > 0 ? reward.xp : 0, stars: stars, detail: detail)
}

struct GameFinale: Equatable {
    var title: String
    var score: Int
    var gems: Int
    var xp: Int
    var stars: Int
    var detail: String
}

struct GuestPet: View {
    var name: String
    var form: String

    var body: some View {
        PetCreatureView(
            stage: form == "egg" ? .egg : (AdultForm(rawValue: form) == nil ? .baby : .adult),
            mood: .joyful,
            form: AdultForm(rawValue: form),
            animates: true,
            accessibilityLabel: "\(name) is riding along"
        )
    }
}

struct RaisedPet: View {
    @EnvironmentObject private var session: PetSession
    var mood: PetMood = .joyful
    var side: CGFloat = 72
    var bounce: Bool = false

    var body: some View {
        if let pet = session.record?.pet {
            PetCreatureView(
                stage: pet.stage,
                mood: mood,
                form: pet.displayForm,
                tint: pet.trait?.tint,
                outfit: session.record?.progress.outfitID,
                shell: session.record?.progress.wardrobe.shell ?? "shell.plain",
                eyes: session.record?.progress.wardrobe.eyes ?? "eyes.round",
                antenna: session.record?.progress.wardrobe.antenna ?? "antenna.ball",
                marking: session.record?.progress.wardrobe.marking ?? "marking.none",
                level: session.level,
                animates: true,
                accessibilityLabel: pet.name
            )
            .frame(width: side, height: side)
            .scaleEffect(bounce ? 1.12 : 1)
            .offset(y: bounce ? -6 : 0)
            .animation(.spring(duration: 0.28), value: bounce)
        }
    }
}

enum PetStamp {
    @MainActor
    static func texture(session: PetSession, mood: PetMood) -> SKTexture {
        guard let pet = session.record?.pet else { return blank() }
        let progress = session.record?.progress
        let view = PetCreatureView(
            stage: pet.stage,
            mood: mood,
            form: pet.displayForm,
            tint: pet.trait?.tint,
            outfit: progress?.outfitID,
            shell: progress?.wardrobe.shell ?? "shell.plain",
            eyes: progress?.wardrobe.eyes ?? "eyes.round",
            antenna: progress?.wardrobe.antenna ?? "antenna.ball",
            marking: progress?.wardrobe.marking ?? "marking.none",
            level: LevelTable.level(for: progress?.xp ?? 0),
            animates: false,
            accessibilityLabel: pet.name
        )
        .frame(width: 120, height: 120)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.uiImage {
            return SKTexture(image: image)
        }
        return blank()
    }

    private static func blank() -> SKTexture {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
            UIColor(red: 0.73, green: 0.64, blue: 0.98, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 8, y: 8, width: 48, height: 48))
        }
        return SKTexture(image: image)
    }
}

struct GameEndCard: View {
    var finale: GameFinale
    var celebrate: Bool = false
    var onAgain: () -> Void
    var onNext: () -> Void
    var onShop: () -> Void
    var onHome: () -> Void
    var extraTitle: String? = nil
    var onExtra: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            if celebrate {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        for index in 0..<28 {
                            let x = CGFloat((index * 47) % 100) / 100 * size.width
                            let y = CGFloat((time * 80 + Double(index * 30)).truncatingRemainder(dividingBy: Double(size.height)))
                            let rect = CGRect(x: x, y: y, width: 8, height: 8)
                            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 1, green: 0.8, blue: 0.4).opacity(0.85)))
                        }
                    }
                }
                .allowsHitTesting(false)
            }
            VStack(spacing: 12) {
                RaisedPet(mood: .joyful, side: 88, bounce: celebrate)
                Text(finale.title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text(finale.detail)
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("\(finale.score)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .accessibilityLabel("Score \(finale.score)")
                if finale.stars > 0 {
                    Text(String(repeating: "★", count: finale.stars))
                        .font(.system(.title2, design: .rounded))
                        .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.3))
                }
                HStack(spacing: 10) {
                    ChipFace(chip: CareChip(stat: .gems, amount: finale.gems), side: 22)
                    Text("+\(finale.xp) XP")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        endButton("Play again", action: onAgain)
                        endButton("Next level", action: onNext)
                    }
                    HStack(spacing: 8) {
                        endButton("Shop", action: onShop)
                        endButton("Home", action: onHome)
                    }
                    if let extraTitle, let onExtra {
                        endButton(extraTitle, action: onExtra)
                    }
                }
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(red: 0.97, green: 0.94, blue: 1)))
            .padding(24)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func endButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Capsule().fill(Color(red: 0.55, green: 0.42, blue: 0.86)))
            .foregroundStyle(.white)
    }
}

struct LeaveGamePrompt: View {
    var onStay: () -> Void
    var onLeave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Leave game?")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("You can keep what you scored, or stay and play on.")
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button("Stay", action: onStay)
                    Button("Leave", action: onLeave)
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

struct HowToOverlay: View {
    var title: String
    var pages: [String]
    var onDone: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
            CosmicCloseButton(label: "Close how to play", action: onDone)
                .padding(.trailing, 16)
                .padding(.top, 8)
        }
        .accessibilityAddTraits(.isModal)
    }
}

final class SnackBoardScene: SKScene {
    var onSwap: ((Int, Int) -> Void)?
    var onTap: ((Int) -> Void)?
    private let columns = 8
    private let rows = 8
    private var gems: [SKNode] = []
    private(set) var busy = false
    private var touchStart: Int?

    func load(_ cells: [Int]) {
        removeAllChildren()
        gems = cells.indices.map { makeGem(cells[$0], at: $0) }
        gems.forEach { addChild($0) }
        backgroundColor = .clear
    }

    func glow(_ indexes: [Int]) {
        for (index, node) in gems.enumerated() {
            node.run(.fadeAlpha(to: indexes.contains(index) ? 1 : 0.55, duration: 0.2))
        }
    }

    func animate(from start: Int, to end: Int, accepted: Bool, steps: [SnackMatch.SnackStep], final: [Int], done: @escaping () -> Void) {
        guard gems.indices.contains(start), gems.indices.contains(end) else { done(); return }
        busy = true
        let first = gems[start]
        let second = gems[end]
        let origin = first.position
        let destination = second.position
        let slide = SKAction.move(to: destination, duration: 0.2)
        slide.timingMode = .easeOut
        let back = SKAction.move(to: origin, duration: 0.18)
        back.timingMode = .easeOut
        first.zPosition = 2
        second.run(.move(to: origin, duration: 0.2))
        first.run(slide) { [weak self] in
            guard let self else { return }
            if !accepted {
                first.run(back)
                second.run(.move(to: destination, duration: 0.18)) { [weak self] in
                    self?.busy = false
                    done()
                }
                return
            }
            self.gems.swapAt(start, end)
            self.play(steps: steps, final: final, done: done)
        }
    }

    private func play(steps: [SnackMatch.SnackStep], final: [Int], done: @escaping () -> Void) {
        var sequence: [SKAction] = []
        for step in steps {
            sequence.append(.run { [weak self] in self?.pop(step.cleared) })
            sequence.append(.wait(forDuration: 0.22))
            sequence.append(.run { [weak self] in self?.drop(into: step.cells) })
            sequence.append(.wait(forDuration: 0.28))
        }
        sequence.append(.run { [weak self] in
            self?.load(final)
            self?.busy = false
            done()
        })
        run(.sequence(sequence))
    }

    private func pop(_ indexes: [Int]) {
        for index in indexes where gems.indices.contains(index) {
            let node = gems[index]
            let spark = SKShapeNode(circleOfRadius: 4)
            spark.fillColor = .white
            spark.position = node.position
            addChild(spark)
            spark.run(.sequence([.group([.scale(to: 2.4, duration: 0.2), .fadeOut(withDuration: 0.2), .moveBy(x: 0, y: 70, duration: 0.2)]), .removeFromParent()]))
            node.run(.sequence([
                .group([
                    .scale(to: 1.35, duration: 0.12),
                    .moveBy(x: 0, y: 90, duration: 0.2),
                    .fadeOut(withDuration: 0.2)
                ]),
                .removeFromParent()
            ]))
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func drop(into cells: [Int]) {
        removeChildren(in: gems)
        gems = []
        for index in cells.indices {
            let gem = makeGem(cells[index], at: index)
            let landing = gem.position
            gem.position.y = landing.y + cellSize * 1.4
            gem.setScale(0.8)
            addChild(gem)
            let fall = SKAction.move(to: landing, duration: 0.22 + Double(index / columns) * 0.02)
            fall.timingMode = .easeOut
            gem.run(.sequence([fall, .scale(to: 1.08, duration: 0.06), .scale(to: 1, duration: 0.06)]))
            gems.append(gem)
        }
    }

    private var cellSize: CGFloat {
        min(size.width, size.height) / CGFloat(columns)
    }

    private func point(for index: Int) -> CGPoint {
        let side = cellSize
        let col = index % columns
        let row = index / columns
        return CGPoint(
            x: side * (CGFloat(col) + 0.5),
            y: size.height - side * (CGFloat(row) + 0.5)
        )
    }

    private func makeGem(_ tile: Int, at index: Int) -> SKNode {
        let hue = SnackMatch.hue(of: tile)
        let names = [GameArt.gemStar, GameArt.gemMoon, GameArt.gemPlanet, GameArt.gemComet, GameArt.gemDonut]
        let special = SnackMatch.isBomb(tile) ? GameArt.gemStarbomb : (SnackMatch.isStripe(tile) ? GameArt.gemLineblast : names[hue % names.count])
        let node: SKNode
        if let texture = SpriteArt.texture(special) {
            let sprite = SKSpriteNode(texture: texture)
            let side = cellSize * 0.86
            sprite.size = CGSize(width: side, height: side)
            if special == GameArt.gemStarbomb {
                addBoardSparkle(to: sprite)
            }
            node = sprite
        } else {
            let shape = SKShapeNode(circleOfRadius: cellSize * 0.38)
            let colors: [SKColor] = [
                SKColor(red: 1, green: 0.55, blue: 0.7, alpha: 1),
                SKColor(red: 1, green: 0.82, blue: 0.35, alpha: 1),
                SKColor(red: 0.55, green: 0.75, blue: 1, alpha: 1),
                SKColor(red: 0.72, green: 0.55, blue: 0.98, alpha: 1),
                SKColor(red: 0.55, green: 0.9, blue: 0.75, alpha: 1)
            ]
            shape.fillColor = colors[hue % colors.count]
            shape.strokeColor = .white
            shape.lineWidth = 2
            node = shape
        }
        node.position = point(for: index)
        node.name = "\(index)"
        return node
    }

    private func addBoardSparkle(to node: SKNode) {
        for index in 0..<6 {
            let dot = SKShapeNode(circleOfRadius: 1.4)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.alpha = 0.2
            let angle = CGFloat(index) / 6 * .pi * 2
            dot.position = CGPoint(x: cos(angle) * 12, y: sin(angle) * 12)
            node.addChild(dot)
            let twinkle = SKAction.sequence([
                .fadeAlpha(to: 1, duration: 0.28),
                .fadeAlpha(to: 0.15, duration: 0.4)
            ])
            dot.run(.sequence([.wait(forDuration: 0.08 * Double(index)), .repeatForever(twinkle)]))
        }
    }

    private func index(at point: CGPoint) -> Int? {
        let side = cellSize
        let col = Int(point.x / side)
        let row = Int((size.height - point.y) / side)
        guard col >= 0, col < columns, row >= 0, row < rows else { return nil }
        return row * columns + col
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !busy, let point = touches.first?.location(in: self) else { return }
        touchStart = index(at: point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !busy, let start = touchStart, let point = touches.first?.location(in: self), let end = index(at: point) else { return }
        touchStart = nil
        if start == end {
            onTap?(start)
        } else if SnackMatch.areNeighbors(start, end, width: columns) {
            onSwap?(start, end)
        }
    }
}

@MainActor
final class SnackTable: ObservableObject {
    @Published var cells: [Int]
    @Published var score = 0
    @Published var moves = 22
    @Published var banner = ""
    @Published var finished = false
    @Published var armed: PowerUpKind?
    let board = SnackBoardScene(size: CGSize(width: 360, height: 360))
    private let columns = 8
    private let rows = 8
    private let goal = 500
    private var idle = Date()
    private var hint: (Int, Int)?

    init() {
        cells = (0..<64).map { _ in Int.random(in: 0..<SnackMatch.kinds) }
        board.scaleMode = .resizeFill
        board.onSwap = { [weak self] a, b in self?.trySwap(a, b) }
        board.onTap = { [weak self] index in self?.tap(index) }
    }

    func start() {
        cells = SnackMatch.reshuffled(cells, width: columns, height: rows, seed: UInt64.random(in: 1...90_000))
        board.load(cells)
        idle = Date()
    }

    func restart() {
        score = 0
        moves = 22
        finished = false
        banner = ""
        armed = nil
        board.isPaused = false
        start()
    }

    func nudgeHint() {
        guard !finished, !board.busy, Date().timeIntervalSince(idle) > 5 else { return }
        hint = SnackMatch.hint(in: cells, width: columns, height: rows)
        board.glow(hint.map { [$0.0, $0.1] } ?? [])
        if hint == nil {
            cells = SnackMatch.reshuffled(cells, width: columns, height: rows, seed: UInt64.random(in: 1...90_000))
            board.load(cells)
            banner = "Reshuffle"
            idle = Date()
        }
    }

    func trySwap(_ a: Int, _ b: Int) {
        guard !finished, !board.busy, cells.indices.contains(a), cells.indices.contains(b) else { return }
        idle = Date()
        hint = nil
        if let outcome = SnackMatch.swapAndResolve(cells: cells, width: columns, height: rows, a: a, b: b, refill: { Int.random(in: 0..<SnackMatch.kinds) }) {
            board.animate(from: a, to: b, accepted: true, steps: outcome.steps, final: outcome.cells) { [weak self] in
                Task { @MainActor in self?.apply(outcome) }
            }
        } else {
            board.animate(from: a, to: b, accepted: false, steps: [], final: cells) {}
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    func tap(_ index: Int) {
        guard !finished, cells.indices.contains(index) else { return }
        if armed == .hammer {
            guard let outcome = SnackMatch.smash(cells: cells, width: columns, height: rows, index: index, refill: { Int.random(in: 0..<SnackMatch.kinds) }) else { return }
            armed = nil
            board.animate(from: index, to: index, accepted: true, steps: outcome.steps, final: outcome.cells) { [weak self] in
                self?.apply(outcome, spentMove: false)
            }
        } else if armed == .colorBomb {
            guard let outcome = SnackMatch.clearColor(cells: cells, width: columns, height: rows, hue: SnackMatch.hue(of: cells[index]), refill: { Int.random(in: 0..<SnackMatch.kinds) }) else { return }
            armed = nil
            apply(outcome, spentMove: false)
            board.load(cells)
        }
    }

    func useTool(_ kind: PowerUpKind, session: PetSession) {
        switch kind {
        case .hammer, .colorBomb:
            if session.powerCount(kind) == 0 {
                session.buyPower(kind)
                return
            }
            guard session.spendPower(kind) else { return }
            armed = armed == kind ? nil : kind
        case .shuffle:
            guard session.spendPower(.shuffle) else {
                session.buyPower(.shuffle)
                return
            }
            cells = SnackMatch.reshuffled(cells, width: columns, height: rows, seed: UInt64.random(in: 1...90_000))
            board.load(cells)
            banner = "Shuffled"
        case .extraMoves:
            guard session.spendPower(.extraMoves) else {
                session.buyPower(.extraMoves)
                return
            }
            moves += 5
            banner = "+5 moves"
        case .blast, .jet:
            break
        }
        idle = Date()
    }

    private func apply(_ outcome: SnackMatch.Outcome, spentMove: Bool = true) {
        cells = outcome.cells
        score += outcome.points
        if spentMove { moves -= 1 }
        if outcome.madeBomb {
            banner = "Star bomb"
        } else if outcome.madeStripe {
            banner = "Line blast"
        } else if outcome.cascades > 1 {
            banner = "Combo \(outcome.cascades)"
        }
        UIImpactFeedbackGenerator(style: outcome.cascades > 1 ? .medium : .light).impactOccurred()
        if outcome.points > 0 { PocketSound.shared.match() } else { PocketSound.shared.tap() }
        idle = Date()
        if score >= 220 || moves <= 0 { finished = true }
    }
}

struct SnackMatchGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var table = SnackTable()
    @State private var showHowTo = !UserDefaults.standard.bool(forKey: "howto.snackMatch")
    @State private var closed = false
    @State private var askingLeave = false
    @State private var finale: GameFinale?
    @State private var celebrate = false

    private let goal = 220

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                CosmicCloseButton(label: "Leave Snack Match") {
                    table.board.isPaused = true
                    askingLeave = true
                }
                Button("?") { showHowTo = true }
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.8)))
                    .accessibilityLabel("How to play Snack Match")
                Spacer()
                Text("\(table.moves)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .accessibilityLabel("\(table.moves) moves left")
            }
            GoalMeter(title: "\(min(table.score, goal))/\(goal)", fraction: Double(table.score) / Double(goal), ink: .primary)
            HStack(spacing: 8) {
                RaisedPet(
                    mood: table.banner.contains("Combo") ? .joyful : .content,
                    side: 64,
                    bounce: table.banner.contains("Combo") || table.banner == "Star bomb"
                )
                if !table.banner.isEmpty {
                    Text(table.banner)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(red: 0.45, green: 0.3, blue: 0.75))
                }
                Spacer()
            }
            SpriteView(scene: table.board, options: [.allowsTransparency])
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            HStack(spacing: 8) {
                tool(.hammer, "Hammer")
                tool(.shuffle, "Shuffle")
                tool(.colorBomb, "Color")
                tool(.extraMoves, "+5")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketBackground(theme: "bg_match").ignoresSafeArea())
        .onAppear { table.start() }
        .onChange(of: table.finished) { _, done in
            if done { presentEnd() }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !showHowTo else { continue }
                table.nudgeHint()
            }
        }
        .overlay {
            if askingLeave {
                LeaveGamePrompt(onStay: {
                    askingLeave = false
                    table.board.isPaused = false
                }, onLeave: {
                    table.board.isPaused = true
                    presentEnd(detail: "You left the board.")
                })
            }
            if let finale {
                GameEndCard(finale: finale, celebrate: celebrate, onAgain: {
                    self.finale = nil
                    celebrate = false
                    closed = false
                    table.restart()
                }, onNext: {
                    self.finale = nil
                    closed = false
                    table.restart()
                }, onShop: {
                    session.openShopAfterGame = true
                    dismiss()
                }, onHome: { dismiss() })
            }
            if showHowTo {
                HowToOverlay(
                    title: "Snack Match",
                    pages: [
                        "Drag a gem into a neighbor. The swap stays, even with no match.",
                        "Matches pop and fly up. The gems above fall in with a bounce.",
                        "Fill the star meter before your moves run out."
                    ],
                    onDone: {
                        UserDefaults.standard.set(true, forKey: "howto.snackMatch")
                        showHowTo = false
                    }
                )
            }
        }
    }

    private func tool(_ kind: PowerUpKind, _ title: String) -> some View {
        Button {
            table.useTool(kind, session: session)
        } label: {
            VStack(spacing: 2) {
                Text(title)
                Text("\(session.powerCount(kind))")
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(table.armed == kind ? Color(red: 1, green: 0.84, blue: 0.4) : Color.white.opacity(0.7))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(session.powerCount(kind)) charges")
    }

    private func presentEnd(detail: String = "The board is done.") {
        guard finale == nil else { return }
        closed = true
        table.board.isPaused = true
        finale = bankedFinale(session: session, title: "Snack Match", score: table.score, detail: detail, gameID: MiniGame.snackMatch.rawValue)
        celebrate = table.score >= goal
    }
}

struct CosmicSolitaireGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var map: CosmicSolitaire.Level?
    @State private var deal = SolitaireDeal.deal(seed: 1, drawCount: 1)
    @State private var history: [SolitaireDeal] = []
    @State private var moves = 0
    @State private var selection: SolitaireDeal.Move?
    @State private var showHowTo = !UserDefaults.standard.bool(forKey: "howto.solitaire")
    @State private var askingLeave = false
    @State private var closed = false
    @State private var finale: GameFinale?

    var body: some View {
        ZStack {
            PocketBackground(theme: "bg_shop").ignoresSafeArea()
            if let map {
                table(map)
            } else {
                levelList
            }
            VStack {
                Spacer()
                HStack {
                    RaisedPet(mood: moves > 0 ? .joyful : .content, side: 64, bounce: moves > 0)
                    Spacer()
                }
            }
            .padding()
            .allowsHitTesting(false)
            if askingLeave {
                LeaveGamePrompt(onStay: { askingLeave = false }, onLeave: leave)
            }
            if let finale {
                GameEndCard(finale: finale, onAgain: { replaySolitaire(next: false) }, onNext: { replaySolitaire(next: true) }, onShop: {
                    session.openShopAfterGame = true
                    dismiss()
                }, onHome: { dismiss() })
            }
            if showHowTo {
                HowToOverlay(
                    title: "Cosmic Solitaire",
                    pages: [
                        "Tap the deck to draw. Tap a card, then where it should go.",
                        "Build down in alternating colors. Foundations build up by suit from the ace.",
                        "Undo a mistake or ask for a hint. Clear the board to win."
                    ],
                    onDone: {
                        UserDefaults.standard.set(true, forKey: "howto.solitaire")
                        showHowTo = false
                    }
                )
            }
        }
    }

    private var levelList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CosmicCloseButton(label: "Leave Cosmic Solitaire") { dismiss() }
                Text("Cosmic Solitaire")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Spacer()
                Button("?") { showHowTo = true }.font(.system(.headline, design: .rounded).weight(.bold))
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(CosmicSolitaire.levels) { level in
                        let stars = session.record?.progress.bestScores["solitaire.level.\(level.id)"] ?? 0
                        let open = CosmicSolitaire.isOpen(level: level.id, petLevel: session.level, stars: starMap)
                        Button {
                            guard open else { return }
                            self.map = level
                            deal = SolitaireDeal.deal(seed: level.seed, drawCount: level.drawCount)
                            history = []
                            moves = 0
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(level.name).font(.system(.headline, design: .rounded))
                                    Text(open ? "Draw \(level.drawCount) · \(stars) stars" : "Lv \(level.unlockLevel)")
                                        .font(.system(.caption, design: .rounded))
                                }
                                Spacer()
                                Text(open ? "Play" : "Locked").font(.system(.caption, design: .rounded).weight(.bold))
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(open ? 0.62 : 0.28)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!open)
                    }
                }
            }
        }
        .padding(16)
    }

    private func table(_ level: CosmicSolitaire.Level) -> some View {
        VStack(spacing: 8) {
            HStack {
                CosmicCloseButton(label: "Leave Cosmic Solitaire") { askingLeave = true }
                Text("Moves \(moves)").font(.system(.headline, design: .rounded).weight(.bold))
                Spacer()
                Button("Undo") { undo() }.disabled(history.isEmpty)
                Button("Hint") { applyHint() }
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            HStack(spacing: 8) {
                Button { play(.draw) } label: { cardBack.overlay(Text("\(deal.stock.count)").font(.caption.bold())) }
                cardView(deal.waste.last, selected: false).onTapGesture { play(.wasteToFoundation) }
                Spacer()
                ForEach(0..<4, id: \.self) { index in
                    cardView(deal.foundations[index].last, selected: false)
                        .onTapGesture { tryFoundationOrWaste(index) }
                }
            }
            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<7, id: \.self) { pile in
                    VStack(spacing: 2) {
                        if deal.tableau[pile].isEmpty {
                            RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.4)).frame(width: 42, height: 58)
                                .onTapGesture { dropOnTableau(pile) }
                        }
                        ForEach(Array(deal.tableau[pile].enumerated()), id: \.element.id) { index, card in
                            cardView(card, selected: isSelected(pile: pile, index: index))
                                .onTapGesture { tapTableau(pile, index) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Button("Maps") { self.map = nil }.font(.system(.caption, design: .rounded).weight(.bold))
            Text(level.name).font(.system(.caption, design: .rounded))
        }
        .padding(12)
    }

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(red: 0.45, green: 0.32, blue: 0.75))
            .frame(width: 42, height: 58)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 1))
    }

    private func cardView(_ card: CosmicCard?, selected: Bool) -> some View {
        Group {
            if let card, card.faceUp {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        Text(label(card))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(card.suit.isRed ? Color.red : Color(red: 0.2, green: 0.15, blue: 0.35))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color.yellow : Color.white, lineWidth: selected ? 3 : 1))
            } else if card != nil {
                cardBack
            } else {
                RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.35)).frame(width: 42, height: 58)
            }
        }
        .frame(width: 42, height: 58)
    }

    private func label(_ card: CosmicCard) -> String {
        let rank: String
        switch card.rank {
        case 1: rank = "A"
        case 11: rank = "J"
        case 12: rank = "Q"
        case 13: rank = "K"
        default: rank = "\(card.rank)"
        }
        let mark = ["★", "☾", "☄", "◆"][card.suit.rawValue]
        return "\(rank)\(mark)"
    }

    private func isSelected(pile: Int, index: Int) -> Bool {
        guard case let .tableauToTableau(from, _, count) = selection else { return false }
        return from == pile && index >= deal.tableau[pile].count - count
    }

    private func tapTableau(_ pile: Int, _ index: Int) {
        let cards = deal.tableau[pile]
        guard cards.indices.contains(index), cards[index].faceUp else { return }
        if selection != nil {
            dropOnTableau(pile)
            return
        }
        let count = cards.count - index
        let run = Array(cards.suffix(count))
        guard SolitaireDeal.isRun(run) else { return }
        selection = .tableauToTableau(from: pile, to: pile, count: count)
        if let moved = deal.applying(.tableauToFoundation(pile: pile)), count == 1 {
            selection = nil
            play(.tableauToFoundation(pile: pile))
            _ = moved
        }
    }

    private func dropOnTableau(_ pile: Int) {
        if case let .tableauToTableau(from, _, count) = selection {
            play(.tableauToTableau(from: from, to: pile, count: count))
        } else if deal.waste.last != nil {
            play(.wasteToTableau(pile))
        }
        selection = nil
    }

    private func tryFoundationOrWaste(_ suit: Int) {
        if case .tableauToTableau = selection {
            if case let .tableauToTableau(from, _, _) = selection {
                play(.tableauToFoundation(pile: from))
            }
        } else {
            play(.wasteToFoundation)
        }
        selection = nil
        _ = suit
    }

    private func play(_ move: SolitaireDeal.Move) {
        guard let next = deal.applying(move) else {
            selection = nil
            return
        }
        history.append(deal)
        deal = next
        moves += 1
        selection = nil
        if deal.won, let map {
            let stars = CosmicSolitaire.stars(moves: moves, won: true)
            session.recordStars(id: "solitaire.level.\(map.id)", stars: stars)
            let points = stars * 35 + max(0, 80 - moves)
            finale = bankedFinale(session: session, title: "Cosmic Solitaire", score: points, stars: stars, detail: "Board cleared in \(moves) moves.", gameID: MiniGame.cosmicSolitaire.rawValue)
        }
    }

    private func replaySolitaire(next: Bool) {
        guard let map else { return }
        let nextID = next ? min(map.id + 1, CosmicSolitaire.levels.count) : map.id
        let level = CosmicSolitaire.levels.first { $0.id == nextID } ?? map
        self.map = level
        deal = SolitaireDeal.deal(seed: level.seed, drawCount: level.drawCount)
        history = []
        moves = 0
        selection = nil
        closed = false
        finale = nil
    }

    private func undo() {
        guard let previous = history.popLast() else { return }
        deal = previous
        moves = max(0, moves - 1)
        selection = nil
    }

    private func applyHint() {
        if let move = deal.hint() { play(move) }
    }

    private var starMap: [Int: Int] {
        var map: [Int: Int] = [:]
        for level in CosmicSolitaire.levels {
            map[level.id] = session.record?.progress.bestScores["solitaire.level.\(level.id)"] ?? 0
        }
        return map
    }

    private func leave() {
        guard finale == nil else { return }
        closed = true
        let points = moves > 0 ? min(12, moves / 4) : 0
        finale = bankedFinale(session: session, title: "Cosmic Solitaire", score: points, detail: "You left the table.", gameID: MiniGame.cosmicSolitaire.rawValue)
    }
}

struct StarSudokuGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var difficulty: SudokuDifficulty?
    @State private var puzzle = SudokuPuzzle(given: Array(repeating: 0, count: 81), solution: Array(repeating: 0, count: 81))
    @State private var cells = Array(repeating: 0, count: 81)
    @State private var notes: [Int: Set<Int>] = [:]
    @State private var selected: Int?
    @State private var noteMode = false
    @State private var mistakes = 0
    @State private var hints = 0
    @State private var history: [[Int]] = []
    @State private var started = Date()
    @State private var showHowTo = !UserDefaults.standard.bool(forKey: "howto.sudoku")
    @State private var askingLeave = false
    @State private var closed = false
    @State private var finale: GameFinale?

    var body: some View {
        ZStack {
            PocketBackground(theme: "bg_match").ignoresSafeArea()
            if difficulty == nil {
                menu
            } else {
                board
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RaisedPet(mood: mistakes > 0 ? .sad : .joyful, side: 64, bounce: mistakes == 0 && selected != nil)
                }
            }
            .padding()
            .allowsHitTesting(false)
            if askingLeave {
                LeaveGamePrompt(onStay: { askingLeave = false }, onLeave: leave)
            }
            if let finale {
                GameEndCard(finale: finale, onAgain: { replaySudoku(next: false) }, onNext: { replaySudoku(next: true) }, onShop: {
                    session.openShopAfterGame = true
                    dismiss()
                }, onHome: { dismiss() })
            }
            if showHowTo {
                HowToOverlay(
                    title: "Star Sudoku",
                    pages: [
                        "Each row, column, and box holds the digits 1 through 9 once.",
                        "Tap a cell, then a number. Notes mode pencils in guesses.",
                        "A hint fills one cell. A clean board with no hints earns three stars."
                    ],
                    onDone: {
                        UserDefaults.standard.set(true, forKey: "howto.sudoku")
                        showHowTo = false
                    }
                )
            }
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CosmicCloseButton(label: "Leave Star Sudoku") { dismiss() }
                Text("Star Sudoku").font(.system(.title2, design: .rounded).weight(.bold))
                Spacer()
                Button("?") { showHowTo = true }.font(.system(.headline, design: .rounded).weight(.bold))
            }
            ForEach(SudokuDifficulty.allCases, id: \.self) { level in
                let open = StarSudoku.isOpen(level, petLevel: session.level, cleared: cleared)
                Button {
                    guard open else { return }
                    let made = SudokuPuzzle.generate(seed: UInt64.random(in: 1...9_000), difficulty: level)
                    puzzle = made
                    cells = made.given
                    notes = [:]
                    mistakes = 0
                    hints = 0
                    history = []
                    started = Date()
                    difficulty = level
                } label: {
                    HStack {
                        Text(level.rawValue.capitalized).font(.system(.headline, design: .rounded))
                        Spacer()
                        Text(open ? "Lv \(level.unlockLevel)" : "Locked Lv \(level.unlockLevel)")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(open ? 0.62 : 0.28)))
                }
                .buttonStyle(.plain)
                .disabled(!open)
            }
        }
        .padding(16)
    }

    private var board: some View {
        VStack(spacing: 10) {
            HStack {
                CosmicCloseButton(label: "Leave Star Sudoku") { askingLeave = true }
                Text(difficulty?.rawValue.capitalized ?? "")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Spacer()
                Text("\(mistakes) slips")
                    .font(.system(.caption, design: .rounded).weight(.bold))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 9), spacing: 2) {
                ForEach(0..<81, id: \.self) { index in
                    let given = puzzle.given[index] != 0
                    let wrong = cells[index] != 0 && cells[index] != puzzle.solution[index]
                    Button {
                        selected = index
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selected == index ? Color(red: 1, green: 0.9, blue: 0.6) : Color.white.opacity(0.8))
                            if cells[index] != 0 {
                                Text("\(cells[index])")
                                    .font(.system(.title3, design: .rounded).weight(given ? .bold : .regular))
                                    .foregroundStyle(wrong ? Color.red : Color(red: 0.25, green: 0.18, blue: 0.4))
                            } else if let marks = notes[index], !marks.isEmpty {
                                Text(marks.sorted().map(String.init).joined(separator: " "))
                                    .font(.system(size: 8, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 34)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: index % 3 == 0 ? 2 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(given)
                }
            }
            HStack {
                ForEach(1...9, id: \.self) { number in
                    Button("\(number)") { enter(number) }
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Circle().fill(Color.white.opacity(0.7)))
                }
            }
            HStack {
                Button(noteMode ? "Notes on" : "Notes") { noteMode.toggle() }
                Button("Erase") { enter(0) }
                Button("Undo") { undo() }.disabled(history.isEmpty)
                Button("Hint") { hint() }
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            Button("Difficulties") { difficulty = nil }
                .font(.system(.caption, design: .rounded).weight(.bold))
        }
        .padding(12)
    }

    private var cleared: Set<String> {
        var set: Set<String> = []
        for level in SudokuDifficulty.allCases where (session.record?.progress.bestScores["sudoku.\(level.rawValue)"] ?? 0) > 0 {
            set.insert(level.rawValue)
        }
        return set
    }

    private func enter(_ number: Int) {
        guard let selected, puzzle.given[selected] == 0 else { return }
        history.append(cells)
        if noteMode, number != 0 {
            var marks = notes[selected] ?? []
            if marks.contains(number) { marks.remove(number) } else { marks.insert(number) }
            notes[selected] = marks
            return
        }
        cells[selected] = number
        notes[selected] = nil
        if number != 0, number != puzzle.solution[selected] {
            mistakes += 1
        }
        if cells == puzzle.solution, let difficulty {
            let stars = StarSudoku.stars(mistakes: mistakes, hints: hints, solved: true)
            session.recordStars(id: "sudoku.\(difficulty.rawValue)", stars: stars)
            let points = stars * 30 + max(0, 40 - mistakes * 5)
            finale = bankedFinale(session: session, title: "Star Sudoku", score: points, stars: stars, detail: "\(difficulty.rawValue.capitalized) cleared.", gameID: MiniGame.starSudoku.rawValue)
        }
    }

    private func replaySudoku(next: Bool) {
        guard let difficulty else { return }
        let order = SudokuDifficulty.allCases
        let index = order.firstIndex(of: difficulty) ?? 0
        let picked = next ? order[min(index + 1, order.count - 1)] : difficulty
        let made = SudokuPuzzle.generate(seed: UInt64.random(in: 1...9_000), difficulty: picked)
        puzzle = made
        cells = made.given
        notes = [:]
        mistakes = 0
        hints = 0
        history = []
        started = Date()
        self.difficulty = picked
        closed = false
        finale = nil
    }

    private func undo() {
        guard let previous = history.popLast() else { return }
        cells = previous
    }

    private func hint() {
        guard let index = cells.indices.first(where: { cells[$0] == 0 }) else { return }
        history.append(cells)
        cells[index] = puzzle.solution[index]
        hints += 1
        notes[index] = nil
    }

    private func leave() {
        guard finale == nil else { return }
        closed = true
        let filled = cells.filter { $0 != 0 }.count - puzzle.given.filter { $0 != 0 }.count
        let points = filled > 0 ? min(10, filled / 3) : 0
        finale = bankedFinale(session: session, title: "Star Sudoku", score: points, detail: "You left the grid.", gameID: MiniGame.starSudoku.rawValue)
    }
}

struct VisitSheet: View {
    var card: String
    var onSave: (String) -> Void
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @State private var pasted = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let pet = session.record?.pet {
                    let mine = PetCard.text(name: pet.name, form: pet.displayForm?.rawValue ?? pet.stage.rawValue, level: session.level)
                    Text(mine)
                        .font(.system(.caption, design: .rounded))
                        .textSelection(.enabled)
                    if let image = VisitCode.image(for: mine) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 180, height: 180)
                            .accessibilityLabel("QR code for \(pet.name)")
                    }
                    ShareLink(item: mine) {
                        Text("Share with AirDrop")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                    }
                }
                TextField("Paste a friend's card", text: $pasted)
                    .textFieldStyle(.roundedBorder)
                Button("Show this visitor") {
                    if PetCard.parse(pasted) != nil {
                        onSave(pasted)
                        dismiss()
                    }
                }
                .font(.system(.headline, design: .rounded).weight(.bold))
                if !card.isEmpty {
                    Button("Send the visitor home") {
                        onSave("")
                        dismiss()
                    }
                }
            }
            .padding()
            .navigationTitle("Pet visit")
            .toolbar {
                Button("Close") { dismiss() }
            }
        }
    }
}

enum VisitCode {
    static func image(for text: String) -> UIImage? {
        guard let data = text.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return UIImage(ciImage: scaled)
    }
}

struct StickPad: View {
    @Binding var stick: CGSize

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.35))
            .frame(width: 120, height: 120)
            .overlay {
                Circle()
                    .fill(Color.white)
                    .frame(width: 48, height: 48)
                    .offset(stick)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let limited = CGSize(
                            width: min(36, max(-36, value.translation.width)),
                            height: min(36, max(-36, value.translation.height))
                        )
                        stick = limited
                    }
                    .onEnded { _ in stick = .zero }
            )
            .accessibilityLabel("Joystick")
    }
}

struct ShipDuoGame: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var link = ShipLink()
    @State private var run = ShipRun()
    @State private var stick = CGSize.zero
    @State private var last = Date()
    @State private var finale: GameFinale?
    @State private var banked = false

    var body: some View {
        ZStack {
            PocketBackground(theme: "bg_hopper").ignoresSafeArea()
            course
            VStack {
                HStack {
                    CosmicCloseButton(label: "Leave Ship Duo") { presentEnd(detail: "You docked the ship.") }
                    Text("Level \(run.level)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(link.status)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack {
                    StickPad(stick: $stick)
                    Spacer()
                    VStack(spacing: 8) {
                        Button("Practice") { link.stop(); link.status = "Practice" }
                        Button("Host") { link.host() }
                        Button("Join") { link.join() }
                    }
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            if let finale {
                GameEndCard(
                    finale: finale,
                    onAgain: { replay() },
                    onNext: { replay() },
                    onShop: {
                        session.openShopAfterGame = true
                        dismiss()
                    },
                    onHome: { dismiss() }
                )
            }
        }
        .onAppear {
            last = Date()
            if let pet = session.record?.pet {
                link.greet(PetCard.text(name: pet.name, form: pet.displayForm?.rawValue ?? pet.stage.rawValue, level: session.level))
            }
        }
        .onChange(of: link.status) { _, status in
            guard status == "Together", let pet = session.record?.pet else { return }
            link.greet(PetCard.text(name: pet.name, form: pet.displayForm?.rawValue ?? pet.stage.rawValue, level: session.level))
        }
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { date in
            guard finale == nil else { return }
            let dt = min(0.05, date.timeIntervalSince(last))
            last = date
            let mine = (Double(stick.width / 36), Double(-stick.height / 36))
            let theirs = (Double(link.remote.width), Double(link.remote.height))
            link.send(x: mine.0, y: mine.1)
            run = ShipCourse.step(run, left: mine, right: theirs, dt: dt)
            if run.level >= 4 {
                presentEnd(detail: "You flew through three doors.")
            }
        }
    }

    private var course: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height * 0.72)
            func place(_ across: Double, _ along: Double) -> CGPoint {
                CGPoint(x: center.x + across, y: center.y - (along - run.y))
            }
            for gate in ShipCourse.checkpoints {
                let point = place(0, gate)
                let line = Path(CGRect(x: 24, y: point.y, width: size.width - 48, height: 4))
                context.fill(line, with: .color(.white.opacity(0.7)))
            }
            for rock in ShipCourse.obstacles(level: run.level) {
                let point = place(rock.0, rock.1)
                context.fill(Path(ellipseIn: CGRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32)), with: .color(Color(red: 0.95, green: 0.55, blue: 0.45)))
            }
            let door = place(0, ShipCourse.length)
            context.fill(Path(roundedRect: CGRect(x: size.width / 2 - 28, y: door.y, width: 56, height: 70), cornerRadius: 12), with: .color(Color(red: 0.55, green: 0.85, blue: 0.7)))
            context.fill(Path(ellipseIn: CGRect(x: center.x + run.x - 18, y: center.y - 14, width: 36, height: 28)), with: .color(Color(red: 0.75, green: 0.65, blue: 0.98)))
        }
        .overlay {
            HStack(spacing: 2) {
                RaisedPet(side: 46, bounce: stick != .zero)
                if !link.remoteName.isEmpty {
                    GuestPet(name: link.remoteName, form: link.remoteForm)
                        .frame(width: 46, height: 46)
                }
            }
            .offset(y: 70)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func presentEnd(detail: String) {
        guard finale == nil else { return }
        let score = (run.level - 1) * 100 + Int(run.y / 40)
        if !banked {
            banked = true
            finale = bankedFinale(session: session, title: "Ship Duo", score: score, detail: detail, gameID: MiniGame.shipDuo.rawValue)
        }
    }

    private func replay() {
        run = ShipRun()
        finale = nil
        banked = false
    }
}
