import CoachCore
import SwiftUI

/// Board N5, design §3 N5: Shopping's one action bar. Primary "In the shop"
/// opens in-store mode; secondary "Send to Reminders" writes the list to
/// Reminders. Nothing asks "are you sure" (E5); the only alert is the
/// system's permission prompt on the first send.
struct GroceryActionBar: View {
    let items: [ShoppingItem]
    let monday: Date
    /// Called after in-store mode closes or a send finishes, so the list redraws.
    let onChange: () -> Void

    @State private var inStore = false
    @State private var sending = false
    @State private var problem: String?
    private let calendar = Calendar.coach
    private var ticks: MealTicks { .shared }

    var body: some View {
        ActionBar {
            VStack(spacing: Space.s) {
                if let problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.caution)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("shopping.remindersProblem")
                }
                Button {
                    Task { await send() }
                } label: {
                    if sending { ProgressView() } else { Text("Send to Reminders") }
                }
                .buttonStyle(SecondaryActionStyle())
                .disabled(sending || items.isEmpty)
                .accessibilityIdentifier("shopping.reminders")
            }
        } primary: {
            Button("In the shop") { inStore = true }
                .buttonStyle(PrimaryActionStyle())
                .disabled(items.isEmpty)
                .accessibilityIdentifier("shopping.inStore")
        }
        .fullScreenCover(isPresented: $inStore, onDismiss: onChange) {
            InStoreView(items: items, monday: monday) { inStore = false }
        }
    }

    private func send() async {
        sending = true
        defer { sending = false }
        let toSend = GroceryExport.toSend(items) { ticks.isTicked($0, week: monday, calendar: calendar) }
        do {
            _ = try await RemindersExport.shared.send(toSend, now: AppClock.now(), calendar: calendar)
            problem = nil
        } catch RemindersExport.Failure.denied {
            problem = "Reminders is off for HealthCoach. Turn it on in Settings › Apps › HealthCoach."
        } catch {
            problem = "Couldn't write to Reminders. Try again in a moment."
        }
        onChange()
    }
}

/// The header line after a send (design N5): "Sent to Reminders · Shopping",
/// for the rest of the day. Its value says what Reminders holds, so the UI
/// test can check the list is there and wasn't duplicated.
struct GrocerySentLine: View {
    let now: Date
    private var export: RemindersExport { .shared }

    var body: some View {
        if export.sentToday(now: now, calendar: .coach) {
            Text("Sent to Reminders · \(GroceryExport.listTitle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(nil)
                .accessibilityIdentifier("shopping.sent")
                .accessibilityValue(export.lastResult.map { "\($0.lists) list · \($0.items) items" } ?? "")
        }
    }
}
