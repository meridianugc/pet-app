import Foundation

public enum CareAction: String, Codable, Equatable, Sendable {
    case feed
    case play
    case beginSleep
    case wake
}

public struct CareOutcome: Equatable, Sendable {
    public var pet: Pet
    public var applied: Bool
    public var note: String

    public init(pet: Pet, applied: Bool, note: String) {
        self.pet = pet
        self.applied = applied
        self.note = note
    }
}

/// Pure simulation. Pass dates from a `Clock`; nothing here reads the wall clock.
public struct PetEngine: Sendable {
    public var rules: PetRules

    public init(rules: PetRules = PetRules()) {
        self.rules = rules
    }

    public func advance(_ pet: Pet, to end: Date) -> Pet {
        guard !pet.isDead else { return pet }
        guard end > pet.lastSimulatedAt else { return pet }

        var pet = pet
        var cursor = pet.lastSimulatedAt
        let epsilon = 0.000_000_1
        var steps = 0

        while cursor < end, steps < 4_000 {
            steps += 1
            if pet.isDead { break }

            if applyDueTransitions(&pet, at: cursor) {
                continue
            }

            let gap = timeUntilBoundary(pet, from: cursor, until: end)
            if gap <= epsilon {
                if !applyDueTransitions(&pet, at: cursor) {
                    break
                }
                continue
            }

            integrate(&pet, for: gap)
            cursor = cursor.addingTimeInterval(gap)
            pet.lastSimulatedAt = cursor
            _ = applyDueTransitions(&pet, at: cursor)
        }

        return pet
    }

    public func advance(_ pet: Pet, clock: Clock) -> Pet {
        advance(pet, to: clock.now)
    }

    public func perform(_ action: CareAction, on pet: Pet, at date: Date) -> CareOutcome {
        var pet = advance(pet, to: date)
        if pet.isDead {
            return CareOutcome(pet: pet, applied: false, note: "It's too late for that.")
        }
        if pet.stage == .egg {
            return CareOutcome(pet: pet, applied: false, note: "Still an egg.")
        }

        switch action {
        case .feed:
            if pet.isSleeping {
                return CareOutcome(pet: pet, applied: false, note: "They're asleep.")
            }
            let overfed = pet.hunger >= rules.overfeedAt
            pet.hunger = clamp(pet.hunger + rules.feedHunger)
            if overfed {
                pet.happiness = clamp(pet.happiness - rules.overfeedHappinessPenalty)
            } else {
                pet.happiness = clamp(pet.happiness + rules.feedHappiness)
            }
            refreshCriticalFlag(&pet, at: date)
            if pet.stage == .baby {
                if overfed {
                    pet.care.overfeeds += 1
                } else {
                    pet.care.properFeeds += 1
                }
            }
            let note = overfed ? "That was too much food." : "Yum."
            return CareOutcome(pet: pet, applied: true, note: note)

        case .play:
            if pet.isSleeping {
                return CareOutcome(pet: pet, applied: false, note: "They're asleep.")
            }
            if pet.energy < rules.minimumEnergyToPlay {
                return CareOutcome(pet: pet, applied: false, note: "Too tired to play.")
            }
            pet.happiness = clamp(pet.happiness + rules.playHappiness)
            pet.energy = clamp(pet.energy - rules.playEnergyCost)
            pet.hunger = clamp(pet.hunger - rules.playHungerCost)
            refreshCriticalFlag(&pet, at: date)
            if pet.stage == .baby {
                pet.care.plays += 1
            }
            return CareOutcome(pet: pet, applied: true, note: "That was fun.")

        case .beginSleep:
            if pet.isSleeping {
                return CareOutcome(pet: pet, applied: false, note: "They're already asleep.")
            }
            if pet.energy >= rules.statMax - 0.001 {
                return CareOutcome(pet: pet, applied: false, note: "Too awake to sleep.")
            }
            pet.isSleeping = true
            pet.sleepStartedAt = date
            pet.passedOut = false
            return CareOutcome(pet: pet, applied: true, note: "Sweet dreams.")

        case .wake:
            if !pet.isSleeping {
                return CareOutcome(pet: pet, applied: false, note: "They're already up.")
            }
            pet.isSleeping = false
            pet.sleepStartedAt = nil
            pet.passedOut = false
            return CareOutcome(pet: pet, applied: true, note: "Good morning.")
        }
    }

    /// Time left in the current stage after catching the pet up to `date`.
    /// Nil once they are an adult.
    public func timeRemainingInStage(_ pet: Pet, at date: Date) -> TimeInterval? {
        let current = advance(pet, to: date)
        guard let duration = rules.duration(for: current.stage) else { return nil }
        let elapsed = date.timeIntervalSince(current.stageStartedAt)
        return max(0, duration - elapsed)
    }

    // MARK: - Simulation steps

    /// Applies every mode change that is already due at `cursor` without moving time.
    /// Returns true when the pet changed, so the caller looks for the next boundary.
    private func applyDueTransitions(_ pet: inout Pet, at cursor: Date) -> Bool {
        guard !pet.isDead else { return false }

        if pet.stage == .egg {
            guard let duration = rules.duration(for: .egg) else { return false }
            let elapsed = cursor.timeIntervalSince(pet.stageStartedAt)
            guard elapsed >= duration - 0.000_1 else { return false }
            hatch(&pet, at: cursor)
            return true
        }

        let before = pet
        let (hungerRate, happinessRate, _) = ratesPerSecond(sleeping: pet.isSleeping)
        liftRecoveringStats(&pet, hungerRate: hungerRate, happinessRate: happinessRate)
        refreshCriticalFlag(&pet, at: cursor)

        if let since = pet.criticalSince,
           isCurrentlyCritical(pet, hungerRate: hungerRate, happinessRate: happinessRate),
           cursor.timeIntervalSince(since) >= rules.neglectDuration - 0.000_1 {
            die(&pet, at: cursor)
            return pet != before
        }

        if let duration = rules.duration(for: pet.stage) {
            let elapsed = cursor.timeIntervalSince(pet.stageStartedAt)
            if elapsed >= duration - 0.000_1, let next = pet.stage.next {
                if pet.stage == .baby {
                    pet.adultForm = Evolution.form(for: pet.care, rules: rules.evolution)
                }
                pet.stage = next
                pet.stageStartedAt = cursor
                return pet != before
            }
        }

        if !pet.isSleeping, pet.energy <= rules.statMin + 0.000_1 {
            pet.isSleeping = true
            pet.sleepStartedAt = cursor
            pet.passedOut = true
            pet.energy = rules.statMin
            return pet != before
        }

        if pet.isSleeping, pet.energy >= rules.statMax - 0.000_1 {
            pet.isSleeping = false
            pet.sleepStartedAt = nil
            pet.passedOut = false
            pet.energy = rules.statMax
            return pet != before
        }

        return pet != before
    }

    private func timeUntilBoundary(_ pet: Pet, from cursor: Date, until end: Date) -> TimeInterval {
        var limit = end.timeIntervalSince(cursor)
        guard limit > 0, !pet.isDead else { return max(0, limit) }

        if let duration = rules.duration(for: pet.stage) {
            let left = duration - cursor.timeIntervalSince(pet.stageStartedAt)
            if left > 0 { limit = min(limit, left) }
        }

        if pet.stage == .egg {
            return max(0, limit)
        }

        let (hungerRate, happinessRate, energyRate) = ratesPerSecond(sleeping: pet.isSleeping)

        if let dt = timeToReach(pet.hunger, rate: hungerRate, target: rules.statMin) {
            limit = min(limit, dt)
        }
        if let dt = timeToReach(pet.happiness, rate: happinessRate, target: rules.statMin) {
            limit = min(limit, dt)
        }

        if pet.stage != .egg {
            if pet.isSleeping {
                if let dt = timeToReach(pet.energy, rate: energyRate, target: rules.statMax) {
                    limit = min(limit, dt)
                }
            } else if let dt = timeToReach(pet.energy, rate: energyRate, target: rules.statMin) {
                limit = min(limit, dt)
            }
        }

        if let since = pet.criticalSince,
           isCurrentlyCritical(pet, hungerRate: hungerRate, happinessRate: happinessRate) {
            let left = rules.neglectDuration - cursor.timeIntervalSince(since)
            if left > 0 { limit = min(limit, left) }
        }

        return max(0, limit)
    }

    private func integrate(_ pet: inout Pet, for dt: TimeInterval) {
        guard dt > 0, pet.stage != .egg, !pet.isDead else { return }
        let hungerWasEmpty = pet.hunger <= rules.statMin + 0.000_1
        let happinessWasEmpty = pet.happiness <= rules.statMin + 0.000_1
        let (hungerRate, happinessRate, energyRate) = ratesPerSecond(sleeping: pet.isSleeping)
        pet.hunger = clamp(pet.hunger + hungerRate * dt)
        pet.happiness = clamp(pet.happiness + happinessRate * dt)
        pet.energy = clamp(pet.energy + energyRate * dt)
        if pet.stage == .baby {
            if hungerWasEmpty { pet.care.hungerEmptySeconds += dt }
            if happinessWasEmpty { pet.care.happinessEmptySeconds += dt }
        }
    }

    private func ratesPerSecond(sleeping: Bool) -> (Double, Double, Double) {
        let hour: Double = 3600
        if sleeping {
            return (
                -rules.sleepHungerPerHour / hour,
                rules.sleepHappinessPerHour / hour,
                rules.sleepEnergyPerHour / hour
            )
        }
        return (
            -rules.hungerDecayPerHour / hour,
            -rules.happinessDecayPerHour / hour,
            -rules.energyDecayPerHour / hour
        )
    }

    /// A stat sitting on zero with a positive rate is no longer a crisis.
    private func liftRecoveringStats(_ pet: inout Pet, hungerRate: Double, happinessRate: Double) {
        if pet.hunger <= rules.statMin + 0.000_1, hungerRate > 0 {
            pet.hunger = min(rules.statMax, rules.statMin + 0.001)
        }
        if pet.happiness <= rules.statMin + 0.000_1, happinessRate > 0 {
            pet.happiness = min(rules.statMax, rules.statMin + 0.001)
        }
    }

    private func isCurrentlyCritical(_ pet: Pet, hungerRate: Double, happinessRate: Double) -> Bool {
        let hungerCrisis = pet.hunger <= rules.statMin + 0.000_1 && hungerRate <= 0
        let happinessCrisis = pet.happiness <= rules.statMin + 0.000_1 && happinessRate <= 0
        return hungerCrisis || happinessCrisis
    }

    private func refreshCriticalFlag(_ pet: inout Pet, at cursor: Date) {
        let (hungerRate, happinessRate, _) = ratesPerSecond(sleeping: pet.isSleeping)
        if isCurrentlyCritical(pet, hungerRate: hungerRate, happinessRate: happinessRate) {
            if pet.criticalSince == nil {
                pet.criticalSince = cursor
            }
        } else {
            pet.criticalSince = nil
        }
    }

    private func hatch(_ pet: inout Pet, at cursor: Date) {
        pet.stage = .baby
        pet.stageStartedAt = cursor
        pet.bornAt = cursor
        pet.hunger = rules.hatchHunger
        pet.happiness = rules.hatchHappiness
        pet.energy = rules.hatchEnergy
        pet.isSleeping = false
        pet.sleepStartedAt = nil
        pet.passedOut = false
        pet.criticalSince = nil
        pet.diedAt = nil
        pet.deathReason = nil
    }

    private func die(_ pet: inout Pet, at cursor: Date) {
        let reason: DeathReason = pet.hunger <= pet.happiness ? .hunger : .loneliness
        pet.diedAt = cursor
        pet.deathReason = reason
        pet.isSleeping = false
        pet.sleepStartedAt = nil
        pet.passedOut = false
        pet.lastSimulatedAt = cursor
    }

    private func timeToReach(_ value: Double, rate: Double, target: Double) -> TimeInterval? {
        if abs(rate) < 1e-12 { return nil }
        let dt = (target - value) / rate
        if dt <= 0.000_1 { return nil }
        return dt
    }

    private func clamp(_ value: Double) -> Double {
        min(rules.statMax, max(rules.statMin, value))
    }
}
