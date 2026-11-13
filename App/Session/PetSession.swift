import Combine
import Foundation
import PetCore
import WidgetKit

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

    let usesAppGroup: Bool

    private let store: PetFileStore
    private let engine: PetEngine
    private let scheduler: PetNotificationScheduler

    init(
        store: PetFileStore,
        usesAppGroup: Bool,
        scheduler: PetNotificationScheduler = PetNotificationScheduler()
    ) {
        self.store = store
        self.usesAppGroup = usesAppGroup
        self.scheduler = scheduler
        self.engine = PetEngine()
        loadFromDisk()
        Task { await refreshReminderAccess() }
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
        Task { await refreshReminderAccess() }
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

    func feed() { perform(.feed) }
    func play() { perform(.play) }

    func toggleSleep() {
        guard let pet = record?.pet else { return }
        perform(pet.isSleeping ? .wake : .beginSleep)
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
        persist(record, includeAlreadyLow: false)
    }

    private func loadFromDisk() {
        do {
            guard var loaded = try store.load() else { return }
            let now = Date().addingTimeInterval(loaded.debugTimeOffset)
            loaded.pet = engine.advance(loaded.pet, to: now)
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
        record.pet = engine.advance(record.pet, to: now)
        do {
            try store.save(record)
            saveError = nil
        } catch {
            saveError = "Couldn't save on this device. Check that there is free space."
        }
        self.record = record
        WidgetCenter.shared.reloadAllTimelines()
        let pet = record.pet
        Task {
            await scheduler.reschedule(pet: pet, now: now, includeAlreadyLow: includeAlreadyLow)
        }
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
        guard record.pet.stage != .egg, !record.pet.isDead else {
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
