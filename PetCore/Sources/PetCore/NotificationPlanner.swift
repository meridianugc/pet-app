import Foundation

public struct PlannedNotification: Equatable, Identifiable, Sendable {
    public var id: String
    public var fireAt: Date
    public var title: String
    public var body: String

    public init(id: String, fireAt: Date, title: String, body: String) {
        self.id = id
        self.fireAt = fireAt
        self.title = title
        self.body = body
    }

    public static let hatchID = "pocketpet.hatch"
    public static let hungerID = "pocketpet.hunger"
    public static let happinessID = "pocketpet.happiness"
    public static let energyID = "pocketpet.energy"
    public static let criticalID = "pocketpet.critical"
    public static let testID = "pocketpet.test"
    public static let gardenID = "pocketpet.garden"
    public static let tripID = "pocketpet.trip"
    public static let treeID = "pocketpet.tree"

    public static let allIDs = [hatchID, hungerID, happinessID, energyID, criticalID, testID, gardenID, tripID, treeID]
}

/// Turns the stat curves into the next local notifications.
/// Dates come from `PetEngine`, so the warnings match what the pet will actually do.
public struct NotificationPlanner: Sendable {
    public var engine: PetEngine
    public var resolution: TimeInterval

    public init(engine: PetEngine = PetEngine(), resolution: TimeInterval = 30) {
        self.engine = engine
        self.resolution = max(1, resolution)
    }

    public func plan(pet: Pet, now: Date, includeAlreadyLow: Bool) -> [PlannedNotification] {
        let current = engine.advance(pet, to: now)
        guard !current.hasGoneHome else { return [] }

        if current.stage == .egg {
            return hatchPlan(current, now: now)
        }

        var items: [PlannedNotification] = []
        let rules = engine.rules
        let name = current.name

        if let item = needPlan(
            id: PlannedNotification.hungerID,
            pet: current,
            now: now,
            includeAlreadyLow: includeAlreadyLow,
            isBad: { $0.hunger <= rules.hungerWarning },
            title: "\(name) is getting hungry",
            body: "A snack would help.",
            alreadyTitle: "\(name) is hungry",
            alreadyBody: "They're waiting on a meal."
        ) {
            items.append(item)
        }

        if let item = needPlan(
            id: PlannedNotification.happinessID,
            pet: current,
            now: now,
            includeAlreadyLow: includeAlreadyLow,
            isBad: { $0.happiness <= rules.happinessWarning },
            title: "\(name) would like some attention",
            body: "A little play would cheer them up.",
            alreadyTitle: "\(name) is feeling down",
            alreadyBody: "They'd like to play."
        ) {
            items.append(item)
        }

        if let item = needPlan(
            id: PlannedNotification.energyID,
            pet: current,
            now: now,
            includeAlreadyLow: includeAlreadyLow,
            isBad: { !$0.isSleeping && $0.energy <= rules.energyWarning },
            title: "\(name) is getting sleepy",
            body: "They could use a nap.",
            alreadyTitle: "\(name) is tired",
            alreadyBody: "Bedtime would help."
        ) {
            items.append(item)
        }

        if let item = homePlan(current, now: now, includeAlreadyLow: includeAlreadyLow) {
            items.append(item)
        }

        return items.sorted { $0.fireAt < $1.fireAt }
    }

    public func awayPlan(world: AwayWorld, now: Date) -> [PlannedNotification] {
        var items: [PlannedNotification] = []
        let readyTimes = world.seeds.map { $0.plantedAt.addingTimeInterval(6 * 3600) }.filter { $0 > now.addingTimeInterval(1) }
        if let ready = readyTimes.min() {
            items.append(PlannedNotification(
                id: PlannedNotification.gardenID,
                fireAt: ready,
                title: "Your star seeds are ready",
                body: "The garden can be harvested."
            ))
        }
        if let trip = world.trip, trip.returnsAt > now.addingTimeInterval(1) {
            items.append(PlannedNotification(
                id: PlannedNotification.tripID,
                fireAt: trip.returnsAt,
                title: "Back from the stars with a gift",
                body: "A postcard is waiting in the star book."
            ))
        }
        let stored = AwayLife.pendingGems(world, at: now)
        if stored < AwayWorld.gemCap {
            let hours = Double(AwayWorld.gemCap - stored) / Double(AwayWorld.gemPerHour)
            items.append(PlannedNotification(
                id: PlannedNotification.treeID,
                fireAt: now.addingTimeInterval(hours * 3600),
                title: "The gem tree is full",
                body: "Tap it before it stops growing."
            ))
        }
        return items
    }

    private func hatchPlan(_ pet: Pet, now: Date) -> [PlannedNotification] {
        guard let duration = engine.rules.duration(for: .egg) else { return [] }
        let hatchAt = pet.stageStartedAt.addingTimeInterval(duration)
        guard hatchAt > now.addingTimeInterval(1) else { return [] }
        guard hatchAt.timeIntervalSince(now) <= engine.rules.planHorizon else { return [] }
        return [
            PlannedNotification(
                id: PlannedNotification.hatchID,
                fireAt: hatchAt,
                title: "\(pet.name) is hatching",
                body: "Something is moving in the egg."
            )
        ]
    }

    private func needPlan(
        id: String,
        pet: Pet,
        now: Date,
        includeAlreadyLow: Bool,
        isBad: (Pet) -> Bool,
        title: String,
        body: String,
        alreadyTitle: String,
        alreadyBody: String
    ) -> PlannedNotification? {
        if isBad(pet) {
            guard includeAlreadyLow else { return nil }
            return PlannedNotification(
                id: id,
                fireAt: now.addingTimeInterval(engine.rules.alreadyLowReminderDelay),
                title: alreadyTitle,
                body: alreadyBody
            )
        }
        guard let fireAt = firstCrossing(from: pet, now: now, where: isBad) else { return nil }
        return PlannedNotification(id: id, fireAt: fireAt, title: title, body: body)
    }

    private func homePlan(_ pet: Pet, now: Date, includeAlreadyLow: Bool) -> PlannedNotification? {
        guard let homeAt = firstCrossing(from: pet, now: now, where: { $0.hasGoneHome }) else {
            return nil
        }
        let warnAt = homeAt.addingTimeInterval(-engine.rules.homeWarningLead)
        let fireAt: Date
        if warnAt > now.addingTimeInterval(1) {
            fireAt = warnAt
        } else if includeAlreadyLow {
            fireAt = now.addingTimeInterval(engine.rules.alreadyLowReminderDelay)
        } else if homeAt > now.addingTimeInterval(engine.rules.alreadyLowReminderDelay) {
            fireAt = homeAt.addingTimeInterval(-60)
        } else {
            return nil
        }
        return PlannedNotification(
            id: PlannedNotification.criticalID,
            fireAt: fireAt,
            title: "\(pet.name) might fly home",
            body: "They've been needing you. A visit would help them stay."
        )
    }

    /// First sample where `condition` becomes true. Accurate to `resolution`.
    private func firstCrossing(from pet: Pet, now: Date, where condition: (Pet) -> Bool) -> Date? {
        let start = engine.advance(pet, to: now)
        if condition(start) { return nil }
        let horizon = now.addingTimeInterval(engine.rules.planHorizon)
        var cursor = now
        var current = start
        while cursor < horizon {
            let next = min(horizon, cursor.addingTimeInterval(resolution))
            let sample = engine.advance(current, to: next)
            if condition(sample) {
                return next
            }
            current = sample
            cursor = next
        }
        return nil
    }
}
