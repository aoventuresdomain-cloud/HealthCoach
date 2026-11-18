import Foundation

/// One line on the weekly top-up list.
public struct ShoppingItem: Sendable, Equatable, Identifiable {
    /// The ingredient id.
    public let id: String
    public let name: String
    /// The week's merged amount: "1.2 kg", "600 ml", "6".
    public let quantityText: String
    public let aisle: String
    /// Pantry staples are ticked once and stay ticked (M3-03).
    public let isStaple: Bool
    public let ticked: Bool
    /// The chosen shop's search for this item (E5, N4); nil if the URL won't form.
    public let searchURL: URL?
}

/// Board M3-03: one weekly top-up list for everything the box doesn't cover.
/// Quantities are merged across the week, items are sorted by aisle, and
/// staples the owner has ticked stay ticked. Box nights and office lunches add
/// nothing; supplements are staples.
public enum ShoppingList {
    /// `shopID` is the owner's shop (N4, `Profile.food.shop`); nil uses the default.
    public static func week(_ plan: MealPlan, content: NutritionContent,
                            tickedStaples: Set<String> = [], shopID: String? = nil) -> [ShoppingItem] {
        let template = content.shop.searchUrl(for: shopID)
        var totals: [String: Double] = [:]
        for day in plan.days {
            for meal in day.meals {
                guard let id = meal.recipeID, let recipe = content.recipe(id) else { continue }
                for use in recipe.ingredients { totals[use.ingredient, default: 0] += use.qty }
            }
            let month = Calendar(identifier: .gregorian).component(.month, from: day.date)
            for item in content.supplements.items where item.months.contains(month) {
                totals[item.ingredient, default: 0] += item.qty
            }
        }
        let aisleRank = Dictionary(uniqueKeysWithValues: content.aisleOrder.enumerated().map { ($1, $0) })
        return totals.compactMap { id, qty -> ShoppingItem? in
            guard let ingredient = content.ingredients[id] else { return nil }
            return ShoppingItem(id: id, name: ingredient.name,
                                quantityText: NutritionContent.quantity(qty, unit: ingredient.unit),
                                aisle: ingredient.aisle, isStaple: ingredient.staple,
                                ticked: ingredient.staple && tickedStaples.contains(id),
                                searchURL: searchURL(template, term: ingredient.search))
        }
        .sorted {
            let a = aisleRank[$0.aisle] ?? Int.max, b = aisleRank[$1.aisle] ?? Int.max
            return a != b ? a < b : $0.name < $1.name
        }
    }

    static func searchURL(_ template: String, term: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: template.replacingOccurrences(of: "{search}", with: encoded))
    }
}
