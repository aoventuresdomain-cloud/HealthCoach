import CoachCore
import SwiftData
import SwiftUI

/// Meals, shopping and lunch (board M3-04, plan §4.3–4.5): one screen, three
/// tabs. Planned meals are pre-ticked; nothing here asks a question.
struct MealsHubView: View {
    @Environment(\.modelContext) private var context
    let content: ContentLibrary
    let profile: Profile

    enum Tab: String, CaseIterable, Identifiable {
        case meals = "Meals", shopping = "Shopping", lunch = "Lunch"
        var id: String { rawValue }
    }

    @State private var tab = Tab.meals
    @State private var dayOffset = 0
    @State private var version = 0

    private let calendar = Calendar.coach
    private var ticks: MealTicks { .shared }

    var body: some View {
        let _ = version
        let now = AppClock.now()
        let date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        let monday = AlarmSchedule.mondayOf(date, calendar: calendar)
        // The rules engine's calorie target when it has moved it (M4-01), else the content's.
        let kcalTarget = content.programmes[profile.programme.programmeID].flatMap { programme in
            CoachReview.make(programme: programme, profile: profile,
                             history: (try? SessionLogStore(context: context).all()) ?? [],
                             weights: BodyStats.shared.weightSamples, blocks: CoachBlockStore().all,
                             now: now, calendar: calendar)?.calories.kcal
        }
        let plan = MealPlan.week(monday: monday, content: content.nutrition, lunchOrders: content.lunchOrders.orders,
                                 answers: WeekAnswersStore.shared.answers(weekStarting: monday, calendar: calendar),
                                 programmeID: profile.programme.programmeID, kcalTarget: kcalTarget,
                                 calendar: calendar)
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityIdentifier("meals.tabs")

            switch tab {
            case .meals: meals(plan.day(date, calendar: calendar), date: date)
            case .shopping: shopping(plan, monday: monday)
            case .lunch: lunch(plan.day(now, calendar: calendar))
            }
        }
        .background(Color.canvas)
        .navigationTitle(tab.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Meals

    @ViewBuilder
    private func meals(_ day: MealDay?, date: Date) -> some View {
        List {
            Section {
                HStack {
                    Button { dayOffset -= 1 } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous day")
                        .accessibilityIdentifier("meals.previousDay")
                    Spacer()
                    Text(dayOffset == 0 ? "Today" : date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.headline)
                        .accessibilityIdentifier("meals.day")
                    Spacer()
                    Button { dayOffset += 1 } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next day")
                        .accessibilityIdentifier("meals.nextDay")
                }
                .buttonStyle(.borderless)
            }
            if let day {
                let eaten = day.meals.filter { ticks.isTicked($0, on: date, calendar: calendar) }
                let kcal = eaten.map(\.kcal).reduce(0, +)
                let protein = eaten.map(\.protein).reduce(0, +)
                Section {
                    HStack {
                        Totals(value: kcal, unit: "kcal", target: day.target.kcal,
                               ok: (day.target.kcalMin...day.target.kcalMax).contains(kcal))
                        Totals(value: protein, unit: "g protein", target: day.target.protein,
                               ok: protein >= day.target.proteinMin)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("meals.totals")
                }
                Section {
                    ForEach(day.meals, id: \.id) { meal in
                        mealRow(meal, date: date)
                    }
                    ForEach(day.supplements, id: \.self) { line in
                        Label(line, systemImage: "pills").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Planned meals count as eaten. Untick anything you skipped.")
                }
            } else {
                Text("No meal plan for this day.").foregroundStyle(.secondary)
            }
        }
    }

    private func mealRow(_ meal: PlannedMeal, date: Date) -> some View {
        let ticked = ticks.isTicked(meal, on: date, calendar: calendar)
        return HStack(spacing: 12) {
            Button {
                ticks.setTicked(!ticked, meal, on: date, calendar: calendar)
                version += 1
            } label: {
                Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(ticked ? Color.go : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(ticked ? "Eaten" : "Not eaten")
            .accessibilityIdentifier("meals.tick.\(meal.id)")

            NavigationLink {
                if let id = meal.recipeID, let recipe = content.nutrition.recipe(id) {
                    RecipeView(recipe: recipe, lines: content.nutrition.ingredientLines(recipe))
                } else if let id = meal.lunchOrderID, let order = content.lunchOrders.orders.first(where: { $0.id == id }) {
                    LunchOrderDetail(order: order)
                } else {
                    Text(meal.isBoxNight ? "Cook tonight's recipe box card." : meal.name).padding()
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slotTitle(meal)).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    Text(meal.name).font(.body)
                    Text("\(meal.kcal) kcal · \(meal.protein) g protein").font(.subheadline).foregroundStyle(.secondary)
                }
                .opacity(ticked ? 1 : 0.5)
            }
            .accessibilityIdentifier("meals.row.\(meal.id)")
        }
    }

    private func slotTitle(_ meal: PlannedMeal) -> String {
        var title = meal.slot.rawValue
        if let time = meal.time { title += " · \(time)" }
        if meal.isBoxNight { title += " · box" }
        if meal.isOfficeLunch { title += " · office" }
        return title
    }

    // MARK: Shopping

    private func shopping(_ plan: MealPlan, monday: Date) -> some View {
        let items = ShoppingList.week(plan, content: content.nutrition, tickedStaples: ticks.tickedStaples)
        let aisles = items.reduce(into: [String]()) { if !$0.contains($1.aisle) { $0.append($1.aisle) } }
        return List {
            ForEach(aisles, id: \.self) { aisle in
                Section(aisle) {
                    ForEach(items.filter { $0.aisle == aisle }) { item in
                        shoppingRow(item, monday: monday)
                    }
                }
            }
            if items.isEmpty {
                Text("Nothing to buy this week.").foregroundStyle(.secondary)
            }
        }
    }

    private func shoppingRow(_ item: ShoppingItem, monday: Date) -> some View {
        let ticked = ticks.isTicked(item, week: monday, calendar: calendar)
        return HStack(spacing: 12) {
            Button {
                ticks.setTicked(!ticked, item, week: monday, calendar: calendar)
                version += 1
            } label: {
                Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(ticked ? Color.go : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(ticked ? "Got it" : "To buy")
            .accessibilityIdentifier("shopping.tick.\(item.id)")
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).strikethrough(ticked)
                Text(item.isStaple ? "\(item.quantityText) · staple" : item.quantityText)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if let url = item.searchURL {
                Link(destination: url) { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel("Search the shop for \(item.name)")
            }
        }
        .accessibilityIdentifier("shopping.row.\(item.id)")
    }

    // MARK: Lunch

    private func lunch(_ today: MealDay?) -> some View {
        let suggested = today?.meals.first(where: \.isOfficeLunch)?.lunchOrderID
        return List {
            if suggested == nil {
                Text("Today isn't an office day, so there's no lunch order to suggest.")
                    .foregroundStyle(.secondary)
            }
            ForEach(content.lunchOrders.orders) { order in
                NavigationLink { LunchOrderDetail(order: order) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        if order.id == suggested {
                            Text("TODAY'S SUGGESTION").font(.coachLabel).foregroundStyle(.go)
                        }
                        Text(order.order)
                        Text("\(order.place) · \(order.walkMinutes) min walk · \(order.kcal) kcal · \(order.protein) g · £\(String(format: "%.2f", order.priceGBP))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("lunch.row.\(order.id)")
            }
        }
    }
}

private struct Totals: View {
    let value: Int
    let unit: String
    let target: Int
    let ok: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.coachNumber(22)).foregroundStyle(ok ? Color.go : Color.primary)
            Text("\(unit) of \(target)").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecipeView: View {
    let recipe: NutritionContent.Recipe
    let lines: [String]

    var body: some View {
        List {
            Section {
                Text("\(recipe.minutes) min · makes \(recipe.portions) · \(recipe.perPortion.kcal) kcal, \(recipe.perPortion.protein) g protein each")
                    .foregroundStyle(.secondary)
            }
            Section("Ingredients") {
                ForEach(lines, id: \.self) { Text($0) }
            }
            Section("Method") {
                ForEach(Array(recipe.method.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)").font(.headline).foregroundStyle(.go)
                        Text(step)
                    }
                }
            }
        }
        .navigationTitle(recipe.name)
        .accessibilityIdentifier("recipe.view")
    }
}

struct LunchOrderDetail: View {
    let order: LunchOrder

    var body: some View {
        List {
            Section("Order") { Text(order.order).font(.title3.bold()) }
            Section {
                LabeledContent("Where", value: "\(order.place), \(order.address)")
                LabeledContent("Walk", value: "\(order.walkMinutes) min")
                LabeledContent("Calories", value: "\(order.kcal) kcal")
                LabeledContent("Protein", value: "\(order.protein) g")
                LabeledContent("Price", value: "£\(String(format: "%.2f", order.priceGBP))")
            } footer: {
                Text([order.goodFor.map { "Good for \($0)." }, "Nutrition: \(order.nutritionSource)."].compactMap { $0 }.joined(separator: " "))
            }
        }
        .navigationTitle(order.place)
        .accessibilityIdentifier("lunch.detail")
    }
}
