import Foundation

/// Board N5: what "Send to Reminders" writes, and what in-store mode shows.
/// Pure, so the rules are unit-tested here and the app only talks to EventKit.
///
/// The list is shared with whoever the owner shares it with, so the app only
/// ever changes reminders it wrote itself (marked in the notes); anything a
/// partner adds by hand is left alone. Only names and quantities leave the
/// app, never calories or health data (gap plan §4.7).
public enum GroceryExport {
    /// The one Reminders list, found by this title, created once and reused.
    public static let listTitle = "Shopping"
    /// The notes prefix that marks a reminder as the app's own: "healthcoach:<ingredient id>".
    public static let marker = "healthcoach:"

    /// "Chicken thighs · 1.2 kg".
    public static func title(_ item: ShoppingItem) -> String {
        item.quantityText.isEmpty ? item.name : "\(item.name) · \(item.quantityText)"
    }

    public static func notes(_ item: ShoppingItem) -> String { marker + item.id }

    /// The ingredient id a reminder was written for, or nil if a person wrote it.
    public static func itemID(notes: String?) -> String? {
        guard let notes, notes.hasPrefix(marker) else { return nil }
        let id = String(notes.dropFirst(marker.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? nil : id
    }

    /// A reminder already in the list.
    public struct Existing: Sendable, Equatable {
        public let id: String
        public let title: String
        public let notes: String?
        public let completed: Bool
        public init(id: String, title: String, notes: String?, completed: Bool) {
            self.id = id; self.title = title; self.notes = notes; self.completed = completed
        }
    }

    /// The changes one send makes.
    public struct Changes: Sendable, Equatable {
        /// New reminders: (title, notes).
        public var add: [Add] = []
        /// The app's own open reminders whose quantity changed: (reminder id, new title).
        public var retitle: [Retitle] = []
        /// The app's own open reminders for items no longer needed (ticked or gone from the week).
        public var remove: [String] = []

        public struct Add: Sendable, Equatable { public let title: String, notes: String }
        public struct Retitle: Sendable, Equatable { public let id: String, title: String }

        public var isEmpty: Bool { add.isEmpty && retitle.isEmpty && remove.isEmpty }
    }

    /// What to send: the week's items still to get. A ticked item is already
    /// in the cupboard, so it isn't sent.
    public static func toSend(_ items: [ShoppingItem], isTicked: (ShoppingItem) -> Bool) -> [ShoppingItem] {
        items.filter { !isTicked($0) }
    }

    /// Sending twice never duplicates: each item has at most one open reminder
    /// of the app's own. A completed reminder (bought) is history and stays;
    /// if the item is still wanted, a new open one is added. Reminders a
    /// person wrote are never touched. A second open copy of the same item
    /// (say, from two phones) is removed.
    public static func changes(send items: [ShoppingItem], existing: [Existing]) -> Changes {
        var changes = Changes()
        let wanted = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var covered = Set<String>()
        for reminder in existing where !reminder.completed {
            guard let id = itemID(notes: reminder.notes) else { continue }
            guard let item = wanted[id], !covered.contains(id) else {
                changes.remove.append(reminder.id)
                continue
            }
            covered.insert(id)
            let title = title(item)
            if reminder.title != title { changes.retitle.append(.init(id: reminder.id, title: title)) }
        }
        for item in items where !covered.contains(item.id) {
            covered.insert(item.id)
            changes.add.append(.init(title: title(item), notes: notes(item)))
        }
        return changes
    }

    /// In-store mode (N5): only what's left to get, in aisle order (the list's
    /// own order), so the next item is always the top row.
    public static func inStore(_ items: [ShoppingItem], isTicked: (ShoppingItem) -> Bool) -> [ShoppingItem] {
        items.filter { !isTicked($0) }
    }
}
