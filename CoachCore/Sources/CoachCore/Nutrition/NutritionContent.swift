import Foundation

/// `Content/recipes/recipes.json` (board M3-01 data, M3-02 schema v1).
/// Schema owner: Planner Engineer; content owner: the Researcher.
public struct NutritionContent: VersionedFormat, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let note: String?
    public let shop: Shop
    /// Aisle ids in walking order; every ingredient's aisle is one of them.
    public let aisleOrder: [String]
    /// Keyed by programme id ("phase-1").
    public let dailyTargets: [String: DailyTarget]
    public let snackRule: SnackRule
    public let supplements: Supplements
    public let boxNight: BoxNight
    /// How extras (`kind: extra` recipes) fill a day under the band.
    public let extraRules: ExtraRules
    /// Keyed by ingredient id.
    public let ingredients: [String: Ingredient]
    public internal(set) var recipes: [Recipe]

    public struct Shop: Codable, Sendable, Equatable {
        /// "waitrose" (decision E5).
        public let `default`: String
        /// Contains `{search}`, replaced by the ingredient's search term.
        public let searchUrl: String
        public let decision: String?
        /// N4: the shops offered before the first list, the default first.
        /// Absent: only the default.
        public let options: [Option]?

        public struct Option: Codable, Sendable, Equatable, Identifiable {
            public let id: String
            public let name: String
            /// Contains `{search}`.
            public let searchUrl: String
        }

        /// The shops to offer, the default first.
        public var choices: [Option] {
            let all = options ?? []
            let fallback = Option(id: self.default, name: self.default.capitalized, searchUrl: searchUrl)
            let first = all.first { $0.id == self.default } ?? fallback
            return [first] + all.filter { $0.id != first.id }
        }

        /// The search template for `shopID`, or the default's.
        public func searchUrl(for shopID: String?) -> String {
            shopID.flatMap { id in choices.first { $0.id == id }?.searchUrl } ?? searchUrl
        }
    }

    /// Advisor rule: each planned day is within `kcal` ± `kcalBandPlusMinus`,
    /// never under `kcalFloor`, with at least `proteinMin` protein.
    public struct DailyTarget: Codable, Sendable, Equatable {
        /// The starting target; the rules engine may move it week to week.
        public var kcal: Int
        public let kcalBandPlusMinus: Int
        public let kcalFloor: Int
        public let protein: Int
        public let proteinMin: Int
        public let eatingMoments: Int?
        public let proteinPerMoment: Int?
        public let note: String?

        public var kcalMin: Int { max(kcalFloor, kcal - kcalBandPlusMinus) }
        public var kcalMax: Int { kcal + kcalBandPlusMinus }

        /// The same rules around another weekly target.
        public func with(kcal: Int) -> DailyTarget {
            var copy = self
            copy.kcal = kcal
            return copy
        }
    }

    /// The yogurt pot by default; the shake when the day would be short of protein.
    public struct SnackRule: Codable, Sendable, Equatable {
        public let `default`: String
        public let replaceWith: String
        public let whenPlannedProteinBelow: Int
        /// The Wednesday snack, before basketball.
        public let wednesdayTime: TimeOfDay
        public let note: String?
    }

    public struct Supplements: Codable, Sendable, Equatable {
        public let preTicked: Bool
        public let with: String
        public let items: [Item]
        public let note: String?

        public struct Item: Codable, Sendable, Equatable {
            public let ingredient: String
            /// Short name on the breakfast line ("Creatine").
            public let label: String
            public let qty: Double
            public let unit: String
            /// The label dose when `qty` counts tablets ("10 µg").
            public let dose: String?
            /// Calendar months (1–12) it's taken in.
            public let months: [Int]
            public let note: String?
        }
    }

    public struct BoxNight: Codable, Sendable, Equatable {
        public let id: String
        public let name: String
        public let portions: Int
        public let perPortion: Macros
        public let nightsPerWeek: NightsPerWeek
        /// The weeknights the box covers unless the owner changes them.
        public let defaultNights: [Weekday]
        public let shopping: Bool
        public let note: String?

        public struct NightsPerWeek: Codable, Sendable, Equatable {
            public let min: Int
            public let max: Int
        }
    }

    /// Advisor order (17 Nov) with the Head of Engineering's cap.
    public struct ExtraRules: Codable, Sendable, Equatable {
        public let proteinFirst: ProteinFirst
        /// Tried in order; "a|b|c" means one of those.
        public let order: [String]
        public let maxPerDay: Int
        public let maxPerKind: Int
        public let sideTiming: String?
        public let note: String?

        public struct ProteinFirst: Codable, Sendable, Equatable {
            public let extra: String
            public let whenPlannedProteinBelow: Int
        }

        /// The ids in each step of `order`.
        public var steps: [[String]] { order.map { $0.split(separator: "|").map(String.init) } }
    }

    public struct Macros: Codable, Sendable, Equatable {
        public let kcal: Int
        public let protein: Int
    }

    public struct Ingredient: Codable, Sendable, Equatable {
        public let name: String
        public let aisle: String
        /// Pantry staples are ticked off once, not every week (M3-03).
        public let staple: Bool
        public let per100: Per100
        public let unit: Unit
        /// For `each` items: the weight of one.
        public let gramsEach: Double?
        /// The shop search term.
        public let search: String

        public struct Per100: Codable, Sendable, Equatable {
            public let kcal: Double
            public let protein: Double
        }

        public enum Unit: String, Codable, Sendable { case g, ml, each }
    }

    public struct Recipe: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let kind: Kind
        /// Always 2, except the shake (1: the owner's only).
        public let portions: Int
        public let minutes: Int
        /// One person's share.
        public let perPortion: Macros
        public let ingredients: [Use]
        public let method: [String]
        public let note: String?
        /// Extras only: "side", "second-snack", "richer-breakfast", "protein-boost".
        public let extraKind: String?
        /// Extras only: what it goes with ("dinner", "box-night", "sunday-cook", "lunch", "breakfast", "snack").
        public let addsTo: [String]?
        /// Extras only: the meal it swaps out instead of adding to.
        public let replaces: MealSlot?
        /// Dinners and Sunday cooks: main ingredients and their group (e.g. "salmon",
        /// "oily-fish"), for a dislike filter in Preferences (Advisor A4).
        public let mainIngredients: [String]?

        public enum Kind: String, Codable, Sendable {
            case breakfast, lunch, dinner, snack
            case sundayCook = "sunday-cook"
            /// A defined top-up (a side, a larger portion, a second snack) the
            /// planner adds only to bring a day up into the band.
            case extra
        }

        /// `qty` is the total for all portions, in the ingredient's unit.
        public struct Use: Codable, Sendable, Equatable {
            public let ingredient: String
            public let qty: Double
        }
    }

    public func recipe(_ id: String) -> Recipe? { recipes.first { $0.id == id } }

    public func recipes(_ kind: Recipe.Kind) -> [Recipe] { recipes.filter { $0.kind == kind } }

    /// "600 g 0% fat Greek yogurt", for the recipe screen.
    public func ingredientLines(_ recipe: Recipe) -> [String] {
        recipe.ingredients.compactMap { use in
            guard let ingredient = ingredients[use.ingredient] else { return nil }
            return "\(Self.quantity(use.qty, unit: ingredient.unit)) \(ingredient.name)"
        }
    }

    /// "1.2 kg", "600 g", "300 ml", "1.5 l", "6".
    public static func quantity(_ qty: Double, unit: Ingredient.Unit) -> String {
        func trim(_ v: Double) -> String {
            let tenths = (v * 10).rounded() / 10
            return tenths == tenths.rounded() ? String(Int(tenths)) : WeightTrend.oneDecimal(tenths)
        }
        switch unit {
        case .each: return trim(qty.rounded(.up))
        case .g: return qty >= 1000 ? "\(trim(qty / 1000)) kg" : "\(trim(qty)) g"
        case .ml: return qty >= 1000 ? "\(trim(qty / 1000)) l" : "\(trim(qty)) ml"
        }
    }

    /// Rule breaks, so a bad content edit fails `swift test` rather than the app.
    public func problems() -> [String] {
        var out: [String] = []
        if !shop.searchUrl.contains("{search}") { out.append("shop.searchUrl has no {search}") }
        for option in shop.options ?? [] where !option.searchUrl.contains("{search}") {
            out.append("shop option \(option.id): searchUrl has no {search}")
        }
        for (id, ingredient) in ingredients.sorted(by: { $0.key < $1.key }) {
            if !aisleOrder.contains(ingredient.aisle) { out.append("ingredient \(id): aisle \(ingredient.aisle) not in aisleOrder") }
        }
        var seen = Set<String>()
        for recipe in recipes {
            if !seen.insert(recipe.id).inserted { out.append("recipe \(recipe.id) appears twice") }
            let expected = recipe.id == snackRule.replaceWith ? 1 : 2
            if recipe.kind == .extra ? !(1...2).contains(recipe.portions) : recipe.portions != expected { out.append("recipe \(recipe.id): \(recipe.portions) portions, expected \(expected)") }
            if recipe.method.isEmpty { out.append("recipe \(recipe.id): no method") }
            for use in recipe.ingredients where ingredients[use.ingredient] == nil {
                out.append("recipe \(recipe.id): unknown ingredient \(use.ingredient)")
            }
            let text = ([recipe.name] + recipe.method).joined(separator: " ").lowercased()
            for raw in Self.rawFish where text.contains(raw) { out.append("recipe \(recipe.id): mentions \(raw) (no raw fish)") }
        }
        for id in [snackRule.default, snackRule.replaceWith] where recipe(id)?.kind != .snack {
            out.append("snackRule: \(id) is not a snack recipe")
        }
        for item in supplements.items {
            if ingredients[item.ingredient] == nil { out.append("supplement \(item.ingredient): unknown ingredient") }
            if item.months.isEmpty || !item.months.allSatisfy({ (1...12).contains($0) }) {
                out.append("supplement \(item.ingredient): months must be 1–12")
            }
        }
        let extraIDs = Set(recipes(.extra).map(\.id))
        for recipe in recipes(.extra) where recipe.extraKind == nil || (recipe.addsTo ?? []).isEmpty {
            out.append("extra \(recipe.id): needs extraKind and addsTo")
        }
        for id in extraRules.steps.flatMap({ $0 }) + [extraRules.proteinFirst.extra] where !extraIDs.contains(id) {
            out.append("extraRules: \(id) is not an extra")
        }
        if extraRules.maxPerDay < 1 || extraRules.maxPerKind < 1 { out.append("extraRules: limits must be at least 1") }
        for kind in [Recipe.Kind.breakfast, .lunch, .dinner, .sundayCook] where recipes(kind).isEmpty {
            out.append("no \(kind.rawValue) recipes")
        }
        let nights = boxNight.defaultNights.count
        if nights < boxNight.nightsPerWeek.min || nights > boxNight.nightsPerWeek.max {
            out.append("boxNight.defaultNights: \(nights) nights, expected \(boxNight.nightsPerWeek.min)–\(boxNight.nightsPerWeek.max)")
        }
        if boxNight.defaultNights.contains(.sunday) { out.append("boxNight.defaultNights: Sunday is the Sunday cook") }
        // Advisor rule (gate 1–2): target ± 150 kcal, never under 1,700, protein ≥ 150 g.
        for (id, t) in dailyTargets.sorted(by: { $0.key < $1.key }) {
            if t.kcalBandPlusMinus > Self.kcalTolerance || t.kcalFloor < Self.kcalFloor {
                out.append("dailyTargets.\(id): band ± \(t.kcalBandPlusMinus) or floor \(t.kcalFloor) is looser than ± \(Self.kcalTolerance), \(Self.kcalFloor)")
            }
            if t.kcal < t.kcalFloor { out.append("dailyTargets.\(id): target under its floor") }
            if t.proteinMin < 150 || t.proteinMin > t.protein { out.append("dailyTargets.\(id): proteinMin must be 150–\(t.protein)") }
        }
        return out
    }

    /// Advisor rule, shared with the rules engine (`CalorieTarget.dayBand`).
    public static var kcalFloor: Int { CalorieRules.dayFloorKcal }
    public static var kcalTolerance: Int { CalorieRules.dayBandKcal }

    static let rawFish = ["sushi", "sashimi", "poke", "tartare", "ceviche", "smoked salmon"]
}

/// `Content/lunch-orders.json`: office-day orders near St James's Market.
public struct LunchOrders: VersionedFormat, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let note: String?
    public let origin: Origin
    public let orders: [LunchOrder]

    public struct Origin: Codable, Sendable, Equatable {
        public let name: String
        public let postcode: String
        public let maxWalkMinutes: Int
    }

    public func problems() -> [String] {
        var out: [String] = []
        if orders.isEmpty { out.append("no orders") }
        var seen = Set<String>()
        for order in orders {
            if !seen.insert(order.id).inserted { out.append("order \(order.id) appears twice") }
            if order.walkMinutes > origin.maxWalkMinutes {
                out.append("order \(order.id): \(order.walkMinutes) min walk, over \(origin.maxWalkMinutes)")
            }
            if order.kcal <= 0 || order.protein <= 0 { out.append("order \(order.id): no kcal or protein") }
            let text = order.order.lowercased()
            for raw in NutritionContent.rawFish where text.contains(raw) && !text.contains("no \(raw)") {
                out.append("order \(order.id): mentions \(raw) (no raw fish)")
            }
        }
        return out
    }
}

public struct LunchOrder: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let place: String
    public let address: String
    public let walkMinutes: Int
    public let cuisine: String?
    public let order: String
    public let kcal: Int
    public let protein: Int
    public let priceGBP: Double
    /// Where the figures came from; "estimate" when none were published.
    public let nutritionSource: String
    public let goodFor: String?
    public let note: String?
}
