import SwiftUI

struct RecoveryView: View {
    @EnvironmentObject private var session: PetSession
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("The saved pet couldn't be opened.")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("The old file will be kept beside the new one, named pet-record-broken.json, inside the same folder. You can start a new egg.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("Name", text: $name, prompt: Text("Mochi"))
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Pet name")
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 24 {
                                name = String(newValue.prefix(24))
                            }
                        }
                    Button {
                        session.createPet(named: name)
                    } label: {
                        Text("Start a new egg")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PocketButton.tint)
                }
                .padding(24)
            }
            .background(PocketBackground().ignoresSafeArea())
            .navigationTitle("Pocket Pet")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
