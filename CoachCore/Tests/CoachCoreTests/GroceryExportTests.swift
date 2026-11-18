import Foundation
import Testing
@testable import CoachCore

/// Board N5: "Send to Reminders" writes one list, reused, with quantities, and
/// never duplicates; in-store mode shows only what's left, in aisle order.
@Suite struct GroceryExportTests {
    private func item(_ id: String, _ name: String, _ qty: String, aisle: String = "produce",
                      staple: Bool = false) -> ShoppingItem {
        ShoppingItem(id: id, name: name, quantityText: qty, aisle: aisle, isStaple: staple,
                     ticked: false, searchURL: nil)
    }

    private func week() throws -> [ShoppingItem] {
        let lib = try ContentLibrary.load(from: contentRoot)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23))!
        let plan = MealPlan.week(monday: monday, content: lib.nutrition, lunchOrders: lib.lunchOrders.orders,
                                 answers: WeekAnswers(officeDays: []), programmeID: "phase-1", calendar: calendar)
        return ShoppingList.week(plan, content: lib.nutrition)
    }

    @Test func eachReminderCarriesTheQuantityAndOnlyNameAndAmount() throws {
        let items = try week()
        #expect(!items.isEmpty)
        let changes = GroceryExport.changes(send: items, existing: [])
        #expect(changes.add.count == items.count)
        #expect(changes.retitle.isEmpty && changes.remove.isEmpty)
        for (add, item) in zip(changes.add, items) {
            #expect(add.title == "\(item.name) · \(item.quantityText)")
            #expect(GroceryExport.itemID(notes: add.notes) == item.id)
            // Gap plan §4.7: only the name, amount and id; no calories or targets.
            let lowered = (add.title + add.notes).lowercased()
            #expect(!lowered.contains("kcal"), "\(add.title)")
            #expect(add.notes == "healthcoach:\(item.id)")
        }
    }

    @Test func sendingAgainChangesNothing() throws {
        let items = try week()
        let first = GroceryExport.changes(send: items, existing: [])
        let existing = first.add.enumerated().map {
            GroceryExport.Existing(id: "r\($0.offset)", title: $0.element.title, notes: $0.element.notes, completed: false)
        }
        #expect(GroceryExport.changes(send: items, existing: existing).isEmpty)
    }

    @Test func aChangedQuantityRetitlesAndATickedItemLeaves() {
        let rice = item("rice", "Rice", "500 g")
        let existing = [
            GroceryExport.Existing(id: "a", title: "Rice · 250 g", notes: "healthcoach:rice", completed: false),
            GroceryExport.Existing(id: "b", title: "Eggs · 6", notes: "healthcoach:eggs", completed: false),
            GroceryExport.Existing(id: "c", title: "Oats · 1 kg", notes: "healthcoach:oats", completed: false),
        ]
        // Eggs got ticked (already have them), oats left the week.
        let changes = GroceryExport.changes(send: [rice], existing: existing)
        #expect(changes.retitle == [.init(id: "a", title: "Rice · 500 g")])
        #expect(Set(changes.remove) == ["b", "c"])
        #expect(changes.add.isEmpty)
    }

    @Test func aPersonsOwnRemindersAreNeverTouched() {
        let existing = [
            GroceryExport.Existing(id: "p1", title: "Birthday candles", notes: nil, completed: false),
            GroceryExport.Existing(id: "p2", title: "Milk", notes: "the oat one", completed: false),
        ]
        let changes = GroceryExport.changes(send: [item("milk", "Milk", "2 l")], existing: existing)
        #expect(changes.remove.isEmpty && changes.retitle.isEmpty)
        #expect(changes.add == [.init(title: "Milk · 2 l", notes: "healthcoach:milk")])
    }

    @Test func boughtStaysAsHistoryAndADuplicateIsCleanedUp() {
        let existing = [
            GroceryExport.Existing(id: "done", title: "Rice · 500 g", notes: "healthcoach:rice", completed: true),
            GroceryExport.Existing(id: "x1", title: "Eggs · 6", notes: "healthcoach:eggs", completed: false),
            GroceryExport.Existing(id: "x2", title: "Eggs · 6", notes: "healthcoach:eggs", completed: false),
        ]
        let changes = GroceryExport.changes(send: [item("rice", "Rice", "500 g"), item("eggs", "Eggs", "6")],
                                            existing: existing)
        // Rice bought last time and wanted again: a new open one; the done one stays.
        #expect(changes.add == [.init(title: "Rice · 500 g", notes: "healthcoach:rice")])
        #expect(changes.remove == ["x2"])
        #expect(changes.retitle.isEmpty)
    }

    @Test func tickedItemsAreNotSentAndInStoreKeepsAisleOrder() throws {
        let items = try week()
        let ticked: Set<String> = [items[0].id, items[2].id]
        let send = GroceryExport.toSend(items) { ticked.contains($0.id) }
        #expect(send.count == items.count - 2 && !send.contains { ticked.contains($0.id) })
        let shown = GroceryExport.inStore(items) { ticked.contains($0.id) }
        #expect(shown.map(\.id) == items.map(\.id).filter { !ticked.contains($0) })
        #expect(GroceryExport.inStore(items) { _ in true }.isEmpty)
    }

    @Test func markerParsing() {
        #expect(GroceryExport.itemID(notes: "healthcoach:rice") == "rice")
        #expect(GroceryExport.itemID(notes: "healthcoach:") == nil)
        #expect(GroceryExport.itemID(notes: "rice") == nil)
        #expect(GroceryExport.itemID(notes: nil) == nil)
        #expect(GroceryExport.title(item("salt", "Salt", "")) == "Salt")
    }
}
