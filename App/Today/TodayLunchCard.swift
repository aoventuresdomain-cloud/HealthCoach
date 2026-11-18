import CoachCore
import SwiftUI

/// N9a: the office lunch card, opened from Today's lunch row (D8: seen with 0
/// taps on the row; D9: "Another" is one more). On the first office day it
/// carries N4's one-line question (A3: 1 tap to see the suggestion, skipping
/// keeps the defaults; picking a walk or Looks right answers it once).
struct TodayLunchCard: View {
    let meals: MealDay?
    let orders: [LunchOrder]
    let food: Profile.Food
    /// The content's walk limit, used until the owner answers.
    let defaultWalk: Int
    var onWalk: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    var body: some View {
        let shown = OfficeLunch.suggestion(meals, orders: orders, step: step)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    if let shown {
                        NavigationLink { LunchOrderDetail(order: shown) } label: {
                            VStack(alignment: .leading, spacing: Space.s) {
                                Text("TODAY").font(.coachLabel).foregroundStyle(.go)
                                Text(shown.order).font(.title2.bold()).multilineTextAlignment(.leading)
                                Text("\(shown.place) · \(shown.walkMinutes) min · \(shown.protein) g protein")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Space.xl)
                            .background(Color.surface, in: .rect(cornerRadius: Radius.card))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("lunch.suggestion")
                        if food.needsOfficeLunchQuestion(isOfficeDay: true) {
                            AskLunchRow(defaultWalk: defaultWalk, dislikes: food.dislikes, onDone: onWalk)
                        }
                        if orders.count > 1 {
                            Button("Another") { step += 1 }
                                .buttonStyle(SecondaryActionStyle())
                                .accessibilityIdentifier("lunch.another")
                        }
                    } else {
                        // The answer narrowed the walk past today's order: the row goes on the next plan.
                        Text("No office lunch today.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("lunch.noOffice")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.canvas)
            .navigationTitle("Lunch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("lunch.close")
                }
            }
        }
    }
}
