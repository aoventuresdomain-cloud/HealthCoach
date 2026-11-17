import Foundation

/// Quiet hours, 22:30–06:00 (plan §4.7). No coach notification fires inside them.
public enum QuietHours {
    public static let start = TimeOfDay(hour: 22, minute: 30)
    public static let end = TimeOfDay(hour: 6, minute: 0)

    /// True from 22:30 up to, but not including, 06:00.
    public static func contains(_ time: TimeOfDay) -> Bool {
        time >= start || time < end
    }

    public static func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        contains(TimeOfDay(date, calendar: calendar))
    }

    /// 06:00 at the end of the quiet spell that holds `date`; `date` itself
    /// when it is outside quiet hours.
    public static func nextAllowed(after date: Date, calendar: Calendar = .current) -> Date {
        guard contains(date, calendar: calendar) else { return date }
        let morning = TimeOfDay(date, calendar: calendar) >= start
            ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
            : calendar.startOfDay(for: date)
        return end.on(morning, calendar: calendar)
    }

    /// 22:25 on the evening the quiet spell that holds `date` began; `date`
    /// itself when it is outside quiet hours.
    public static func lastAllowed(before date: Date, calendar: Calendar = .current) -> Date {
        guard contains(date, calendar: calendar) else { return date }
        let evening = TimeOfDay(date, calendar: calendar) >= start
            ? calendar.startOfDay(for: date)
            : calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))!
        return start.adding(minutes: -5).on(evening, calendar: calendar)
    }
}

/// One local notification the app should have pending (plan §4.7).
public struct CoachNotification: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case morningBrief, leaveNow, windDown, sundayPrompt
    }

    /// Stable per kind and day, so a re-plan replaces rather than duplicates.
    public let id: String
    public let kind: Kind
    public let fireDate: Date
    public let title: String
    public let body: String
}

/// Builds the pending notifications from the planned days (board M2-05).
/// Pure: the clock comes in as `now`, so quiet hours are unit-tested.
///
/// One that lands in quiet hours is never scheduled there: the morning brief
/// and the Sunday prompt wait until 06:00, wind-down comes early (22:25), and
/// "leave now" is dropped, because it is only right at its own time.
public enum NotificationPlanner {
    /// iOS keeps at most 64 pending local notifications per app.
    public static let pendingLimit = 64
    /// Wind-down goes out this long before lights out.
    public static let windDownMinutes = 30
    /// The Sunday prompt asks about the coming week at this time on Sunday.
    public static let sundayPromptTime = TimeOfDay(hour: 18, minute: 0)

    /// The notifications for the same 14 days the wake alarms cover
    /// (`AlarmSchedule.horizonDays`), planned the way the alarms are.
    public static func plan(now: Date, programme: Programme, profile: Profile,
                            answers: (Date) -> WeekAnswers, dropping: Set<String> = [],
                            calendar: Calendar = .current) -> [CoachNotification] {
        guard profile.programme.startDate != nil else { return [] }
        let today = calendar.startOfDay(for: now)
        let last = calendar.date(byAdding: .day, value: AlarmSchedule.horizonDays - 1, to: today)!
        var days: [WeekPlan.Day] = []
        var monday = AlarmSchedule.mondayOf(today, calendar: calendar)
        while monday <= last {
            let week = WeekPlanner.plan(weekStarting: monday, programme: programme, profile: profile,
                                        answers: answers(monday), dropping: dropping, calendar: calendar)
            days += week.days.filter { $0.date >= today && $0.date <= last }
            monday = calendar.date(byAdding: .day, value: 7, to: monday)!
        }
        return plan(days: days, sessionName: { programme.sessions[$0]?.name ?? "Session" },
                    now: now, calendar: calendar)
    }

    public static func plan(days: [WeekPlan.Day], sessionName: (String) -> String,
                            now: Date, calendar: Calendar = .current) -> [CoachNotification] {
        var out: [CoachNotification] = []

        func add(_ kind: CoachNotification.Kind, at planned: Date, dayKey: Date,
                 title: String, body: String) {
            var fire = planned
            if QuietHours.contains(fire, calendar: calendar) {
                switch kind {
                case .morningBrief, .sundayPrompt: fire = QuietHours.nextAllowed(after: fire, calendar: calendar)
                case .windDown: fire = QuietHours.lastAllowed(before: fire, calendar: calendar)
                case .leaveNow: return
                }
            }
            guard fire > now else { return }
            out.append(CoachNotification(id: "\(kind.rawValue)-\(key(dayKey, calendar: calendar))",
                                         kind: kind, fireDate: fire, title: title, body: body))
        }

        for day in days {
            let date = calendar.startOfDay(for: day.date)
            if let wake = day.wake {
                add(.morningBrief, at: wake.on(date, calendar: calendar), dayKey: date,
                    title: "Today", body: brief(day, sessionName: sessionName))
            }
            if let leave = day.leave {
                add(.leaveNow, at: leave.on(date, calendar: calendar), dayKey: date,
                    title: "Leave now", body: "Time to head to the office.")
            }
            if let lightsOut = day.lightsOutBefore {
                // Lights out is the night before this day: the evening before,
                // or this day's small hours when it is after midnight.
                let windDown = lightsOut.adding(minutes: -windDownMinutes)
                let evening = calendar.date(byAdding: .day, value: -1, to: date)!
                let on = windDown.hour < 12 ? date : evening
                add(.windDown, at: windDown.on(on, calendar: calendar), dayKey: date,
                    title: "Wind down", body: "Lights out at \(lightsOut). Screens off soon.")
            }
            if day.weekday == .sunday {
                add(.sundayPrompt, at: sundayPromptTime.on(date, calendar: calendar), dayKey: date,
                    title: "Plan next week", body: "Which days are you in the office? It takes 20 seconds.")
            }
        }
        // Soonest first, and only as many as iOS will keep.
        return Array(out.sorted { $0.fireDate < $1.fireDate }.prefix(pendingLimit))
    }

    /// "Upper A at 07:40, leave at 08:35." The first line of the morning brief.
    static func brief(_ day: WeekPlan.Day, sessionName: (String) -> String) -> String {
        var parts: [String] = []
        if let session = day.session {
            parts.append("\(sessionName(session.sessionID)) at \(session.start)")
        } else if let fixed = day.fixed {
            parts.append("\(fixed.name) at \(fixed.time)")
        } else {
            parts.append("Rest day")
        }
        if let leave = day.leave { parts.append("leave at \(leave)") }
        return parts.joined(separator: ", ") + "."
    }

    private static func key(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

extension TimeOfDay {
    /// The clock time of `date` in `calendar`'s time zone.
    init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    /// This clock time on the day that starts at `day`, right across a clock change.
    func on(_ day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
