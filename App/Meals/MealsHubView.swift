import CoachCore
import SwiftData
import SwiftUI

/// Meals, shopping and lunch (board M3-04, plan §4.3–4.5): one screen, three
/// tabs. Planned meals are pre-ticked; nothing here asks a question.
struct MealsHubView: View {
    @Environment(\.modelContext) private var context
    let content: ContentLibrary
    let profile: Profile
    /// N4: stores an answer to the shop or office-lunch question at once.
    var onAnswerFood: ((inout Profile.Food) -> Void) -> Void = { _ in }

    enum Tab: String, CaseIterable, Identifiable {
        case meals = "Meals", shopping = "Shopping", lunch = "Lunch"
        var id: String { rawValue }
    }

    @State private var tab = Tab.meals
    @State private var dayOffset = 0
    @State private var version = 0
    /// Lunch: "Another" steps through the other orders from today's suggestion.
    @State private var lunchStep = 0
    /// N4: the shop question, once, on the first visit to Shopping.
    @State private var askShop = false
    @State private var answeredShop = false
    @State private var openedFromReminder = false

    private let calendar = Calendar.coach
    private var ticks: MealTicks { .shared }
    private var social: SocialMealStore { .shared }

    var body: some View {
        let _ = version
        let now = AppClock.now()
        let date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        let monday = AlarmSchedule.mondayOf(date, calendar: calendar)
        let answers = WeekAnswersStore.shared.answers(weekStarting: monday, calendar: calendar)
        // C1: the week shown is planned at the coach's target for that week (M4-01,
        // imports included), so next week's meals follow Monday's check;
        // C3: its training days take the extras first. C6: the phase in force that week.
        let basePlan = content.programme(for: profile, on: date, calendar: calendar).map { programme in
            MealPlan.coached(monday: monday, now: now, content: content.nutrition,
                             lunchOrders: profile.food.lunchOrders(content.lunchOrders), answers: answers, programme: programme,
                             profile: profile, history: (try? SessionLogStore(context: context).all()) ?? [],
                             weights: BodyStats.shared.weightHistory, blocks: CoachBlockStore().all,
                             // N3: each day's dislikes, so an edit applies from tomorrow.
                             dislikes: { profile.dislikes(on: $0, calendar: calendar) },
                             calendar: calendar)
        } ?? MealPlan.week(monday: monday, content: content.nutrition, lunchOrders: profile.food.lunchOrders(content.lunchOrders),
                           answers: answers, programmeID: profile.programme.programmeID,
                           dislikes: { profile.dislikes(on: $0, calendar: calendar) }, calendar: calendar)
        // C4: a social meal replaces that day's dinner; the rest of the week trims a little.
        let plan = basePlan.withSocialMeals(social.dates(calendar: calendar), calendar: calendar)
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityIdentifier("meals.tabs")

            switch tab {
            case .meals: meals(plan.day(date, calendar: calendar), date: date, monday: monday)
            case .shopping: shopping(plan, monday: monday)
            case .lunch: lunch(plan.day(now, calendar: calendar))
            }
        }
        .background(Color.canvas)
        // N9 (W5): the delivery reminder opens Shopping.
        .task(id: NotificationTaps.shared.pending) {
            guard NotificationTaps.shared.pending == .shopping else { return }
            NotificationTaps.shared.pending = nil
            // The reminder only exists once a slot is chosen, so it never asks the shop question.
            openedFromReminder = true
            tab = .shopping
        }
        .onAppear { askShopIfNeeded() }
        .onChange(of: tab) { askShopIfNeeded() }
        .sheet(isPresented: $askShop, onDismiss: {
            // Swiped away: the defaults (Waitrose, Sunday morning) apply, and it isn't asked again.
            guard !answeredShop else { return }
            let shop = content.nutrition.shop.default
            onAnswerFood { $0.skipShopQuestion(defaultShop: shop) }
        }) {
            AskShopView(shops: content.nutrition.shop.choices) { shop, slot in
                answeredShop = true
                onAnswerFood { food in
                    food.shop = shop
                    food.delivery = slot
                }
            }
            .presentationDetents([.large])
        }
        // UI-12: the tab bar already says Meals. On the Meals tab the nav bar
        // carries the day, with ‹ › either side; the other tabs have no title.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if tab == .meals {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dayOffset -= 1 } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous day")
                        .accessibilityIdentifier("meals.previousDay")
                }
                ToolbarItem(placement: .principal) {
                    Text(dayOffset == 0 ? "Today" : date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.headline)
                        .accessibilityIdentifier("meals.day")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dayOffset += 1 } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next day")
                        .accessibilityIdentifier("meals.nextDay")
                }
            }
        }
    }

    private func askShopIfNeeded() {
        if tab == .shopping, profile.food.needsShopQuestion, !answeredShop, !openedFromReminder { askShop = true }
    }

    // MARK: Meals

    @ViewBuilder
    private func meals(_ day: MealDay?, date: Date, monday: Date) -> some View {
        List {
            if let day {
                let eaten = day.meals.filter { ticks.isTicked($0, on: date, calendar: calendar) }
                let kcal = eaten.map(\.kcal).reduce(0, +)
                let protein = eaten.map(\.protein).reduce(0, +)
                Section {
                    ForEach(day.meals, id: \.id) { meal in
                        mealRow(meal, date: date)
                    }
                    ForEach(day.supplements, id: \.self) { line in
                        Label(line, systemImage: "pills").foregroundStyle(.secondary)
                    }
                } header: {
                    // UI-12: one quiet line, no targets; the engine steers by the scale.
                    Text("\(kcal.formatted()) kcal · \(protein) g protein")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .accessibilityIdentifier("meals.totals")
                } footer: {
                    // Needed once; obvious after the first untick.
                    if !ticks.hasEverUnticked {
                        Text("Planned meals count as eaten. Untick anything you skipped.")
                    }
                }
                socialRow(date: date, monday: monday, isSocial: day.isSocial)
            } else {
                Text("No meal plan for this day.").foregroundStyle(.secondary)
            }
        }
    }

    /// C4: one tap for dinner out, with the week's count beside it ("1 of 2").
    /// A third is allowed; the count turns orange and the coach summary says so.
    private func socialRow(date: Date, monday: Date, isSocial: Bool) -> some View {
        let count = SocialMeals.count(social.dates(calendar: calendar), weekOf: monday, calendar: calendar)
        return Section {
            HStack {
                Button {
                    social.toggle(date, calendar: calendar)
                    version += 1
                } label: {
                    Label(isSocial ? "Undo social meal" : "Social meal",
                          systemImage: isSocial ? "arrow.uturn.backward" : "fork.knife.circle")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderless) // only the button taps, not the whole row
                .accessibilityHint(isSocial ? "Puts the planned dinner back" : "Dinner out instead of the planned one")
                .accessibilityIdentifier("meals.social")
                Spacer()
                Text("\(count.text) this week")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(count.flagged ? Color.caution : Color.secondary)
                    .accessibilityIdentifier("meals.socialCount")
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
                    .frame(minWidth: 44, minHeight: 44)  // 44 pt hit area round the 24 pt circle
                    .contentShape(.rect)
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
        let items = ShoppingList.week(plan, content: content.nutrition, tickedStaples: ticks.tickedStaples,
                                      shopID: profile.food.shop)
        let aisles = items.reduce(into: [String]()) { if !$0.contains($1.aisle) { $0.append($1.aisle) } }
        let toGet = items.filter { !ticks.isTicked($0, week: monday, calendar: calendar) }.count
        return List {
            ForEach(Array(aisles.enumerated()), id: \.element) { index, aisle in
                Section {
                    ForEach(items.filter { $0.aisle == aisle }) { item in
                        shoppingRow(item, monday: monday)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: Space.m) {
                        if index == 0 {
                            // UI-12: the shop named once, with a count that shrinks as you tick.
                            // QA-35: a header line like Meals' totals, not a list row (no gap).
                            Text("\(shopName) · \(toGet) to get")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                                .accessibilityIdentifier("shopping.header")
                            // N5: after a send, for the rest of the day.
                            GrocerySentLine(now: AppClock.now())
                        }
                        Text(aisle.prefix(1).uppercased() + aisle.dropFirst())  // QA-29: "Produce", not "produce"
                    }
                }
            }
            if items.isEmpty {
                Text("Nothing to buy this week.").foregroundStyle(.secondary)
            }
        }
        // N5: "In the shop" (primary) and "Send to Reminders".
        .safeAreaInset(edge: .bottom) {
            GroceryActionBar(items: items, monday: monday) { version += 1 }
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
                    .frame(minWidth: 44, minHeight: 44)  // 44 pt hit area round the 24 pt circle
                    .contentShape(.rect)
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
                // Plan §4.4: opens the shop's search in Safari. Outbound only; nothing is sent.
                // UI-12: a quiet 44 pt magnifier; the shop is named once in the header.
                Link(destination: url) {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Search \(shopName) for \(item.name)")
                .accessibilityIdentifier("shopping.search.\(item.id)")
            }
        }
        // .contain keeps the tick and search link as their own elements; an
        // identifier on a bare stack is copied onto every child and hid them.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shopping.row.\(item.id)")
    }

    private var shopName: String {
        let shop = content.nutrition.shop
        return shop.choices.first { $0.id == (profile.food.shop ?? shop.default) }?.name ?? shop.default.capitalized
    }

    // MARK: Lunch

    /// UI-12: on an office day one order, large, with "Another"; otherwise one
    /// line. The full list is one tap away either way.
    private func lunch(_ today: MealDay?) -> some View {
        // N4: only orders within the owner's walk.
        let orders = profile.food.lunchOrders(content.lunchOrders)
        let suggested = today?.meals.first(where: \.isOfficeLunch)?.lunchOrderID
        let first = orders.firstIndex { $0.id == suggested }
        let shown = first.map { orders[($0 + lunchStep) % max(orders.count, 1)] }
        return ScrollView {
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
                    // N4: the office food question, once, on the first office day.
                    if profile.food.needsOfficeLunchQuestion(isOfficeDay: suggested != nil) {
                        AskLunchRow(defaultWalk: content.lunchOrders.origin.maxWalkMinutes,
                                    dislikes: profile.food.dislikes) { walk in
                            onAnswerFood { $0.officeLunchMaxWalkMinutes = walk }
                        }
                    }
                    if orders.count > 1 {
                        Button("Another") { lunchStep += 1 }
                            .buttonStyle(SecondaryActionStyle())
                            .accessibilityIdentifier("lunch.another")
                    }
                } else {
                    Text("No office today.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("lunch.noOffice")
                }
                NavigationLink {
                    LunchOrdersList(orders: orders)
                } label: {
                    HStack {
                        Text("All \(orders.count) orders")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)
                    .padding(.horizontal, Space.l)
                    .background(Color.surface, in: .rect(cornerRadius: Radius.secondary))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("lunch.all")
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.s)
        }
    }
}

/// Every lunch order, two lines each; kcal and price are on the detail screen.
private struct LunchOrdersList: View {
    let orders: [LunchOrder]

    var body: some View {
        List {
            ForEach(orders) { order in
                NavigationLink { LunchOrderDetail(order: order) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(order.order)
                        Text("\(order.place) · \(order.walkMinutes) min · \(order.protein) g")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("lunch.row.\(order.id)")
            }
        }
        .navigationTitle("Lunch orders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecipeView: View {
    let recipe: NutritionContent.Recipe
    let lines: [String]

    var body: some View {
        List {
            // QA-34: plain secondary text, not a card; it heads the ingredients.
            Section {
                ForEach(lines, id: \.self) { Text($0) }
            } header: {
                VStack(alignment: .leading, spacing: Space.m) {
                    Text("\(recipe.minutes) min · makes \(recipe.portions) · \(recipe.perPortion.kcal) kcal, \(recipe.perPortion.protein) g protein each")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .accessibilityIdentifier("recipe.meta")
                    Text("Ingredients")
                }
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
