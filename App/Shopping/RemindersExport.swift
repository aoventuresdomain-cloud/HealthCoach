import CoachCore
import EventKit
import Foundation
import Observation

/// Board N5: "Send to Reminders". Writes the week's top-up list into one
/// Reminders list called Shopping: found by name, created only if there's
/// none, so a list the owner already shares with a partner is reused. The
/// rules (no duplicates, a person's own reminders untouched) are
/// `GroceryExport` in CoachCore; this file only talks to EventKit.
@MainActor @Observable
final class RemindersExport {
    static let shared = RemindersExport()

    enum Failure: Error, Equatable {
        case denied
        case noSource
        case failed(String)
    }

    /// What the list holds after a send, read back from Reminders, so the
    /// header (and the UI test) show what's really there.
    struct Result: Equatable {
        /// Reminders lists called Shopping: 1 unless one was made elsewhere too.
        let lists: Int
        /// The app's own open reminders in the list.
        let items: Int
    }

    /// The day of the last send ("2026-11-23"), and what it found in Reminders.
    private(set) var sentDay: String?
    private(set) var lastResult: Result?

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let sentKey = "shopping.sentDay.v1"

    private init() {
        if LaunchOptions.current.isUITest, let suite = UserDefaults(suiteName: "uitest.grocery") {
            suite.removePersistentDomain(forName: "uitest.grocery")
            defaults = suite
        } else {
            defaults = .standard
        }
        sentDay = defaults.string(forKey: sentKey)
    }

    /// Design N5: the header says "Sent to Reminders" for the rest of the day.
    func sentToday(now: Date, calendar: Calendar) -> Bool {
        sentDay == MealTicks.dayKey(now, calendar: calendar)
    }

    /// The first send shows the one system permission alert; after that, none.
    func send(_ items: [ShoppingItem], now: Date, calendar: Calendar) async throws -> Result {
        guard try await store.requestFullAccessToReminders() else { throw Failure.denied }
        let list = try shoppingList()
        let existing = await reminders(in: list)
        let changes = GroceryExport.changes(send: items, existing: existing.map {
            GroceryExport.Existing(id: $0.calendarItemIdentifier, title: $0.title ?? "",
                                   notes: $0.notes, completed: $0.isCompleted)
        })
        let byID = Dictionary(existing.map { ($0.calendarItemIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
        do {
            for change in changes.retitle {
                guard let reminder = byID[change.id] else { continue }
                reminder.title = change.title
                try store.save(reminder, commit: false)
            }
            for id in changes.remove { if let r = byID[id] { try store.remove(r, commit: false) } }
            for add in changes.add {
                let reminder = EKReminder(eventStore: store)
                reminder.calendar = list
                reminder.title = add.title
                reminder.notes = add.notes
                try store.save(reminder, commit: false)
            }
            try store.commit()
        } catch {
            store.reset()
            throw Failure.failed(error.localizedDescription)
        }
        let day = MealTicks.dayKey(now, calendar: calendar)
        defaults.set(day, forKey: sentKey)
        let result = try await readBack()
        sentDay = day
        lastResult = result
        return result
    }

    /// Counts what's in Reminders now.
    func readBack() async throws -> Result {
        let lists = store.calendars(for: .reminder).filter { $0.title == GroceryExport.listTitle }
        guard let list = lists.first else { return Result(lists: 0, items: 0) }
        let mine = await reminders(in: list).filter {
            !$0.isCompleted && GroceryExport.itemID(notes: $0.notes) != nil
        }
        return Result(lists: lists.count, items: mine.count)
    }

    private func shoppingList() throws -> EKCalendar {
        if let found = store.calendars(for: .reminder).first(where: { $0.title == GroceryExport.listTitle }) {
            return found
        }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = GroceryExport.listTitle
        guard let source = store.defaultCalendarForNewReminders()?.source
                ?? store.sources.first(where: { $0.sourceType == .local }) else { throw Failure.noSource }
        list.source = source
        do { try store.saveCalendar(list, commit: true) } catch { throw Failure.failed(error.localizedDescription) }
        return list
    }

    private func reminders(in list: EKCalendar) async -> [EKReminder] {
        let ids = await Self.fetchIDs(store, store.predicateForReminders(in: [list]))
        return ids.compactMap { store.calendarItem(withIdentifier: $0) as? EKReminder }
    }

    /// EventKit calls back on its own queue. Nonisolated, so the callback isn't
    /// taken as main-actor code; only the identifiers (Sendable) come back,
    /// and the reminders are looked up again on the main actor.
    nonisolated private static func fetchIDs(_ store: EKEventStore, _ predicate: NSPredicate) async -> [String] {
        await withCheckedContinuation { continuation in
            _ = store.fetchReminders(matching: predicate) { found in
                continuation.resume(returning: (found ?? []).map(\.calendarItemIdentifier))
            }
        }
    }
}
