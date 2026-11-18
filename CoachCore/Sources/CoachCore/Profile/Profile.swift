import Foundation

/// The owner's one versioned profile record (plan §1, §5; requirements §12).
/// Everything specific to the owner lives here, not in code. The app stores
/// it in SwiftData as encoded JSON with its version alongside, so CoachCore
/// owns the format and its migrations and tests them on Linux.
///
/// Additive changes (a new optional field, or one with a default) keep the
/// version and decode old records unchanged. A rename or a change of meaning
/// bumps `currentSchemaVersion` and adds a step to `migrate`.
public struct Profile: VersionedFormat, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int = Profile.currentSchemaVersion
    /// False until the owner taps "Looks right" in onboarding (M1-04).
    public var confirmed: Bool = false

    public var about = About()
    public var goal = Goal()
    public var schedule = Schedule()
    public var training = Training()
    public var coach = Coach()
    public var programme = ProgrammeState()
    public var food = Food()
    /// N3: an edit saved in Preferences, waiting for tomorrow. nil when none.
    public var pending: Pending?

    public init() {}

    /// Board N3, Advisor A4(f).
    public struct Food: Codable, Sendable, Equatable {
        /// Foods the meal plan never uses, as the owner wrote them (`Dislikes`). Empty by default.
        public var dislikes: [String] = []
        public init() {}
    }

    public struct About: Codable, Sendable, Equatable {
        public var name: String?
        public var heightCm: Double?
        public var weightKg: Double?
        /// "Anything that hurts". Empty = nothing; exercises are swapped for
        /// their named `swap` where an entry applies (M1-04).
        public var painAreas: [String] = []
        public init() {}
    }

    public struct Goal: Codable, Sendable, Equatable {
        public var target: Target = .leanAndStrong
        public var phaseWeeks: Int = 6
        public init() {}

        public enum Target: String, Codable, Sendable, CaseIterable {
            case leanAndDefined = "lean-and-defined"
            case leanAndStrong = "lean-and-strong"
            case buildMuscle = "build-muscle"
            case generalFitness = "general-fitness"
        }
    }

    public struct Schedule: Codable, Sendable, Equatable {
        /// One sleep rule (M1-03 design): lights out = alarm − sleep − fall-asleep.
        public var sleepHours: Double = 7.5
        public var fallAsleepMinutes: Int = 15
        public var windDownMinutes: Int = 30
        public var latestBedtime = TimeOfDay(hour: 23, minute: 30)
        public var earliestWake = TimeOfDay(hour: 5, minute: 45)
        public var workStart = TimeOfDay(hour: 9, minute: 0)
        public var workEnd = TimeOfDay(hour: 18, minute: 0)
        public var trainingWindows: TrainingWindows = .both
        public var longSessionDay: Weekday = .sunday
        /// Door to desk (requirements §2: about 25 min).
        public var commuteMinutes: Int = 25
        /// After a session, at home.
        public var showerMinutes: Int = 15
        /// Alarm to session start: up, water, kit on.
        public var wakeBufferMinutes: Int = 15
        /// An evening session (and its shower) ends by this, to leave dinner and wind-down.
        public var eveningEndBy = TimeOfDay(hour: 20, minute: 30)
        /// Session start on days with no work (weekends).
        public var dayOffSessionStart = TimeOfDay(hour: 9, minute: 0)
        public init() {}

        public enum TrainingWindows: String, Codable, Sendable, CaseIterable {
            case morning, evening, both
        }
    }

    public struct Training: Codable, Sendable, Equatable {
        public var maxSessionMinutes: Int = 45
        public var dumbbellMaxKg: Double = 24
        public var hasBench = true
        public var hasPullUpBar = true
        public var voiceCues = true
        public var counting: Counting = .tap
        public init() {}

        public enum Counting: String, Codable, Sendable, CaseIterable {
            case tap, voice, both
        }
    }

    public struct Coach: Codable, Sendable, Equatable {
        public var checkInDay: Weekday = .sunday
        public var checkInTime = TimeOfDay(hour: 18, minute: 0)
        public var moodCheck = true
        public var quietFrom = TimeOfDay(hour: 22, minute: 30)
        public var quietUntil = TimeOfDay(hour: 6, minute: 0)
        public init() {}
    }

    /// Where the owner is in the plan.
    public struct ProgrammeState: Codable, Sendable, Equatable {
        public var programmeID = "phase-1"
        /// Monday of programme week 1, in the owner's calendar. nil until onboarding.
        public var startDate: Date?
        /// When onboarding was confirmed. The planner replays missed sessions
        /// (E13) only from this day: earlier days were trained on paper and
        /// count as done. nil (profiles from before this field) means no
        /// replay before today.
        public var confirmedOn: Date?
        public init() {}
    }
}

extension Profile {
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(self)
    }

    /// Decodes a stored record. Any field missing at any depth takes its
    /// default (the stored JSON is laid over a default profile first), so
    /// additive changes need no migration step. Migrations for breaking
    /// changes go in `migrate` before that.
    public static func decoded(from data: Data) throws -> Profile {
        let file = "Profile"
        // Version check first, with the usual plain messages.
        guard let header = try? JSONDecoder().decode(SchemaHeader.self, from: data) else {
            throw ContentError.unreadable(file: file, reason: "no schemaVersion")
        }
        if header.schemaVersion > currentSchemaVersion {
            throw ContentError.newerThanSupported(file: file, found: header.schemaVersion, supported: currentSchemaVersion)
        }
        if header.schemaVersion < oldestSchemaVersion {
            throw ContentError.olderThanSupported(file: file, found: header.schemaVersion, oldest: oldestSchemaVersion)
        }
        do {
            let stored = try migrate(JSONDecoder().decode(JSONValue.self, from: data), from: header.schemaVersion)
            let base = try JSONDecoder().decode(JSONValue.self, from: Profile().encoded())
            var merged = base.merging(stored)
            merged["schemaVersion"] = .number(Double(currentSchemaVersion))
            // A waiting edit's preferences take defaults for fields added since, like the profile.
            if case let .object(pending)? = merged["pending"], let stored = pending["preferences"] {
                let defaults = try JSONDecoder().decode(JSONValue.self,
                                                        from: JSONEncoder().encode(Profile().preferences))
                var updated = pending
                updated["preferences"] = defaults.merging(stored)
                merged["pending"] = .object(updated)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Profile.self, from: JSONEncoder().encode(merged))
        } catch {
            throw ContentError.unreadable(file: file, reason: describe(error))
        }
    }

    /// One step per breaking version change, oldest first. None yet.
    static func migrate(_ json: JSONValue, from version: Int) throws -> JSONValue {
        json
    }
}

// MARK: - N3 · Preferences, re-planned from tomorrow

extension Profile {
    /// Everything the owner can edit in Settings → Preferences: the
    /// onboarding modules. Not `confirmed` or `programme`, which only the app
    /// moves (onboarding, phase changes).
    public struct Preferences: Codable, Sendable, Equatable {
        public var about: About
        public var goal: Goal
        public var schedule: Schedule
        public var training: Training
        public var coach: Coach
        public var food: Food
    }

    /// A saved edit and the day it applies from (midnight, owner's calendar).
    public struct Pending: Codable, Sendable, Equatable {
        public var effectiveFrom: Date
        public var preferences: Preferences
    }

    /// Today's preferences.
    public var preferences: Preferences {
        get { Preferences(about: about, goal: goal, schedule: schedule, training: training, coach: coach, food: food) }
        set {
            about = newValue.about
            goal = newValue.goal
            schedule = newValue.schedule
            training = newValue.training
            coach = newValue.coach
            food = newValue.food
        }
    }

    /// What Preferences shows: a saved edit waiting for tomorrow, else today's.
    public var latestPreferences: Preferences { pending?.preferences ?? preferences }

    /// The profile in force on `date`: with a waiting edit applied once its
    /// day has come (and nothing left pending), else unchanged. Plans for a
    /// day ask for that day's profile, so today keeps its plan and alarms
    /// while tomorrow onwards follow the edit.
    public func effective(on date: Date, calendar: Calendar = .current) -> Profile {
        guard let pending, calendar.startOfDay(for: date) >= pending.effectiveFrom else { return self }
        var applied = self
        applied.preferences = pending.preferences
        applied.pending = nil
        return applied
    }

    /// The profile to store after the owner saves `edited` at `now`: today
    /// unchanged, the edit from tomorrow's midnight, never mid-day. A
    /// second edit the same day replaces the first; an edit back to today's
    /// values leaves nothing pending. Before onboarding is confirmed there is
    /// no plan yet, so the edit applies at once.
    public func scheduling(_ edited: Preferences, now: Date, calendar: Calendar = .current) -> Profile {
        var next = effective(on: now, calendar: calendar)
        guard next.confirmed else {
            next.preferences = edited
            next.pending = nil
            return next
        }
        let today = calendar.startOfDay(for: now)
        guard edited != next.preferences,
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            next.pending = nil
            return next
        }
        next.pending = Pending(effectiveFrom: tomorrow, preferences: edited)
        return next
    }

    /// The dislike list in force on `date` (`MealPlan.week`'s `dislikes`).
    public func dislikes(on date: Date, calendar: Calendar = .current) -> [String] {
        effective(on: date, calendar: calendar).food.dislikes
    }
}
