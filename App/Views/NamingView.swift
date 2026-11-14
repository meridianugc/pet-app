import SwiftUI

struct NamingView: View {
    @EnvironmentObject private var session: PetSession
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PetCreatureView(
                        stage: .egg,
                        mood: .egging,
                        accessibilityLabel: "An egg, waiting for a name."
                    )
                    .frame(maxWidth: 240)
                    .frame(maxWidth: .infinity)

                    Text("A little alien is waiting in this star egg. Give them a name, then look after them as they grow.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("Name", text: $name, prompt: Text("Mochi"))
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .accessibilityLabel("Pet name")
                        .onSubmit(start)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 24 {
                                name = String(newValue.prefix(24))
                            }
                        }

                    Button(action: start) {
                        Text("Start the egg")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PocketButton.tint)
                    .accessibilityHint("Creates an egg and starts the pet.")
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PocketBackground().ignoresSafeArea())
            .navigationTitle("Pocket Pet")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func start() {
        nameFocused = false
        session.createPet(named: name)
    }
}

enum PocketButton {
    static let tint = Color(red: 0.82, green: 0.34, blue: 0.38)
}
