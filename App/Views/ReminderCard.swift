import SwiftUI

struct ReminderCard: View {
    @EnvironmentObject private var session: PetSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Want a nudge?")
                .font(.headline)
            Text("If you leave the app, Pocket Pet can send a gentle reminder when \(name) is hungry, sad, tired, or needs you soon.")
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { @MainActor in
                    await session.allowReminders()
                }
            } label: {
                Text("Allow reminders")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(PocketButton.tint)
            .accessibilityHint("Shows the system prompt for notifications.")

            Button("Not now") {
                session.dismissReminderPrompt()
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityHint("Hides this question. You can turn reminders on later.")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private var name: String {
        session.record?.pet.name ?? "your pet"
    }
}
