import PetCore
import SwiftUI
import WidgetKit

// Timeline: triggered by the app after each save, plus a fallback refresh.
// Each entry is the pet caught up to that wall-clock time, including any debug offset.

struct PetWidgetEntry: TimelineEntry {
    var date: Date
    var simulatedNow: Date
    var pet: Pet?

    static var preview: PetWidgetEntry {
        let now = Date()
        let egg = Pet.freshEgg(name: "Mochi", at: now.addingTimeInterval(-3 * 60 * 60))
        let pet = PetEngine().advance(egg, to: now)
        return PetWidgetEntry(date: now, simulatedNow: now, pet: pet)
    }
}

struct PetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetWidgetEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (PetWidgetEntry) -> Void) {
        completion(context.isPreview ? .preview : makeEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetWidgetEntry>) -> Void) {
        let now = Date()
        var stamps = [now.timeIntervalSince1970]
        let first = makeEntry(at: now)
        if let pet = first.pet {
            let plan = NotificationPlanner().plan(pet: pet, now: first.simulatedNow, includeAlreadyLow: false)
            for item in plan where item.fireAt > first.simulatedNow {
                let delta = item.fireAt.timeIntervalSince(first.simulatedNow)
                stamps.append(now.addingTimeInterval(delta).timeIntervalSince1970)
            }
        }
        for step in 1...6 {
            stamps.append(now.addingTimeInterval(Double(step) * 30 * 60).timeIntervalSince1970)
        }
        let entries = Array(Set(stamps))
            .sorted()
            .prefix(12)
            .map { makeEntry(at: Date(timeIntervalSince1970: $0)) }
        let refresh = (entries.last?.date ?? now).addingTimeInterval(15 * 60)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func makeEntry(at wall: Date) -> PetWidgetEntry {
        guard let record = loadRecord() else {
            return PetWidgetEntry(date: wall, simulatedNow: wall, pet: nil)
        }
        let simulated = wall.addingTimeInterval(record.debugTimeOffset)
        let pet = PetEngine().advance(record.pet, to: simulated)
        return PetWidgetEntry(date: wall, simulatedNow: simulated, pet: pet)
    }

    private func loadRecord() -> PetRecord? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: PetIdentity.appGroupID
        ) else {
            return nil
        }
        do {
            return try PetFileStore(directory: container).load()
        } catch {
            return nil
        }
    }
}

struct PetWidgetEntryView: View {
    var entry: PetWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let pet = entry.pet {
            content(pet)
        } else {
            VStack(spacing: 6) {
                Text("Pocket Pet")
                    .font(.headline)
                Text("Open the app to meet your pet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func content(_ pet: Pet) -> some View {
        if family == .systemMedium {
            HStack(alignment: .center, spacing: 12) {
                creature(pet)
                    .frame(width: 108, height: 108)
                details(pet)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    creature(pet)
                        .frame(width: 68, height: 68)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pet.name)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(PetCopy.statusLine(pet))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                }
                extra(pet)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func details(_ pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pet.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(PetCopy.statusLine(pet))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            extra(pet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func extra(_ pet: Pet) -> some View {
        if pet.stage == .egg || pet.isDead {
            Text(PetCopy.stageLine(pet, now: entry.simulatedNow))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        } else {
            VStack(spacing: 4) {
                StatMeterView(title: "Fed", value: pet.hunger, tint: StatTint.fed, compact: true)
                StatMeterView(title: "Happy", value: pet.happiness, tint: StatTint.happy, compact: true)
                StatMeterView(title: "Energy", value: pet.energy, tint: StatTint.energy, compact: true)
            }
        }
    }

    private func creature(_ pet: Pet) -> some View {
        PetCreatureView(
            stage: pet.stage == .egg ? .egg : pet.stage,
            mood: PetMood.resolve(pet),
            animates: false,
            accessibilityLabel: PetCopy.summary(pet, now: entry.simulatedNow)
        )
    }
}

struct PetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketPet", provider: PetProvider()) { entry in
            PetWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    PocketBackground()
                }
        }
        .configurationDisplayName("Pocket Pet")
        .description("See how your pet is doing.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PetWidgetBundle: WidgetBundle {
    var body: some Widget {
        PetWidget()
    }
}
