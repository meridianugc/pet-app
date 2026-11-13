import Foundation

/// Tunable numbers for decay, growth, care, and warnings.
/// `PetRules()` is what the app ships with. Tests build their own copy.
public struct PetRules: Equatable, Sendable {
    public var eggDuration: TimeInterval
    public var babyDuration: TimeInterval
    public var childDuration: TimeInterval
    public var teenDuration: TimeInterval

    /// Points lost per hour while awake. 100 means full, 0 means starving.
    public var hungerDecayPerHour: Double
    public var happinessDecayPerHour: Double
    public var energyDecayPerHour: Double

    /// While asleep: energy rises, hunger still falls (slower), happiness stays put.
    public var sleepEnergyPerHour: Double
    public var sleepHungerPerHour: Double
    public var sleepHappinessPerHour: Double

    public var feedHunger: Double
    public var feedHappiness: Double
    public var overfeedAt: Double
    public var overfeedHappinessPenalty: Double

    public var playHappiness: Double
    public var playEnergyCost: Double
    public var playHungerCost: Double
    public var minimumEnergyToPlay: Double

    /// How long hunger or happiness may sit at zero before the pet dies.
    public var neglectDuration: TimeInterval

    public var statMin: Double
    public var statMax: Double

    public var hatchHunger: Double
    public var hatchHappiness: Double
    public var hatchEnergy: Double

    public var hungerWarning: Double
    public var happinessWarning: Double
    public var energyWarning: Double
    public var deathWarningLead: TimeInterval
    public var planHorizon: TimeInterval
    public var alreadyLowReminderDelay: TimeInterval

    public init() {
        eggDuration = 45 * 60
        babyDuration = 6 * 60 * 60
        childDuration = 18 * 60 * 60
        teenDuration = 36 * 60 * 60

        hungerDecayPerHour = 10
        happinessDecayPerHour = 7
        energyDecayPerHour = 12

        sleepEnergyPerHour = 30
        sleepHungerPerHour = 4
        sleepHappinessPerHour = 0

        feedHunger = 32
        feedHappiness = 5
        overfeedAt = 85
        overfeedHappinessPenalty = 10

        playHappiness = 26
        playEnergyCost = 16
        playHungerCost = 8
        minimumEnergyToPlay = 15

        neglectDuration = 4 * 60 * 60

        statMin = 0
        statMax = 100

        hatchHunger = 80
        hatchHappiness = 80
        hatchEnergy = 70

        hungerWarning = 30
        happinessWarning = 30
        energyWarning = 25
        deathWarningLead = 45 * 60
        planHorizon = 48 * 60 * 60
        alreadyLowReminderDelay = 2 * 60
    }

    public func duration(for stage: LifeStage) -> TimeInterval? {
        switch stage {
        case .egg: return eggDuration
        case .baby: return babyDuration
        case .child: return childDuration
        case .teen: return teenDuration
        case .adult: return nil
        }
    }
}
