import Foundation
import Testing
@testable import CoachCore

/// Board M2-04: the 7-day weight average and steps, from read-only Health data.
@Suite struct BodyTrendTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    private func at(_ m: Int, _ d: Int, _ h: Int = 7) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
    }

    // MARK: Weight

    @Test func sevenDayAverageOfDailyWeighIns() throws {
        // 24–30 Nov, one morning weigh-in each.
        let kgs = [83.0, 82.8, 83.2, 82.6, 82.4, 82.9, 82.5]
        let samples = kgs.enumerated().map { WeightSample(date: at(11, 24 + $0.offset), kg: $0.element) }
        let trend = try #require(WeightTrend.make(samples: samples, endingOn: at(11, 30, 21), calendar: calendar))
        #expect(abs(trend.averageKg - 82.771) < 0.001)
        #expect(trend.daysWeighed == 7)
        #expect(trend.previousAverageKg == nil)
        #expect(trend.summary == "82.8 kg (7-day average)")
    }

    @Test func comparesWithTheWeekBefore() throws {
        let lastWeek = (17...23).map { WeightSample(date: at(11, $0), kg: 84.0) }
        let thisWeek = (24...30).map { WeightSample(date: at(11, $0), kg: 83.4) }
        let trend = try #require(WeightTrend.make(samples: lastWeek + thisWeek, endingOn: at(11, 30), calendar: calendar))
        #expect(trend.previousAverageKg == 84.0)
        #expect(abs(try #require(trend.changeKg) + 0.6) < 0.0001)
        #expect(trend.summary == "83.4 kg (7-day average), down 0.6 kg on last week")
    }

    @Test func severalWeighInsInADayCountOnce() throws {
        // Two readings on 28 Nov average to 83; the day isn't double-counted.
        let samples = [
            WeightSample(date: at(11, 26), kg: 82.0),
            WeightSample(date: at(11, 27), kg: 82.0),
            WeightSample(date: at(11, 28, 7), kg: 82.0),
            WeightSample(date: at(11, 28, 20), kg: 84.0),
        ]
        let trend = try #require(WeightTrend.make(samples: samples, endingOn: at(11, 28), calendar: calendar))
        #expect(trend.daysWeighed == 3)
        #expect(abs(trend.averageKg - (82 + 82 + 83) / 3) < 0.0001)
    }

    @Test func tooFewWeighInsGiveNoTrend() {
        let two = [WeightSample(date: at(11, 29), kg: 82), WeightSample(date: at(11, 30), kg: 82)]
        #expect(WeightTrend.make(samples: two, endingOn: at(11, 30), calendar: calendar) == nil)
        #expect(WeightTrend.make(samples: [], endingOn: at(11, 30), calendar: calendar) == nil)
    }

    @Test func readingsOutsideTheWindowOrImplausibleAreIgnored() throws {
        let samples = [
            WeightSample(date: at(11, 23), kg: 90),   // 8 days back: previous window
            WeightSample(date: at(11, 24), kg: 82),
            WeightSample(date: at(11, 25), kg: 18),   // a child on the scale
            WeightSample(date: at(11, 26), kg: 82),
            WeightSample(date: at(11, 27), kg: 82),
            WeightSample(date: at(12, 1), kg: 70),    // after the day asked about
        ]
        let trend = try #require(WeightTrend.make(samples: samples, endingOn: at(11, 30), calendar: calendar))
        #expect(trend.averageKg == 82)
        #expect(trend.daysWeighed == 3)
        #expect(trend.previousAverageKg == nil) // one reading isn't a week
    }

    @Test func levelWeekSaysSo() throws {
        let samples = (17...30).map { WeightSample(date: at(11, $0), kg: 82.0) }
        let trend = try #require(WeightTrend.make(samples: samples, endingOn: at(11, 30), calendar: calendar))
        #expect(trend.summary == "82.0 kg (7-day average), level with last week")
    }

    // MARK: Steps

    @Test func stepsTodayAndTheWeekBefore() {
        let days = (23...29).map { StepCount(day: at(11, $0, 0), steps: 7000 + ($0 - 23) * 500) }
            + [StepCount(day: at(11, 30, 0), steps: 4321)]
        let summary = StepsSummary.make(days: days, today: at(11, 30, 18), calendar: calendar)
        #expect(summary.today == 4321)
        #expect(summary.sevenDayAverage == 8500) // 7000…10000 in 500s
    }

    @Test func noStepsYetIsZeroNotMissing() {
        let summary = StepsSummary.make(days: [], today: at(11, 30), calendar: calendar)
        #expect(summary.today == 0)
        #expect(summary.sevenDayAverage == nil)
    }

    @Test func emptyDaysDoNotDragTheAverageDown() {
        // The phone was off on 27 Nov: that day isn't counted as zero.
        let days = [StepCount(day: at(11, 26, 0), steps: 8000), StepCount(day: at(11, 27, 0), steps: 0),
                    StepCount(day: at(11, 28, 0), steps: 10000)]
        #expect(StepsSummary.make(days: days, today: at(11, 30), calendar: calendar).sevenDayAverage == 9000)
    }
}
