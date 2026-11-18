import Foundation

/// The wake alarms for the next `horizonDays` days, from the week planner
/// (board M2-02, plan §4.1). The app reconciles these against AlarmKit on
/// every open and after the Sunday prompt; there is no background job, so as
/// long as the app opens once a week, 7–14 days of alarms are always set.
public enum AlarmSchedule {
    public static let horizonDays = 14

    /// Wake alarms from today through `horizonDays − 1` days ahead that are
    /// still in the future. `answers(monday)` gives the Sunday prompt answers
    /// for the week starting that Monday; weeks not yet answered should get
    /// the latest answers (the app's job). Empty when there's no start date.
    ///
    /// `programmeOn(date)` gives the phase in force on each planned day
    /// (C6: `ContentLibrary.programme(for:on:)`), so the Sunday before a new
    /// phase sets Monday's alarm from the new phase. Without it, or when it
    /// gives nil, every day uses `programme`.
    public static func make(now: Date, programme: Programme, profile: Profile,
                            answers: (Date) -> WeekAnswers, dropping: Set<String> = [],
                            completed: Set<String> = [],
                            programmeOn: ((Date) -> Programme?)? = nil,
                            calendar: Calendar = .current) -> [PlannedAlarm] {
        guard profile.programme.startDate != nil else { return [] }
        let today = calendar.startOfDay(for: now)
        // N3: each day from that day's profile, so a Preferences edit moves
        // alarms from tomorrow and today's stays as it was.
        struct Key: Hashable { let monday: Date; let edited: Bool; let programme: String }
        var plans: [Key: WeekPlan] = [:]
        var alarms: [PlannedAlarm] = []
        for offset in 0..<horizonDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let monday = mondayOf(date, calendar: calendar)
            let dayProfile = profile.effective(on: date, calendar: calendar)
            let dayProgramme = programmeOn?(date) ?? programme
            let key = Key(monday: monday, edited: dayProfile.pending == nil && profile.pending != nil,
                          programme: dayProgramme.id)
            if plans[key] == nil {
                plans[key] = WeekPlanner.plan(weekStarting: monday, programme: dayProgramme, profile: dayProfile,
                                              answers: answers(monday), dropping: dropping,
                                              now: now, completed: completed, calendar: calendar)
            }
            guard let day = plans[key]?.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) }),
                  let alarm = alarm(for: day, programme: dayProgramme, calendar: calendar),
                  alarm.fireDate > now else { continue }
            alarms.append(alarm)
        }
        return alarms
    }

    /// "Tomorrow changed" (plan §4.1): `current` with only `date`'s alarm
    /// replaced from `changedWeek`, the week re-planned with the new answers.
    /// Every other day keeps its alarm exactly, so the reconcile touches one.
    public static func replacingDay(_ date: Date, in current: [PlannedAlarm], from changedWeek: WeekPlan,
                                    programme: Programme, calendar: Calendar = .current) -> [PlannedAlarm] {
        var kept = current.filter { !calendar.isDate($0.fireDate, inSameDayAs: date) }
        if let day = changedWeek.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) }),
           let alarm = alarm(for: day, programme: programme, calendar: calendar) {
            kept.append(alarm)
        }
        return kept.sorted { $0.fireDate < $1.fireDate }
    }

    /// The day's wake alarm, or nil when it has none (a day off with nothing on).
    /// The id comes from the date and time, so an unchanged alarm keeps its id
    /// across opens and a moved one gets a new one (the reconcile swaps it).
    public static func alarm(for day: WeekPlan.Day, programme: Programme, calendar: Calendar = .current) -> PlannedAlarm? {
        guard let wake = day.wake,
              let fire = calendar.date(bySettingHour: wake.hour, minute: wake.minute, second: 0, of: day.date) else { return nil }
        let title: String
        if let session = day.session, let name = programme.sessions[session.sessionID]?.name {
            title = "\(name) at \(session.start)"
        } else if let fixed = day.fixed {
            title = "Wake up · \(fixed.name) tonight"
        } else {
            title = "Wake up"
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: day.date)
        func pad(_ n: Int?) -> String { n.map { $0 < 10 ? "0\($0)" : "\($0)" } ?? "00" }
        let key = "wake|\(parts.year ?? 0)-\(pad(parts.month))-\(pad(parts.day))|\(wake)"
        return PlannedAlarm(id: UUID(stableFrom: key), fireDate: fire, title: title)
    }

    /// The Monday on or before `date`.
    public static func mondayOf(_ date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        let index = Weekday.allCases.firstIndex(of: Weekday(calendarWeekday: calendar.component(.weekday, from: day)))!
        return calendar.date(byAdding: .day, value: -index, to: day) ?? day
    }
}

/// What Today says about the alarms after a reconcile (QA-1): zero upcoming
/// alarms is always a warning, never "all set".
public enum AlarmCoverage: Equatable, Sendable {
    case allSet(count: Int, next: Date)
    /// Some were missing and have been set again; nothing for the owner to do.
    case reSet(missing: Int, total: Int, next: Date)
    /// Nothing upcoming is set: Today shows a warning.
    case noAlarms

    public init(_ outcome: ReconcileOutcome) {
        guard outcome.total > 0, let next = outcome.next else {
            self = .noAlarms
            return
        }
        self = outcome.reSet > 0 ? .reSet(missing: outcome.reSet, total: outcome.total, next: next)
                                 : .allSet(count: outcome.total, next: next)
    }

    public var needsWarning: Bool { self == .noAlarms }
}

extension UUID {
    /// A UUID that is always the same for the same text (two FNV-1a 64-bit
    /// hashes, version 8 layout). Not for security: only to keep alarm ids stable.
    public init(stableFrom text: String) {
        func fnv(_ seed: UInt64) -> UInt64 {
            var hash: UInt64 = seed
            for byte in text.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01B3
            }
            return hash
        }
        let high = fnv(0xcbf2_9ce4_8422_2325)
        let low = fnv(0x84222325_cbf29ce4)
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8(truncatingIfNeeded: high >> (56 - 8 * UInt64(i)))
            bytes[8 + i] = UInt8(truncatingIfNeeded: low >> (56 - 8 * UInt64(i)))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x80 // version 8
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        self.init(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                         bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
