import Foundation

/// Board N3, Advisor A4(f): foods the owner doesn't eat. The list is set in
/// Preferences, empty by default, and the meal plan always respects it: a
/// recipe or lunch order is never planned when a dislike starts a word of its
/// name or of any of its ingredients, ignoring case and accents. So
/// "mushroom" leaves out "Chestnut mushrooms" and "tuna" a tuna salad. Being
/// word starts, "pea" also leaves out peanut butter: stricter, never looser.
public enum Dislikes {
    /// Lower case, no accents, every run of non-letters and non-digits one space.
    static func normalised(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        let words = folded.split { !($0.isLetter || $0.isNumber) }
        return words.joined(separator: " ")
    }

    /// True when `dislike` starts a word of `text` (several words: a run of words).
    public static func matches(_ dislike: String, _ text: String) -> Bool {
        let term = normalised(dislike)
        guard !term.isEmpty else { return false }
        return (" " + normalised(text)).contains(" " + term)
    }

    static func matchesAny(_ dislikes: [String], _ texts: [String]) -> Bool {
        dislikes.contains { dislike in texts.contains { matches(dislike, $0) } }
    }
}

extension NutritionContent {
    /// True when a dislike matches the recipe's name, or the name or id of any of its ingredients.
    public func isDisliked(_ recipe: Recipe, dislikes: [String]) -> Bool {
        guard !dislikes.isEmpty else { return false }
        var texts = [recipe.name]
        for use in recipe.ingredients {
            texts.append(use.ingredient)
            if let ingredient = ingredients[use.ingredient] { texts.append(ingredient.name) }
        }
        return Dislikes.matchesAny(dislikes, texts)
    }

    /// The content without any recipe a dislike matches.
    public func excluding(dislikes: [String]) -> NutritionContent {
        guard !dislikes.isEmpty else { return self }
        var copy = self
        copy.recipes = recipes.filter { !isDisliked($0, dislikes: dislikes) }
        return copy
    }
}

extension LunchOrder {
    /// True when a dislike matches the order (the place's name doesn't count).
    public func isDisliked(by dislikes: [String]) -> Bool {
        Dislikes.matchesAny(dislikes, [order])
    }
}
