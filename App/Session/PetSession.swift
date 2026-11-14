import Combine
import Foundation
import PetCore
import WidgetKit

struct MeterPop: Equatable, Identifiable {
    var id = UUID()
    var stat: CareStat
    var amount: Int
}

struct PlayReward: Equatable {
    var title: String
    var score: Int
    var gems: Int
    var xp: Int
    var isBest: Bool
    var gamesPlayed: Int
}

enum CareAsk: Equatable {
    case feed
    case item(String)
}

enum ReminderAccess: Equatable {
    case unknown
    case notAsked
    case allowed
    case denied
}

/// Owns the saved pet, catches it up to the clock, and talks to reminders and the widget.
@MainActor
final class PetSession: ObservableObject {
    @Published private(set) var record: PetRecord?
    @Published private(set) var loadError: String?
    @Published private(set) var saveError: String?
    @Published var note: String?
    @Published private(set) var reminderAccess: ReminderAccess = .unknown
    @Published var playReward: PlayReward?
    @Published var meterPops: [MeterPop] = []
    @Published var careAsk: CareAsk?

    let usesAppGroup: Bool

    private let store: PetFileStore
    private let engine: PetEngine
    private let scheduler: PetNotificationScheduler

    init(
        store: PetFileStore,
        usesAppGroup: Bool,
        scheduler: PetNotificationScheduler? = nil
    ) {
        self.store = store
        self.usesAppGroup = usesAppGroup
        // Default arguments are nonisolated, so the main-actor scheduler is created here.
        self.scheduler = scheduler ?? PetNotificationScheduler()
        self.engine = PetEngine()
        loadFromDisk()
        Task { @MainActor in
            await refreshReminderAccess()
        }
    }

    var currentDate: Date {
        Date().addingTimeInterval(record?.debugTimeOffset ?? 0)
    }

    func sceneBecameActive() {
        refresh(includeAlreadyLow: false)
    }

    func sceneEnteredBackground() {
        refresh(includeAlreadyLow: true)
    }

    func refresh(includeAlreadyLow: Bool) {
        Task { @MainActor in
            await refreshReminderAccess()
        }
        guard let record else { return }
        persist(record, includeAlreadyLow: includeAlreadyLow)
    }

    func createPet(named name: String) {
        quarantineUnreadableFile()
        loadError = nil
        note = nil
        let pet = Pet.freshEgg(name: name, at: Date())
        persist(PetRecord(pet: pet), includeAlreadyLow: false)
    }

    func hatchNewEgg(named name: String) {
        let offset = record?.debugTimeOffset ?? 0
        let dismissed = record?.notificationPromptDismissed ?? false
        let pet = Pet.freshEgg(name: name, at: Date().addingTimeInterval(offset))
        note = nil
        persist(
            PetRecord(pet: pet, debugTimeOffset: offset, notificationPromptDismissed: dismissed),
            includeAlreadyLow: false
        )
    }

    func feed() {
        if record?.pet.isSleeping == true {
            careAsk = .feed
            return
        }
        perform(.feed)
    }

    func confirmCare() {
        let ask = careAsk
        careAsk = nil
        perform(.wake)
        switch ask {
        case .feed:
            perform(.feed)
        case let .item(id):
            useItem(id)
        case nil:
            break
        }
    }

    func dismissCare() {
        careAsk = nil
    }

    var level: Int { LevelTable.level(for: record?.progress.xp ?? 0) }

    func dismissReward() {
        playReward = nil
    }

    func finishGame(points: Int, gameID: String? = nil, title: String = "Game") {
        guard var record else { return }
        let now = currentDate
        var pet = engine.advance(record.pet, to: now)
        let solo = pet.isSleeping
        guard pet.stage != .egg, !pet.hasGoneHome, solo || pet.energy >= engine.rules.minimumEnergyToPlay else {
            note = pet.energy < engine.rules.minimumEnergyToPlay ? "Too tired to play." : "Not a good moment to play."
            record.pet = pet
            persist(record, includeAlreadyLow: false)
            return
        }
        let reward = GameRewards.reward(points: points, solo: solo)
        let gems = record.progress.gemPayout(base: reward.coins, now: now)
        if !solo {
            pet.happiness = min(engine.rules.statMax, pet.happiness + reward.happiness)
            pet.energy = max(engine.rules.statMin, pet.energy - reward.energyCost)
            if pet.stage == .baby { pet.care.plays += 1 }
        }
        pet.lastSimulatedAt = now
        record.pet = pet
        record.progress.coins += gems
        record.progress.xp += reward.xp
        record.progress.gamesFinished += 1
        var isBest = false
        if let gameID {
            isBest = record.progress.noteBest(gameID: gameID, score: points)
        }
        let calendar = Calendar.current
        record.progress.daily = DailyBoard.recordGame(record.progress.daily, on: now, calendar: calendar)
        record.progress.streak = Streak.mark(
            record.progress.streak,
            on: DayStamp.capture(now, calendar: calendar),
            calendar: calendar
        )
        note = nil
        if gameID != nil {
            playReward = PlayReward(
                title: title,
                score: points,
                gems: gems,
                xp: reward.xp,
                isBest: isBest,
                gamesPlayed: record.progress.daily.gamesPlayed
            )
        }
        persist(record, includeAlreadyLow: false)
    }

    func buy(_ id: String) {
        guard var record else { return }
        switch Shop.purchase(id: id, progress: record.progress, level: level) {
        case let .success(progress):
            record.progress = progress
            note = "Tucked into the bag."
            persist(record, includeAlreadyLow: false)
        case let .failure(error):
            note = shopNote(error)
        }
    }

    func useItem(_ id: String) {
        guard var record else { return }
        if record.pet.isSleeping, let item = Shop.item(id), item.needsThePetAwake {
            careAsk = .item(id)
            return
        }
        switch Shop.consume(id: id, progress: record.progress) {
        case let .success((progress, effect)):
            record.progress = progress
            var pet = engine.advance(record.pet, to: currentDate)
            guard pet.stage != .egg, !pet.hasGoneHome, !pet.isSleeping else {
                record.progress.stock[id, default: 0] += 1
                note = "They're not ready for that."
                persist(record, includeAlreadyLow: false)
                return
            }
            pet = PetCare.apply(effect, to: pet, rules: engine.rules)
            pet.lastSimulatedAt = currentDate
            record.pet = pet
            if effect.gemBonusHours > 0 {
                record.progress.gemBonusPercent = effect.gemBonusPercent
                record.progress.gemBonusUntil = currentDate.addingTimeInterval(effect.gemBonusHours * 3600)
            }
            flash(effect.chips)
            if effect.hunger > 0 {
                record.progress.mealsFed += 1
            }
            record.progress.xp += effect.countsAsHealthyMeal ? 8 : 3
            if effect.countsAsHealthyMeal {
                praiseCare(&record.progress, at: currentDate)
            }
            note = effect.countsAsTreat ? "A sweet treat." : "Yum."
            persist(record, includeAlreadyLow: false)
        case let .failure(error):
            note = shopNote(error)
        }
    }

    func buyLook(_ id: String) {
        guard var record else { return }
        switch LookBook.buy(
            id: id,
            wardrobe: record.progress.wardrobe,
            coins: record.progress.coins,
            level: level,
            achievements: record.progress.achievements
        ) {
        case let .success((wardrobe, coins)):
            record.progress.wardrobe = wardrobe
            record.progress.coins = coins
            note = nil
            persist(record, includeAlreadyLow: false)
        case let .failure(error):
            note = lookNote(error)
        }
    }

    func wearLook(_ id: String) {
        guard var record else { return }
        switch LookBook.wear(
            id: id,
            wardrobe: record.progress.wardrobe,
            stage: record.pet.stage,
            form: record.pet.displayForm
        ) {
        case let .success(wardrobe):
            record.progress.wardrobe = wardrobe
            note = nil
            persist(record, includeAlreadyLow: false)
        case let .failure(error):
            note = lookNote(error)
        }
    }

    private func lookNote(_ error: LookError) -> String {
        switch error {
        case .unknown: return "That look isn't here."
        case .lockedLevel(let level): return "Unlocks at level \(level)."
        case .lockedAchievement: return "A little more care unlocks that."
        case .lockedTrips(let count): return count == 1 ? "Finish a space trip first." : "Finish \(count) space trips first."
        case .notEnoughGems: return "Not enough star gems."
        case .alreadyOwned: return "You already have that look."
        case .notOwned: return "Buy it first."
        case .wrongStage: return "That look waits for another stage."
        }
    }

    func equipOutfit(_ id: String?) {
        guard var record else { return }
        switch Shop.equip(id, progress: record.progress) {
        case let .success(progress):
            record.progress = progress
            note = id == nil ? "Back to plain fur." : "Looking sharp."
            persist(record, includeAlreadyLow: false)
        case let .failure(error):
            note = shopNote(error)
        }
    }

    func equipBackground(_ id: String?) {
        guard var record else { return }
        switch Shop.equipBackground(id, progress: record.progress) {
        case let .success(progress):
            record.progress = progress
            note = id == nil ? "The usual sky." : "New sky."
            persist(record, includeAlreadyLow: false)
        case let .failure(error):
            note = shopNote(error)
        }
    }

    func claim(_ task: DailyTask) {
        guard var record else { return }
        let calendar = Calendar.current
        guard let (daily, coins) = DailyBoard.claim(task, state: record.progress.daily, on: currentDate, calendar: calendar) else {
            note = "That task isn't ready."
            return
        }
        record.progress.daily = daily
        record.progress.coins += coins
        record.progress.streak = Streak.mark(
            record.progress.streak,
            on: DayStamp.capture(currentDate, calendar: calendar),
            calendar: calendar
        )
        note = "\(coins) star gems"
        persist(record, includeAlreadyLow: false)
    }

    func toggleSleep() {
        guard let pet = record?.pet else { return }
        perform(pet.isSleeping ? .wake : .beginSleep)
    }

    func dismissFarewell(naming name: String) {
        guard var record, record.farewell != nil else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            record.pet.name = String(trimmed.prefix(24))
        }
        record.farewell = nil
        note = nil
        persist(record, includeAlreadyLow: false)
    }

    func dismissReminderPrompt() {
        guard var record else { return }
        record.notificationPromptDismissed = true
        persist(record, includeAlreadyLow: false)
    }

    func allowReminders() async {
        _ = await scheduler.requestAuthorization()
        await refreshReminderAccess()
        dismissReminderPrompt()
        if reminderAccess == .allowed {
            refresh(includeAlreadyLow: false)
        }
    }

    func refreshReminderAccess() async {
        switch await scheduler.authorizationStatus() {
        case .notDetermined:
            reminderAccess = .notAsked
        case .denied:
            reminderAccess = .denied
        case .authorized, .provisional, .ephemeral:
            reminderAccess = .allowed
        @unknown default:
            reminderAccess = .unknown
        }
    }

#if DEBUG
    func fastForward(by interval: TimeInterval) {
        guard var record else { return }
        record.debugTimeOffset += interval
        note = "Debug clock moved forward."
        persist(record, includeAlreadyLow: false)
    }

    func useRealClock() {
        guard var record else { return }
        record.debugTimeOffset = 0
        record.pet.lastSimulatedAt = Date()
        note = "Using the real clock. Stats stay where they are."
        persist(record, includeAlreadyLow: false)
    }

    func debugSkipStage() {
        guard let pet = record?.pet else { return }
        guard let left = engine.timeRemainingInStage(pet, at: currentDate) else {
            note = "Already grown up."
            return
        }
        fastForward(by: left + 1)
    }

    func debugFill() {
        debugAdjust(hunger: 80, happiness: 80, energy: 80, clearCrisis: true)
    }

    func debugMakeHungry() {
        debugAdjust(hunger: 18, clearCrisis: true)
    }

    func debugMakeSad() {
        debugAdjust(happiness: 18, clearCrisis: true)
    }

    func debugMakeTired() {
        debugAdjust(energy: 10, clearCrisis: true)
    }

    func debugBringToBrink() {
        let almost = engine.rules.neglectDuration - 120
        debugAdjust(hunger: 0, happiness: 55, energy: 40, crisisAge: almost)
    }

    func sendTestReminder() async {
        let name = record?.pet.name ?? "Your pet"
        note = await scheduler.sendTestReminder(petName: name)
        await refreshReminderAccess()
    }
#endif

    private func perform(_ action: CareAction) {
        guard var record else { return }
        let outcome = engine.perform(action, on: record.pet, at: currentDate)
        record.pet = outcome.pet
        note = outcome.note
        if outcome.applied {
            let calendar = Calendar.current
            switch action {
            case .feed:
                let happy = outcome.wasTreat ? -Int(engine.rules.overfeedHappinessPenalty) : Int(engine.rules.feedHappiness)
                flash([
                    CareChip(stat: .fed, amount: Int(engine.rules.feedHunger)),
                    CareChip(stat: .happy, amount: happy)
                ])
                record.progress.mealsFed += 1
                record.progress.xp += outcome.wasTreat ? 3 : 8
                if !outcome.wasTreat {
                    record.progress.daily = DailyBoard.recordHealthyMeal(record.progress.daily, on: currentDate, calendar: calendar)
                    praiseCare(&record.progress, at: currentDate)
                }
            case .beginSleep:
                record.progress.xp += 5
                record.progress.daily = DailyBoard.recordSleep(record.progress.daily, on: currentDate, calendar: calendar)
                praiseCare(&record.progress, at: currentDate)
            case .play, .wake:
                break
            }
        }
        persist(record, includeAlreadyLow: false)
    }

    private func flash(_ chips: [CareChip]) {
        meterPops = chips.filter { $0.amount != 0 }.map { MeterPop(stat: $0.stat, amount: $0.amount) }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            meterPops = []
        }
    }

    private func praiseCare(_ progress: inout PlayerProgress, at date: Date) {
        let calendar = Calendar.current
        progress.streak = Streak.mark(progress.streak, on: DayStamp.capture(date, calendar: calendar), calendar: calendar)
    }

    private func shopNote(_ error: ShopError) -> String {
        switch error {
        case .unknownItem: return "That isn't in the shop."
        case .notEnoughCoins: return "Not enough star gems."
        case .levelLocked(let required): return "Unlocks at level \(required)."
        case .alreadyOwned: return "You already have that."
        case .noneLeft: return "None left."
        case .notWearable: return "That can't be worn."
        }
    }

    private func loadFromDisk() {
        do {
            guard var loaded = try store.load() else { return }
            let now = Date().addingTimeInterval(loaded.debugTimeOffset)
            settle(&loaded, now: now)
            self.record = loaded
            try? store.save(loaded)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            loadError = "The saved pet could not be read."
        }
    }

    private func persist(_ record: PetRecord, includeAlreadyLow: Bool) {
        var record = record
        let now = Date().addingTimeInterval(record.debugTimeOffset)
        settle(&record, now: now)
        do {
            try store.save(record)
            saveError = nil
        } catch {
            saveError = "Couldn't save on this device. Check that there is free space."
        }
        self.record = record
        WidgetCenter.shared.reloadAllTimelines()
        let pet = record.pet
        Task { @MainActor in
            await scheduler.reschedule(pet: pet, now: now, includeAlreadyLow: includeAlreadyLow)
        }
    }

    private func settle(_ record: inout PetRecord, now: Date) {
        let before = record.pet
        record.pet = engine.advance(record.pet, to: now)
        if EvolutionBonus.applies(before: before, after: record.pet) {
            record.progress.coins += EvolutionBonus.coins
            record.progress.xp += EvolutionBonus.xp
        }
        if record.pet.hasGoneHome, record.farewell == nil {
            let trip = PetLineage.succeed(record.pet, collection: record.collection)
            record.collection = trip.collection
            record.farewell = trip.letter
            record.pet = engine.advance(trip.next, to: now)
        }
        record.collection = record.collection.noting(record.pet)
        record.progress.daily = DailyBoard.refreshed(record.progress.daily, on: now, calendar: .current)
        record.progress = Achievements.sync(record.progress, collection: record.collection)
    }

    private func quarantineUnreadableFile() {
        guard loadError != nil else { return }
        let broken = store.fileURL.deletingLastPathComponent()
            .appendingPathComponent("pet-record-broken.json")
        try? FileManager.default.removeItem(at: broken)
        try? FileManager.default.moveItem(at: store.fileURL, to: broken)
        loadError = nil
    }

#if DEBUG
    private func debugAdjust(
        hunger: Double? = nil,
        happiness: Double? = nil,
        energy: Double? = nil,
        clearCrisis: Bool = false,
        crisisAge: TimeInterval? = nil
    ) {
        guard var record else { return }
        guard record.pet.stage != .egg, !record.pet.hasGoneHome else {
            note = "That waits until the egg has hatched."
            return
        }
        let now = Date().addingTimeInterval(record.debugTimeOffset)
        record.pet = engine.advance(record.pet, to: now)
        if let hunger { record.pet.hunger = hunger }
        if let happiness { record.pet.happiness = happiness }
        if let energy { record.pet.energy = energy }
        record.pet.isSleeping = false
        record.pet.passedOut = false
        record.pet.sleepStartedAt = nil
        if let crisisAge {
            record.pet.criticalSince = now.addingTimeInterval(-crisisAge)
        } else if clearCrisis, record.pet.hunger > 0, record.pet.happiness > 0 {
            record.pet.criticalSince = nil
        }
        record.pet.lastSimulatedAt = now
        note = "Debug stats updated."
        persist(record, includeAlreadyLow: false)
    }
#endif
}
