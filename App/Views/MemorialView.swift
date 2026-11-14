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

struct ShopView: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let progress = session.record?.progress ?? PlayerProgress()
        List {
            Section {
                Text("\(progress.coins) coins · level \(session.level)")
                    .font(.headline)
            }
            Section("Food and toys") {
                ForEach(Shop.catalog.filter { !$0.isDurable }) { item in
                    row(item, progress: progress, durable: false)
                }
            }
            Section("Outfits") {
                ForEach(Shop.catalog.filter { if case .outfit = $0.kind { return true }; return false }) { item in
                    row(item, progress: progress, durable: true)
                }
                if progress.outfitID != nil {
                    Button("Take the outfit off") { session.equipOutfit(nil) }
                }
            }
            Section("Skies") {
                ForEach(Shop.catalog.filter { if case .background = $0.kind { return true }; return false }) { item in
                    row(item, progress: progress, durable: true)
                }
                if progress.backgroundID != nil {
                    Button("Use the usual sky") { session.equipBackground(nil) }
                }
            }
        }
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func row(_ item: Goods, progress: PlayerProgress, durable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.body)
            Text(detail(item, progress: progress))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Buy · \(item.price)") { session.buy(item.id) }
                    .disabled(session.level < item.unlockLevel)
                if !durable, (progress.stock[item.id] ?? 0) > 0 {
                    Button("Use") { session.useItem(item.id) }
                }
                if durable, progress.ownedIDs.contains(item.id) {
                    Button(progress.outfitID == item.id || progress.backgroundID == item.id ? "Using" : "Use") {
                        if case .outfit = item.kind {
                            session.equipOutfit(item.id)
                        } else {
                            session.equipBackground(item.id)
                        }
                    }
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ item: Goods, progress: PlayerProgress) -> String {
        if session.level < item.unlockLevel {
            return "Unlocks at level \(item.unlockLevel)"
        }
        if item.isDurable, progress.ownedIDs.contains(item.id) {
            return "Owned"
        }
        let stock = progress.stock[item.id] ?? 0
        if stock > 0 { return "In the bag: \(stock)" }
        switch item.kind {
        case .food(_, _, true, _): return "A treat. Too many can spoil a baby."
        case .food: return "A healthy meal."
        case .toy: return "A burst of play."
        case .outfit: return "Wear it on the alien."
        case .background: return "A new sky for the room."
        }
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
        List {
            Section("Level \(level)") {
                Text("\(into) / \(span) XP toward the next level")
                    .font(.body)
                Text(progress.streak.count == 1 ? "1 day of good care" : "\(progress.streak.count) days of good care")
                    .font(.body)
            }
            Section("Today") {
                ForEach(DailyTask.allCases, id: \.self) { task in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.body)
                        Text(taskLine(task, progress: progress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if progress.daily.isComplete(task), !progress.daily.claimed.contains(task) {
                            Button("Collect \(task.reward) coins") {
                                session.claim(task)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
            Section("Achievements") {
                if progress.achievements.isEmpty {
                    Text("Look after your alien and these will fill in.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(progress.achievements, id: \.self) { item in
                        Text(item.title)
                            .font(.body)
                    }
                }
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
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
