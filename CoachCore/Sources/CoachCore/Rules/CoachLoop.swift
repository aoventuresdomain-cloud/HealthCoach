import Foundation

// Board C1: the coach loop end to end. The rules engine's weekly answer
// (CoachReview) feeds the meal plan, and what was eaten feeds back into the
// summary the owner shares with Claude. Kept apart from MealPlan so the meal
// planner's own changes (C3, C4) don't collide with it.

extension MealPlan {
    /// The week starting `monday`, planned at the coach's calorie target for
    /// that week. For the current week the target is the one in force `now`
    /// (an import applies from tomorrow); for any other week, the one in force
    /// on its Monday. Without a start date, the content's starting target.
    public static func coached(monday: Date, now: Date, content: NutritionContent, lunchOrders: [LunchOrder],
                               answers: WeekAnswers, programme: Programme, profile: Profile,
                               history: [SessionLog], weights: [WeightSample], blocks: [CoachBlock],
                               boxNights: Set<Weekday>? = nil, calendar: Calendar = .current) -> MealPlan {
        let start = calendar.startOfDay(for: monday)
        let next = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let at = (start..<next).contains(now) ? now : start
        let kcal = CoachReview.make(programme: programme, profile: profile, history: history, weights: weights,
                                    blocks: blocks, now: at, calendar: calendar)?.calories.kcal
        // C3: training days (sessions and basketball) take the extras first.
        let trainingDays = WeekPlanner.plan(weekStarting: start, programme: programme, profile: profile,
                                            answers: answers, calendar: calendar).trainingDays(programme: programme)
        return week(monday: start, content: content, lunchOrders: lunchOrders, answers: answers,
                    programmeID: programme.id, kcalTarget: kcal, trainingDays: trainingDays,
                    boxNights: boxNights, calendar: calendar)
    }
}

/// How closely the planned meals were followed, as averages only (privacy
/// rule: the summary never lists what was eaten on which day).
public struct MealAdherence: Sendable, Equatable {
    public let days: Int
    public let planned: Int
    /// Planned meals left ticked (eaten as planned).
    public let eaten: Int
    /// From the ticked meals, a day.
    public let averageKcal: Int
    public let averageProteinG: Int
    /// Social meals logged in the window (board C4); nil until that counter exists.
    public let socialMeals: Int?
    /// Social meals allowed a week (board C4).
    public static let socialMealsPerWeek = 2

    public init(days: Int, planned: Int, eaten: Int, averageKcal: Int, averageProteinG: Int, socialMeals: Int? = nil) {
        self.days = days
        self.planned = planned
        self.eaten = eaten
        self.averageKcal = averageKcal
        self.averageProteinG = averageProteinG
        self.socialMeals = socialMeals
    }

    /// From planned days and which meals are still ticked. Nil with no days.
    public static func make(days: [MealDay], isTicked: (MealDay, PlannedMeal) -> Bool,
                            socialMeals: Int? = nil) -> MealAdherence? {
        guard !days.isEmpty else { return nil }
        var planned = 0, eaten = 0, kcal = 0, protein = 0
        for day in days {
            for meal in day.meals {
                planned += 1
                guard isTicked(day, meal) else { continue }
                eaten += 1
                kcal += meal.kcal
                protein += meal.protein
            }
        }
        let n = Double(days.count)
        return MealAdherence(days: days.count, planned: planned, eaten: eaten,
                             averageKcal: Int((Double(kcal) / n).rounded()),
                             averageProteinG: Int((Double(protein) / n).rounded()),
                             socialMeals: socialMeals)
    }

    /// The 7 days before today (today isn't over), taken from `plan`, which
    /// gives the week starting a Monday (`MealPlan.coached` in the app).
    public static func lastSevenDays(now: Date, plan: (Date) -> MealPlan,
                                     isTicked: (MealDay, PlannedMeal) -> Bool, socialMeals: Int? = nil,
                                     calendar: Calendar = .current) -> MealAdherence? {
        let today = calendar.startOfDay(for: now)
        var weeks: [Date: MealPlan] = [:]
        var days: [MealDay] = []
        for back in (1...7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
            let monday = AlarmSchedule.mondayOf(date, calendar: calendar)
            let week = weeks[monday] ?? plan(monday)
            weeks[monday] = week
            if let day = week.day(date, calendar: calendar) { days.append(day) }
        }
        return make(days: days, isTicked: isTicked, socialMeals: socialMeals)
    }

    /// The summary lines.
    var lines: [String] {
        var out = ["- Meals (last \(days) days): \(eaten) of \(planned) planned meals eaten as planned; about \(CoachText.thousands(averageKcal)) kcal and \(averageProteinG) g protein a day from those"]
        if let social = socialMeals {
            out.append("- Social meals: \(social) (allowance \(Self.socialMealsPerWeek) a week)")
        }
        return out
    }
}

/// Recovery after sessions, as counts only.
public struct RecoverySummary: Sendable, Equatable {
    public let fine: Int
    public let sore: Int

    /// Recovery answers on sessions started in the 14 days before `now`.
    public static func make(history: [SessionLog], now: Date, calendar: Calendar = .current) -> RecoverySummary? {
        let window = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: now)) ?? now
        let answers = history.filter { $0.startedAt >= window && $0.startedAt <= now }.compactMap(\.recovery)
        guard !answers.isEmpty else { return nil }
        return RecoverySummary(fine: answers.filter { $0 == .fine }.count, sore: answers.filter { $0 == .sore }.count)
    }

    var line: String { "- Recovery (last 14 days): \(fine) Fine, \(sore) Sore" }
}
