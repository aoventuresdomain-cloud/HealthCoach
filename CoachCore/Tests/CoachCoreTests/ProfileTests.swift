import Foundation
import Testing
@testable import CoachCore

@Suite struct ProfileTests {
    @Test func defaultsMatchTheRequirementsDraft() {
        let profile = Profile()
        #expect(profile.schemaVersion == 1)
        #expect(!profile.confirmed)
        #expect(profile.schedule.sleepHours == 7.5)
        #expect(profile.schedule.longSessionDay == .sunday)
        #expect(profile.training.maxSessionMinutes == 45)
        #expect(profile.training.dumbbellMaxKg == 24)
        #expect(profile.coach.checkInTime == TimeOfDay(hour: 18, minute: 0))
        #expect(profile.about.painAreas.isEmpty)
    }

    @Test func roundTrips() throws {
        var profile = Profile()
        profile.confirmed = true
        profile.about.weightKg = 82
        profile.about.painAreas = ["left shoulder"]
        profile.schedule.earliestWake = TimeOfDay(hour: 6, minute: 15)
        profile.programme.startDate = Date(timeIntervalSince1970: 1_795_000_000)
        let decoded = try Profile.decoded(from: profile.encoded())
        #expect(decoded == profile)
    }

    @Test func timesAreStoredAsHoursAndMinutes() throws {
        let json = try JSONDecoder().decode(JSONValue.self, from: Profile().encoded())
        #expect(json["schedule"]?["earliestWake"] == .string("05:45"))
    }

    @Test func missingFieldsTakeDefaultsAtAnyDepth() throws {
        let sparse = Data(#"{"schemaVersion": 1, "confirmed": true, "training": {"maxSessionMinutes": 40}}"#.utf8)
        let profile = try Profile.decoded(from: sparse)
        #expect(profile.confirmed)
        #expect(profile.training.maxSessionMinutes == 40)
        #expect(profile.training.dumbbellMaxKg == 24) // missing inside a present object
        #expect(profile.schedule == Profile.Schedule())
    }

    @Test func newerRecordIsRejectedPlainly() {
        #expect(throws: ContentError.newerThanSupported(file: "Profile", found: 2, supported: 1)) {
            try Profile.decoded(from: Data(#"{"schemaVersion": 2}"#.utf8))
        }
    }

    @Test func brokenRecordIsRejected() {
        #expect(throws: ContentError.self) { try Profile.decoded(from: Data("garbage".utf8)) }
        #expect(throws: ContentError.self) {
            try Profile.decoded(from: Data(#"{"schemaVersion": 1, "schedule": {"earliestWake": "25:99"}}"#.utf8))
        }
    }

    @Test func weekdayFromCalendar() {
        #expect(Weekday(calendarWeekday: 1) == .sunday)
        #expect(Weekday(calendarWeekday: 2) == .monday)
        #expect(Weekday(calendarWeekday: 7) == .saturday)
    }
}
