import SwiftUI
import UserNotifications

/// Onboarding permissions (board M1-04, design screen 8): one line on why for
/// each, then "Continue" walks through the iOS prompts. Health and Location
/// are asked the first time a feature needs them (steps, weather; M2+), since
/// nothing in M1 uses them and an unused prompt is admin. Camera waits for the
/// first photo day; Calendar is never asked (decision D5).
struct PermissionsView: View {
    /// Skips the real system prompts (UI tests can't answer them reliably).
    var skipSystemPrompts = false
    var onDone: () -> Void

    @State private var asking = false

    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let why: String
        let now: Bool
    }

    private let items = [
        Item(id: "alarms", symbol: "alarm", title: "Alarms", why: "Wakes you for training, even on Silent.", now: true),
        Item(id: "notifications", symbol: "bell", title: "Notifications", why: "The Sunday question and the odd nudge. Never at night.", now: true),
        Item(id: "health", symbol: "heart", title: "Health", why: "Steps and weight from your scale. Asked when first needed.", now: false),
        Item(id: "location", symbol: "location", title: "Location while using", why: "Weather for outdoor runs. Asked when first needed.", now: false),
    ]

    var body: some View {
        List {
            Section {
                Text("Two quick yeses")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("permissions.title")
                Text("So the app can run your day without you checking it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            Section {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: item.symbol)
                            .font(.title3)
                            .foregroundStyle(item.now ? Color.green : Color.secondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.headline)
                            Text(item.why).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("permissions.row.\(item.id)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button(asking ? "Asking…" : "Continue") {
                    Task { await askThenFinish() }
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(asking)
                .accessibilityIdentifier("permissions.continue")
            }
        }
    }

    private func askThenFinish() async {
        asking = true
        defer { asking = false }
        if !skipSystemPrompts {
            // A "no" is fine: the feature drops back to manual (requirements §12 J).
            _ = try? await AlarmKitRegistrar().requestAuthorization()
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
        onDone()
    }
}
