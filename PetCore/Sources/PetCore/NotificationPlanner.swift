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

    public static let allIDs = [hatchID, hungerID, happinessID, energyID, criticalID, testID]
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
        guard !current.isDead else { return [] }

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

        if let item = deathPlan(current, now: now, includeAlreadyLow: includeAlreadyLow) {
            items.append(item)
        }

        return items.sorted { $0.fireAt < $1.fireAt }
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

    private func deathPlan(_ pet: Pet, now: Date, includeAlreadyLow: Bool) -> PlannedNotification? {
        guard let deathAt = firstCrossing(from: pet, now: now, where: { $0.isDead }) else {
            return nil
        }
        let warnAt = deathAt.addingTimeInterval(-engine.rules.deathWarningLead)
        let fireAt: Date
        if warnAt > now.addingTimeInterval(1) {
            fireAt = warnAt
        } else if includeAlreadyLow {
            fireAt = now.addingTimeInterval(engine.rules.alreadyLowReminderDelay)
        } else if deathAt > now.addingTimeInterval(engine.rules.alreadyLowReminderDelay) {
            fireAt = deathAt.addingTimeInterval(-60)
        } else {
            return nil
        }
        return PlannedNotification(
            id: PlannedNotification.criticalID,
            fireAt: fireAt,
            title: "\(pet.name) needs you soon",
            body: "They aren't doing well. A visit would help."
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
