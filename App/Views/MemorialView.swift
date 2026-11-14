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
