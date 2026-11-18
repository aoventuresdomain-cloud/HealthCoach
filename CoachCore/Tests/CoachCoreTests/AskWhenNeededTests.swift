import Foundation
import Testing
@testable import CoachCore

/// Board N4: ask when needed. The shop and delivery slot before the first
/// list (Waitrose and Sunday if skipped); the office-lunch walk on the first
/// office day; both kept in Preferences.
@Suite struct AskWhenNeededTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func at(_ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
    }

    private func library() throws -> ContentLibrary { try ContentLibrary.load(from: contentRoot) }

    private func plan(_ lib: ContentLibrary, orders: [LunchOrder],
                      office: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]) -> MealPlan {
        MealPlan.week(monday: at(11, 23), content: lib.nutrition, lunchOrders: orders,
                      answers: WeekAnswers(officeDays: office), programmeID: "phase-1", calendar: calendar)
    }

    // MARK: Shop

    @Test func theShopsOfferedStartWithWaitrose() throws {
        let shop = try library().nutrition.shop
        #expect(shop.choices.first?.id == "waitrose")
        #expect(shop.choices.map(\.id) == ["waitrose", "ocado", "marks-and-spencer", "tesco", "sainsburys"])
        #expect(Set(shop.choices.map(\.id)).count == shop.choices.count)
        #expect(try library().nutrition.problems().isEmpty)
    }

    @Test func searchLinksFollowTheChoice() throws {
        let lib = try library()
        let week = plan(lib, orders: lib.lunchOrders.orders, office: [])
        let hosts: [String?: String] = [nil: "www.waitrose.com", "waitrose": "www.waitrose.com",
                                        "tesco": "www.tesco.com", "ocado": "www.ocado.com",
                                        "marks-and-spencer": "www.ocado.com",
                                        "sainsburys": "www.sainsburys.co.uk", "no-such-shop": "www.waitrose.com"]
        for (shopID, host) in hosts {
            let items = ShoppingList.week(week, content: lib.nutrition, shopID: shopID)
            #expect(!items.isEmpty)
            for item in items {
                #expect(item.searchURL?.host == host, "\(shopID ?? "default"): \(item.name)")
            }
        }
        // M&S goes through Ocado with the brand in the search.
        let mands = ShoppingList.week(week, content: lib.nutrition, shopID: "marks-and-spencer")
        let first = try #require(mands.first?.searchURL?.absoluteString)
        #expect(first.contains("entry=M%26S%20"), "\(first)")
        // The same items and quantities whichever shop.
        let names = { (id: String?) in ShoppingList.week(week, content: lib.nutrition, shopID: id).map(\.quantityText) }
        #expect(names("tesco") == names(nil))
    }

    @Test func skippingTheShopQuestionGivesWaitroseAndSunday() {
        var food = Profile.Food()
        #expect(food.needsShopQuestion)
        food.skipShopQuestion(defaultShop: "waitrose")
        #expect(food.shop == "waitrose")
        #expect(food.delivery == Profile.Food.DeliverySlot(day: .sunday, time: TimeOfDay(hour: 10, minute: 0)))
        #expect(!food.needsShopQuestion)

        // Skipping never overwrites an answer.
        var answered = Profile.Food()
        answered.shop = "tesco"
        answered.delivery = .init(day: .saturday, time: TimeOfDay(hour: 8, minute: 0))
        answered.skipShopQuestion(defaultShop: "waitrose")
        #expect(answered.shop == "tesco" && answered.delivery?.day == .saturday)
    }

    // MARK: Office lunch

    @Test func theOfficeQuestionIsAskedOnceOnAnOfficeDay() {
        var food = Profile.Food()
        #expect(!food.needsOfficeLunchQuestion(isOfficeDay: false))
        #expect(food.needsOfficeLunchQuestion(isOfficeDay: true))
        food.officeLunchMaxWalkMinutes = 8 // answered, or skipped with the default
        #expect(!food.needsOfficeLunchQuestion(isOfficeDay: true))
    }

    @Test func theWalkLimitFiltersTheOrders() throws {
        let lib = try library()
        var food = Profile.Food()
        // Not asked yet: the content's own limit, so every order.
        #expect(food.lunchOrders(lib.lunchOrders) == lib.lunchOrders.orders)
        food.officeLunchMaxWalkMinutes = 5
        let near = food.lunchOrders(lib.lunchOrders)
        #expect(!near.isEmpty && near.count < lib.lunchOrders.orders.count)
        #expect(near.allSatisfy { $0.walkMinutes <= 5 })

        // The week's office lunches come only from those orders.
        let week = plan(lib, orders: near)
        let used = Set(week.days.flatMap(\.meals).compactMap(\.lunchOrderID))
        #expect(!used.isEmpty && used.isSubset(of: Set(near.map(\.id))))

        // Nothing that close: a home lunch to take in, not a gap.
        food.officeLunchMaxWalkMinutes = 1
        #expect(food.lunchOrders(lib.lunchOrders).isEmpty)
        let none = plan(lib, orders: food.lunchOrders(lib.lunchOrders))
        for day in none.days {
            let hasLunch = day.meals.contains { $0.slot == .lunch }
            let office = day.meals.contains { $0.isOfficeLunch }
            #expect(hasLunch && !office, "\(day.date)")
        }
    }

    // MARK: Preferences

    @Test func bothAnswersLiveInPreferencesAndOldProfilesStillLoad() throws {
        var profile = Profile()
        profile.food.shop = "ocado"
        profile.food.delivery = .init(day: .friday, time: TimeOfDay(hour: 18, minute: 0))
        profile.food.officeLunchMaxWalkMinutes = 5
        let round = try Profile.decode(JSONEncoder().encode(profile), file: "profile.json")
        #expect(round.food == profile.food)

        // A profile saved before N4 has no answers yet, so the questions ask.
        var old = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(Profile())) as? [String: Any])
        old["food"] = ["dislikes": ["mushrooms"]]
        let decoded = try Profile.decode(JSONSerialization.data(withJSONObject: old), file: "profile.json")
        #expect(decoded.food.dislikes == ["mushrooms"])
        #expect(decoded.food.needsShopQuestion && decoded.food.officeLunchMaxWalkMinutes == nil)

        // Editing the shop in Preferences applies from tomorrow, as other edits.
        profile.confirmed = true
        var edited = profile.preferences
        edited.food.shop = "tesco"
        let saved = profile.scheduling(edited, now: at(11, 23, 12), calendar: calendar)
        #expect(saved.effective(on: at(11, 23, 20), calendar: calendar).food.shop == "ocado")
        #expect(saved.effective(on: at(11, 24, 7), calendar: calendar).food.shop == "tesco")
    }

    @Test func anAnswerAppliesAtOnceAndSurvivesAPendingEdit() {
        var profile = Profile()
        profile.confirmed = true
        var edited = profile.preferences
        edited.food.dislikes = ["olives"]
        profile = profile.scheduling(edited, now: at(11, 23, 12), calendar: calendar)
        // The first office day is the same evening's question.
        profile.answerFoodQuestion { $0.officeLunchMaxWalkMinutes = 5 }
        profile.answerFoodQuestion { $0.skipShopQuestion(defaultShop: "waitrose") }
        let tonight = profile.effective(on: at(11, 23, 20), calendar: calendar).food
        let tomorrow = profile.effective(on: at(11, 24, 7), calendar: calendar).food
        #expect(tonight.officeLunchMaxWalkMinutes == 5 && tonight.shop == "waitrose")
        #expect(tomorrow.officeLunchMaxWalkMinutes == 5 && tomorrow.shop == "waitrose")
        #expect(tomorrow.dislikes == ["olives"] && tonight.dislikes.isEmpty)
    }
}
