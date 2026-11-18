import CoachCore
import SwiftUI

/// N4 · Ask when needed (ease budget §3): the choices both questions offer,
/// shared with Preferences so the two never drift apart.
enum FoodAsk {
    /// Delivery slots offered, Sunday morning (the default) included.
    static let slots: [Profile.Food.DeliverySlot] = [
        .init(day: .saturday, time: TimeOfDay(hour: 10, minute: 0)),
        .init(day: .sunday, time: TimeOfDay(hour: 10, minute: 0)),
        .init(day: .sunday, time: TimeOfDay(hour: 18, minute: 0)),
        .init(day: .monday, time: TimeOfDay(hour: 19, minute: 0)),
    ]

    /// Longest walk choices for an office lunch, in minutes.
    static let walks = [5, 10, 15]

    /// "Sunday morning", "Monday evening".
    static func label(_ slot: Profile.Food.DeliverySlot) -> String {
        let part = slot.time.hour < 12 ? "morning" : (slot.time.hour < 17 ? "afternoon" : "evening")
        return "\(slot.day.rawValue.capitalized) \(part)"
    }

    /// The slots to show, with `current` added when it isn't one of them.
    static func slotChoices(including current: Profile.Food.DeliverySlot?) -> [Profile.Food.DeliverySlot] {
        guard let current, !slots.contains(current) else { return slots }
        return slots + [current]
    }

    /// "Walk up to 10 min · no dislikes" / "· no mushrooms, olives".
    static func lunchLine(walk: Int, dislikes: [String]) -> String {
        let foods = dislikes.isEmpty ? "no dislikes" : "no " + dislikes.joined(separator: ", ")
        return "Walk up to \(walk) min · \(foods)"
    }
}

/// The shop question, once, on the first visit to Shopping (`ask.shop`):
/// both answers pre-selected, so the usual answer is one tap (A2: 2 / 4).
/// Swiping it away keeps the defaults.
struct AskShopView: View {
    let shops: [NutritionContent.Shop.Option]
    var onDone: (_ shop: String, _ slot: Profile.Food.DeliverySlot) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var shop: String
    @State private var slot = Profile.Food.DeliverySlot()

    init(shops: [NutritionContent.Shop.Option], onDone: @escaping (String, Profile.Food.DeliverySlot) -> Void) {
        self.shops = shops
        self.onDone = onDone
        _shop = State(initialValue: shops.first?.id ?? "waitrose")
    }

    private let columns = [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Where do you shop?").font(.title2.bold())
                LazyVGrid(columns: columns, spacing: Space.s) {
                    ForEach(shops) { option in
                        pill(option.name, on: shop == option.id, id: "ask.shop.option.\(option.id)") { shop = option.id }
                    }
                }
                Text("Delivery").font(.headline)
                LazyVGrid(columns: columns, spacing: Space.s) {
                    ForEach(FoodAsk.slots.indices, id: \.self) { index in
                        let choice = FoodAsk.slots[index]
                        pill(FoodAsk.label(choice), on: slot == choice,
                             id: "ask.shop.slot.\(choice.day.rawValue)-\(choice.time.hour)") { slot = choice }
                    }
                }
                Text("You can change both in Preferences.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .background(Color.canvas)
        .accessibilityIdentifier("ask.shop")
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button("Use these") {
                    onDone(shop, slot)
                    dismiss()
                }
                .buttonStyle(PrimaryActionStyle())
                .accessibilityIdentifier("ask.shop.done")
            }
        }
    }

    private func pill(_ title: String, on: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(on ? Color.onGo : Color.primary)
                .background(on ? Color.go : Color.surface, in: .rect(cornerRadius: Radius.pill))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}

/// The office food question, once, inside the first office day's lunch
/// suggestion (`ask.lunch`): one line and **Looks right**. Ignoring it keeps
/// the defaults (A3: 1 / 3, skipping 0).
struct AskLunchRow: View {
    let defaultWalk: Int
    let dislikes: [String]
    var onDone: (_ walk: Int) -> Void

    @State private var walk: Int?

    var body: some View {
        let minutes = walk ?? defaultWalk
        VStack(alignment: .leading, spacing: Space.s) {
            Menu {
                ForEach(FoodAsk.walks, id: \.self) { choice in
                    Button("Walk up to \(choice) min") { walk = choice }
                }
            } label: {
                HStack {
                    Text(FoodAsk.lunchLine(walk: minutes, dislikes: dislikes))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("ask.lunch.walk")
            Button("Looks right") { onDone(minutes) }
                .buttonStyle(SecondaryActionStyle())
                .accessibilityIdentifier("ask.lunch.done")
        }
        .padding(Space.m)
        .background(Color.surface, in: .rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ask.lunch")
    }
}
