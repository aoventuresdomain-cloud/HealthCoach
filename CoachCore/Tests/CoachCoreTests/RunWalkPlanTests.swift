import Foundation
import Testing
@testable import CoachCore

@Suite struct RunWalkPlanTests {
    private func run(_ id: String) throws -> RunWalkSession {
        let programme = try #require(ContentLibrary.load(from: contentRoot).programmes["phase-1"])
        guard case let .runWalk(session) = programme.sessions[id] else {
            Issue.record("\(id) is not a run-walk")
            throw CancellationError()
        }
        return session
    }

    @Test func weekOneIsTenOneMinuteJogsBetweenWalks() throws {
        let session = try run("run-1")
        let plan = try #require(RunWalkPlan.make(sessionID: "run-1", session: session, week: 1))
        let week = try #require(session.weeks.first { $0.week == 1 })
        #expect(plan.repeats == 10)
        #expect(plan.segments.first?.kind == .warmUp)
        #expect(plan.segments.last?.kind == .coolDown)
        #expect(plan.segments.filter(\.isJog).allSatisfy { $0.seconds == 60 })
        #expect(plan.totalSeconds == week.durationMinutes * 60)
        #expect(Double(plan.jogSeconds) / 60 == week.jogMinutes)
    }

    @Test func everyWeekMatchesItsStatedLength() throws {
        for id in ["run-1", "run-2"] {
            let session = try run(id)
            for week in session.weeks {
                let plan = try #require(RunWalkPlan.make(sessionID: id, session: session, week: week.week))
                #expect(plan.totalSeconds == week.durationMinutes * 60, "\(id) week \(week.week)")
            }
        }
    }

    @Test func laterWeeksBuildTowardsFiveKilometres() throws {
        let session = try run("run-1")
        let jog = session.weeks.compactMap { RunWalkPlan.make(sessionID: "run-1", session: session, week: $0.week)?.jogSeconds }
        #expect(jog.first! < jog.last!)
        #expect(zip(jog, jog.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test func noPlanInAWeekTheSessionDoesNotRun() throws {
        #expect(RunWalkPlan.make(sessionID: "run-2", session: try run("run-2"), week: 1) == nil)
    }

    @Test func cuesSetTheEffortOnceThenCallEachChange() throws {
        let plan = try #require(RunWalkPlan.make(sessionID: "run-1", session: run("run-1"), week: 1))
        #expect(plan.cue(at: 0) == "Warm-up walk for 5 minutes. Easy pace: you could chat.")
        #expect(plan.cue(at: 2) == "Walk for 1 minute")
        #expect(plan.cue(at: 3) == "Jog for 1 minute")
        #expect(plan.cue(at: plan.segments.count - 1).hasPrefix("Last one"))
    }
}
