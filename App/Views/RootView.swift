import PetCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: PetSession

    var body: some View {
        VStack(spacing: 0) {
            if let saveError = session.saveError {
                Text(saveError)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.28))
                    .accessibilityLabel(saveError)
            }
            screen
        }
    }

    @ViewBuilder
    private var screen: some View {
        if session.loadError != nil, session.record == nil {
            RecoveryView()
        } else if let pet = session.record?.pet, pet.hasGoneHome {
            MemorialView(pet: pet)
        } else if session.record?.pet != nil {
            HomeView()
        } else {
            NamingView()
        }
    }
}
