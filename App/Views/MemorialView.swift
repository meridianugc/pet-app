import PetCore
import SwiftUI

struct MemorialView: View {
    @EnvironmentObject private var session: PetSession
    let pet: Pet
    @State private var name: String

    init(pet: Pet) {
        self.pet = pet
        _name = State(initialValue: pet.name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PetCreatureView(
                        stage: pet.stage == .egg ? .baby : pet.stage,
                        mood: .gone,
                        animates: false,
                        accessibilityLabel: PetCopy.summary(pet, now: session.currentDate)
                    )
                    .frame(maxWidth: 240)
                    .frame(maxWidth: .infinity)

                    Text("\(pet.name) has passed on")
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(3)

                    Text(pet.deathReason?.epitaph ?? "They ran out of time.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Text("They were with you for \(life). You can say goodbye, and hatch a new egg whenever you want.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("Name for the next egg", text: $name, prompt: Text(pet.name))
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityLabel("Name for the next egg")
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 24 {
                                name = String(newValue.prefix(24))
                            }
                        }

                    Button {
                        session.hatchNewEgg(named: name)
                    } label: {
                        Text("Hatch a new egg")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PocketButton.tint)
                    .accessibilityHint("Starts again with a new egg.")
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PocketBackground().ignoresSafeArea())
            .navigationTitle("Pocket Pet")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var life: String {
        PetAge.phrase(from: pet.bornAt ?? pet.createdAt, to: pet.diedAt ?? session.currentDate)
    }
}
