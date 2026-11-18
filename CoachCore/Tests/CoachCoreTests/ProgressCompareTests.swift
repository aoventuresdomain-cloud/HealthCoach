import Foundation
import Testing
@testable import CoachCore

/// Board N7: the waist row, the photo pairing and the one line under the photos.
@Suite struct ProgressCompareTests {
    let f = CoachFixture()

    // MARK: - Waist

    @Test func waistStepsOnHalfCentimetresInsideTheRange() {
        #expect(WaistLog.rounded(88.3) == 88.5)
        #expect(WaistLog.rounded(88.2) == 88)
        #expect(WaistLog.rounded(20) == 50)
        #expect(WaistLog.rounded(300) == 160)
        var log = WaistLog()
        #expect(log.prefillCm == 90)
        #expect(log.text == nil)
        log.add(cm: .nan, on: f.day(0))
        #expect(log.entries.isEmpty)
    }

    @Test func waistKeepsOneValueADayAndPrefillsTheLast() {
        var log = WaistLog()
        log.add(cm: 90, on: f.day(0, hour: 7), calendar: f.calendar)
        #expect(log.text == "waist 90 cm")
        log.add(cm: 89.7, on: f.day(14, hour: 7), calendar: f.calendar)
        log.add(cm: 88.4, on: f.day(14, hour: 20), calendar: f.calendar)   // same day: replaces
        #expect(log.entries.count == 2)
        #expect(log.prefillCm == 88.5)
        #expect(log.changeCm == -1.5)
        #expect(log.text == "waist 88.5 cm (\u{2212}1.5)")
        log.add(cm: 90.5, on: f.day(28), calendar: f.calendar)
        #expect(log.text == "waist 90.5 cm (+0.5)")
        log.add(cm: 90, on: f.day(28), calendar: f.calendar)
        #expect(log.text == "waist 90 cm (level)")
        // An entry added out of order still lands in date order.
        log.add(cm: 91, on: f.day(-7), calendar: f.calendar)
        #expect(log.entries.first?.cm == 91)
    }

    @Test func waistRoundTripsAsJSON() throws {
        var log = WaistLog()
        log.add(cm: 90, on: f.day(0), calendar: f.calendar)
        log.add(cm: 88.5, on: f.day(14), calendar: f.calendar)
        let back = try JSONDecoder().decode(WaistLog.self, from: try JSONEncoder().encode(log))
        #expect(back == log)
    }

    @Test func waistReachesClaudeOnlyAtACheckpoint() throws {
        let p = try f.phase1()
        var log = WaistLog()
        log.add(cm: 90, on: f.day(0), calendar: f.calendar)
        log.add(cm: 88.5, on: f.day(28), calendar: f.calendar)
        func summary(_ reason: CoachSummary.Reason?) throws -> String {
            try #require(CoachSummary.text(reason: reason, programme: p, profile: f.profile(), history: [],
                                           weights: f.losing(0.5, to: 41), waist: log, blocks: [],
                                           now: f.day(41, hour: 18), calendar: f.calendar))
        }
        let checkpoint = try summary(.flag(.checkpoint(1)))
        #expect(checkpoint.contains("- Waist (navel, photo day): 88.5 cm, \u{2212}1.5 cm since Mon 16 Nov 2026"))
        // Never the individual values: only the latest and the change. No photos either.
        #expect(!checkpoint.contains("90 cm"))
        #expect(checkpoint.components(separatedBy: "88.5").count == 2)
        #expect(!checkpoint.contains(".jpg"))   // the summary takes no photo input at all
        #expect(!(try summary(.askNow)).contains("Waist"))
        // One value only: no line at all, and no "not measured" line.
        var single = WaistLog()
        single.add(cm: 90, on: f.day(0), calendar: f.calendar)
        let one = try #require(CoachSummary.text(reason: .flag(.checkpoint(1)), programme: p, profile: f.profile(),
                                                 history: [], weights: f.losing(0.5, to: 41), waist: single, blocks: [],
                                                 now: f.day(41, hour: 18), calendar: f.calendar))
        #expect(!one.lowercased().contains("waist"))
        // Waist off: nothing, even at a checkpoint.
        let off = try #require(CoachSummary.text(reason: .flag(.checkpoint(1)), programme: p, profile: f.profile(),
                                                 history: [], weights: f.losing(0.5, to: 41), blocks: [],
                                                 now: f.day(41, hour: 18), calendar: f.calendar))
        #expect(!off.lowercased().contains("waist"))
    }

    // MARK: - Photo pairing

    @Test func pairingPicksWeekZeroAndFourWeeksAgo() {
        // Photo days 0, 14, 28, 42, 56, out of order.
        let dates = [56, 0, 28, 14, 42].map { f.day($0, hour: 7) }
        #expect(PhotoPairing.today(dates) == 0)
        #expect(PhotoPairing.ghost(dates) == 1)
        #expect(PhotoPairing.baseline(dates, against: .weekZero, calendar: f.calendar) == 1)
        #expect(PhotoPairing.baseline(dates, against: .fourWeeksAgo, calendar: f.calendar) == 2)   // day 28
        #expect(PhotoPairing.available(dates, calendar: f.calendar) == [.weekZero, .fourWeeksAgo])
        #expect(PhotoPairing.Against.allCases.map(\.rawValue) == ["Week 0", "4 weeks ago"])
    }

    @Test func fourWeeksAgoTakesTheNearestAtLeastTwoWeeksBack() {
        // A missed block: photos on days 0, 20 and 41. 28 before 41 is day 13;
        // day 20 is 21 back (7 off), day 0 is 41 back (13 off).
        let missed = [0, 20, 41].map { f.day($0) }
        #expect(PhotoPairing.baseline(missed, against: .fourWeeksAgo, calendar: f.calendar) == 1)
        // An exact 28 days wins over the first photo.
        let exact = [0, 56, 84].map { f.day($0) }
        #expect(PhotoPairing.baseline(exact, against: .fourWeeksAgo, calendar: f.calendar) == 1)
        // A tie goes to the earlier photo: 42 and 14 days back are both 14 off.
        let both = [0, 28, 42].map { f.day($0) }
        #expect(PhotoPairing.baseline(both, against: .fourWeeksAgo, calendar: f.calendar) == 0)
        // Only a photo from a week ago: too close.
        let close = [7, 14].map { f.day($0) }
        #expect(PhotoPairing.baseline(close, against: .fourWeeksAgo, calendar: f.calendar) == nil)
        #expect(PhotoPairing.available(close, calendar: f.calendar) == [.weekZero])
    }

    @Test func noPairBeforeASecondPhoto() {
        #expect(PhotoPairing.today([]) == nil)
        #expect(PhotoPairing.ghost([]) == nil)
        let one = [f.day(0)]
        #expect(PhotoPairing.ghost(one) == 0)   // the first photo is its own ghost for the next one
        #expect(PhotoPairing.baseline(one, against: .weekZero, calendar: f.calendar) == nil)
        #expect(PhotoPairing.available(one, calendar: f.calendar).isEmpty)
        // A retake the same day isn't a past photo.
        let sameDay = [f.day(14, hour: 7), f.day(14, hour: 8)]
        #expect(PhotoPairing.baseline(sameDay, against: .weekZero, calendar: f.calendar) == nil)
    }

    // MARK: - The one line

    @Test func theLineJoinsWeightAndWaist() throws {
        let trend = try #require(WeightTrend.make(samples: f.losing(0.5, to: 28), endingOn: f.day(28), calendar: f.calendar))
        let weight = "\(WeightTrend.oneDecimal(trend.averageKg)) kg · 7-day average · \u{2212}1.1 kg since start"
        #expect(ProgressLine.text(trend: trend, changeSinceStart: -1.1) == weight)
        var log = WaistLog()
        log.add(cm: 90, on: f.day(0), calendar: f.calendar)
        log.add(cm: 88.5, on: f.day(28), calendar: f.calendar)
        #expect(ProgressLine.text(trend: trend, changeSinceStart: -1.1, waist: log)
                == weight + " · waist 88.5 cm (\u{2212}1.5)")
        #expect(ProgressLine.text(trend: nil, changeSinceStart: nil, waist: log) == "waist 88.5 cm (\u{2212}1.5)")
        #expect(ProgressLine.text(trend: nil, changeSinceStart: nil) == nil)
        #expect(ProgressLine.text(trend: trend, changeSinceStart: -1.1, waist: WaistLog()) == weight)
    }
}
