import CoachCore
import SwiftData
import SwiftUI

/// The week's meals as Meals shows them, so Today's lunch row (N9a) names the
/// same office order as the Lunch tab. C1: planned at the coach's target for
/// that week (M4-01, imports included); C3: training days take the extras
/// first; C6: the phase in force that week; N3: each day's dislikes, so an edit
/// applies from tomorrow; N4: only lunch orders within the owner's walk;
/// C4: a social meal replaces that day's dinner and the rest of the week trims.
enum WeekMeals {
    @MainActor
    static func plan(for date: Date, now: Date, content: ContentLibrary, profile: Profile,
                     context: ModelContext, calendar: Calendar = .coach) -> MealPlan {
        let monday = AlarmSchedule.mondayOf(date, calendar: calendar)
        let answers = WeekAnswersStore.shared.answers(weekStarting: monday, calendar: calendar)
        let orders = profile.food.lunchOrders(content.lunchOrders)
        let dislikes = { (day: Date) in profile.dislikes(on: day, calendar: calendar) }
        let base = content.programme(for: profile, on: date, calendar: calendar).map { programme in
            MealPlan.coached(monday: monday, now: now, content: content.nutrition,
                             lunchOrders: orders, answers: answers, programme: programme,
                             profile: profile, history: (try? SessionLogStore(context: context).all()) ?? [],
                             weights: BodyStats.shared.weightHistory, blocks: CoachBlockStore().all,
                             dislikes: dislikes, calendar: calendar)
        } ?? MealPlan.week(monday: monday, content: content.nutrition, lunchOrders: orders,
                           answers: answers, programmeID: profile.programme.programmeID,
                           dislikes: dislikes, calendar: calendar)
        return base.withSocialMeals(SocialMealStore.shared.dates(calendar: calendar), calendar: calendar)
    }
}
