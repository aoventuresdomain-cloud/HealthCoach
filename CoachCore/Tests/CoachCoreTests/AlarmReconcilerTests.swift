import Foundation
import Testing
@testable import CoachCore

/// In-memory stand-in for AlarmKit.
private actor FakeRegistrar: AlarmRegistering {
    private(set) var ids: Set<UUID>
    private(set) var registerCalls: [UUID] = []
    private(set) var cancelCalls: [UUID] = []
    var failOnRegister = false

    init(ids: Set<UUID> = []) { self.ids = ids }

    func setFailOnRegister(_ value: Bool) { failOnRegister = value }

    func registeredAlarmIDs() async throws -> Set<UUID> { ids }

    func register(_ alarm: PlannedAlarm) async throws {
        if failOnRegister { throw FakeError.refused }
        registerCalls.append(alarm.id)
        ids.insert(alarm.id)
    }

    func cancel(alarmID: UUID) async throws {
        cancelCalls.append(alarmID)
        ids.remove(alarmID)
    }

    enum FakeError: Error { case refused }
}

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func alarms(_ hoursAhead: [Double]) -> [PlannedAlarm] {
    hoursAhead.map { PlannedAlarm(fireDate: now.addingTimeInterval($0 * 3600), title: "t") }
}

@Suite struct AlarmReconcilerTests {
    @Test func noneMissingChangesNothing() async throws {
        let planned = alarms([1, 2, 3])
        let fake = FakeRegistrar(ids: Set(planned.map(\.id)))
        let outcome = try await AlarmReconciler.reconcile(planned: planned, using: fake, now: now)
        #expect(outcome == ReconcileOutcome(total: 3, reSet: 0, cancelled: 0, next: planned[0].fireDate))
        #expect(await fake.registerCalls.isEmpty)
        #expect(await fake.cancelCalls.isEmpty)
    }

    @Test func someMissingAreReSet() async throws {
        let planned = alarms([1, 2, 3, 4])
        let fake = FakeRegistrar(ids: [planned[0].id, planned[2].id])
        let outcome = try await AlarmReconciler.reconcile(planned: planned, using: fake, now: now)
        #expect(outcome.reSet == 2)
        #expect(outcome.total == 4)
        #expect(await fake.registerCalls == [planned[1].id, planned[3].id])
        #expect(await fake.ids == Set(planned.map(\.id)))
    }

    @Test func allMissingAreReSet() async throws {
        let planned = alarms([5, 1, 3])
        let fake = FakeRegistrar()
        let outcome = try await AlarmReconciler.reconcile(planned: planned, using: fake, now: now)
        #expect(outcome.reSet == 3)
        #expect(outcome.next == now.addingTimeInterval(3600))
        // Soonest first, so a failure part-way still leaves the nearest alarms set.
        #expect(await fake.registerCalls == [planned[1].id, planned[2].id, planned[0].id])
    }

    @Test func pastAlarmsAreNeitherCountedNorReSet() async throws {
        let planned = alarms([-1, 0, 2])
        let fake = FakeRegistrar()
        let outcome = try await AlarmReconciler.reconcile(planned: planned, using: fake, now: now)
        #expect(outcome.total == 1)
        #expect(await fake.registerCalls == [planned[2].id])
    }

    @Test func alarmsNoLongerPlannedAreCancelled() async throws {
        let planned = alarms([1])
        let stray = UUID()
        let fake = FakeRegistrar(ids: [planned[0].id, stray])
        let outcome = try await AlarmReconciler.reconcile(planned: planned, using: fake, now: now)
        #expect(outcome.cancelled == 1)
        #expect(await fake.cancelCalls == [stray])
    }

    @Test func emptyPlanNeverCancelsRegisteredAlarms() async throws {
        let registered: Set<UUID> = [UUID(), UUID()]
        let fake = FakeRegistrar(ids: registered)
        let outcome = try await AlarmReconciler.reconcile(planned: [], using: fake, now: now)
        #expect(outcome.cancelled == 0)
        #expect(await fake.cancelCalls.isEmpty)
        #expect(await fake.ids == registered)
    }

    @Test func planWithOnlyPastAlarmsNeverCancels() {
        let changes = AlarmReconciler.plan(planned: alarms([-2, -1]), registered: [UUID()], now: now)
        #expect(changes.toCancel.isEmpty)
        #expect(changes.toRegister.isEmpty)
    }

    @Test func emptyPlanReportsNothingNext() async throws {
        let outcome = try await AlarmReconciler.reconcile(planned: [], using: FakeRegistrar(), now: now)
        #expect(outcome == ReconcileOutcome(total: 0, reSet: 0, cancelled: 0, next: nil))
    }

    @Test func registrationErrorPropagates() async throws {
        let fake = FakeRegistrar()
        await fake.setFailOnRegister(true)
        await #expect(throws: (any Error).self) {
            try await AlarmReconciler.reconcile(planned: alarms([1]), using: fake, now: now)
        }
    }
}

@Suite struct TestAlarmScheduleTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }

    @Test func makesFourteenWithFirstTwoMinutesAheadOnAWholeMinute() {
        let start = Date(timeIntervalSince1970: 1_800_000_030) // :30 seconds past a minute
        let plan = TestAlarmSchedule.make(now: start, calendar: calendar)
        #expect(plan.count == 14)
        #expect(Set(plan.map(\.id)).count == 14)
        let lead = plan[0].fireDate.timeIntervalSince(start)
        #expect(lead >= 120 && lead < 180)
        #expect(calendar.component(.second, from: plan[0].fireDate) == 0)
    }

    @Test func laterAlarmsStartThreeWeeksOutOneADay() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = TestAlarmSchedule.make(now: start, calendar: calendar)
        let days = plan.dropFirst().compactMap {
            calendar.dateComponents([.day], from: plan[0].fireDate, to: $0.fireDate).day
        }
        #expect(days == Array(21...33))
    }

    @Test func clearingKeepsTheNearAlarmAndDropsTheLaterThirteen() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = TestAlarmSchedule.make(now: start, calendar: calendar)
        let split = TestAlarmSchedule.splitForClearing(plan, now: start)
        #expect(split.keep.map(\.id) == [plan[0].id])
        #expect(split.drop.map(\.id) == plan.dropFirst().map(\.id))
    }

    @Test func zeroCountMakesNothing() {
        #expect(TestAlarmSchedule.make(now: now, count: 0).isEmpty)
    }

    @Test func exactMinuteIsNotPushedOn() {
        let exact = Date(timeIntervalSince1970: 1_800_000_000) // a whole minute (divisible by 60)
        #expect(TestAlarmSchedule.roundedUpToMinute(exact, calendar: calendar) == exact)
    }
}
