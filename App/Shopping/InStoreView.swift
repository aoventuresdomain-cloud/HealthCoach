import CoachCore
import SwiftUI
import UIKit

/// Board N5, design §3 N5: in-store mode. Only what's left to get, in aisle
/// order, rows 64 pt; tapping a row ticks it and it leaves, so the next item
/// is always the top row (W4: no scrolling). No search links, no questions.
/// The screen stays awake while it's open.
struct InStoreView: View {
    let items: [ShoppingItem]
    let monday: Date
    let onClose: () -> Void

    @State private var version = 0
    private let calendar = Calendar.coach
    private var ticks: MealTicks { .shared }

    var body: some View {
        let _ = version
        let left = GroceryExport.inStore(items) { ticks.isTicked($0, week: monday, calendar: calendar) }
        NavigationStack {
            Group {
                if left.isEmpty {
                    VStack(spacing: Space.l) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.coachSymbol(64))
                            .foregroundStyle(.go)
                        Text("All done")
                            .font(.largeTitle.bold())
                            .accessibilityIdentifier("instore.done")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(left) { item in row(item) }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.canvas)
            // .contain keeps each row's own identifier (an identifier on a bare
            // container is copied onto every child).
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("instore.view")
            .navigationTitle(left.isEmpty ? "" : "\(left.count) to get")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("instore.close")
                }
            }
        }
        // Design N5: kept awake while shopping; back to normal when closed.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func row(_ item: ShoppingItem) -> some View {
        Button {
            ticks.setTicked(true, item, week: monday, calendar: calendar)
            version += 1
        } label: {
            HStack(spacing: Space.l) {
                Image(systemName: "circle")
                    .font(.title)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.title3.weight(.semibold))
                    Text(item.quantityText).font(.body).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.quantityText)")
        .accessibilityHint("Ticks it off")
        .accessibilityIdentifier("instore.item.\(item.id)")
    }
}
