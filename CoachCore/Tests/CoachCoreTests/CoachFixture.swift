import Foundation
import Testing
@testable import CoachCore

/// Shared set-up for the M4 rules engine and import tests. Week 1 starts on
/// Monday 16 Nov 2026 (the paper start, decision E13), in Europe/London.
struct CoachFixture {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }()

    var start: Date { day(0) }

    /// Midnight at the start of day `n` (day 0 = Monday of week 1).
    func day(_ n: Int, hour: Int = 0) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16))!
        let d = calendar.date(byAdding: .day, value: n, to: base)!
        return calendar.date(byAdding: .hour, value: hour, to: d)!
    }

    /// Monday of overall week `w`.
    func monday(_ w: Int, hour: Int = 9) -> Date { day((w - 1) * 7, hour: hour) }

    func phase1() throws -> Programme {
        try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
    }

    func profile() -> Profile {
        var p = Profile()
        p.confirmed = true
        p.about.heightCm = 178
        p.about.weightKg = 82
        p.programme.startDate = start
        return p
    }

    /// One 07:00 weigh-in a day from day `from` to day `to` (inclusive).
    func weights(from: Int = -21, to: Int, _ kg: (Int) -> Double) -> [WeightSample] {
        (from...to).map { WeightSample(date: day($0, hour: 7), kg: kg($0)) }
    }

    /// Losing `perWeek` kg a week from 82 kg at day 0.
    func losing(_ perWeek: Double, to: Int) -> [WeightSample] {
        weights(to: to) { 82 - perWeek * Double($0) / 7 }
    }

    /// A block as the importer would stamp it, imported on day `n` at 20:00.
    func block(on n: Int, kcal: Int? = nil, protein: Int? = nil, drop: [String] = [],
               weeks: Int = 1, loads: [CoachBlock.Load] = []) -> CoachBlock {
        CoachBlock(dailyKcal: kcal, proteinG: protein, dropSessions: drop, dropForWeeks: weeks,
                   loads: loads, importedAt: day(n, hour: 20), effectiveFrom: day(n + 1))
    }
}
