import SwiftUI

#if DEBUG
struct DebugMenuView: View {
    @EnvironmentObject private var session: PetSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Clock") {
                Text("Simulated time: \(session.currentDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.body)
                Text(session.usesAppGroup ? "Saving in the shared App Group." : "Saving in the app only. The widget can't see this pet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Move time") {
                timeButton("Forward 15 minutes", interval: 15 * 60)
                timeButton("Forward 1 hour", interval: 60 * 60)
                timeButton("Forward 6 hours", interval: 6 * 60 * 60)
                timeButton("Forward 1 day", interval: 24 * 60 * 60)
                Button("Skip to the next life stage") {
                    session.debugSkipStage()
                }
                Button("Use the real clock again") {
                    session.useRealClock()
                }
            }

            Section("Stats") {
                Button("Fill fed, happy, and energy") { session.debugFill() }
                Button("Make them hungry") { session.debugMakeHungry() }
                Button("Make them sad") { session.debugMakeSad() }
                Button("Make them tired") { session.debugMakeTired() }
                Button("Two minutes from passing on") { session.debugBringToBrink() }
            }

            Section("Reminders") {
                Button("Send a test reminder") {
                    Task { await session.sendTestReminder() }
                }
                Text("Allow reminders first. The test arrives in about 5 seconds, even while this app is open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let note = session.note {
                Section("Last note") {
                    Text(note)
                        .font(.body)
                }
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func timeButton(_ title: String, interval: TimeInterval) -> some View {
        Button(title) {
            session.fastForward(by: interval)
        }
    }
}
#endif
