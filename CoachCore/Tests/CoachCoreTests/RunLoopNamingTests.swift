import Foundation
import Testing
@testable import CoachCore

/// Board N10: the run-walk player names the Hyde Park loop closest to the
/// session's distance.
@Suite struct RunLoopNamingTests {
    private func library() throws -> ContentLibrary { try ContentLibrary.load(from: contentRoot) }

    @Test func everyRunWalkWeekNamesItsClosestLoop() throws {
        let lib = try library()
        var checked = 0
        for programme in lib.phases {
            for (id, session) in programme.sessions {
                guard case let .runWalk(run) = session else { continue }
                let loops = try #require(lib.runLoops[run.route], "\(programme.id) \(id): no loops for \(run.route)")
                for week in run.weeks {
                    let plan = try #require(RunWalkPlan.make(sessionID: id, session: run, week: week.week)?.naming(loops))
                    let loop = try #require(plan.loop)
                    let gap = abs(loop.distanceKm - plan.estimatedKm)
                    let closest = loops.loops.allSatisfy { gap <= abs($0.distanceKm - plan.estimatedKm) }
                    #expect(closest, "\(programme.id) \(id) week \(week.week)")
                    #expect(plan.loopLine?.hasPrefix(loop.name) == true)
                    checked += 1
                }
            }
        }
        #expect(checked > 0)
    }

    @Test func theDistanceEstimateIsPlausible() throws {
        let p1 = try #require(library().programmes["phase-1"])
        guard case let .runWalk(run)? = p1.sessions["run-1"] else { Issue.record("no run-1"); return }
        for week in run.weeks {
            let plan = try #require(RunWalkPlan.make(sessionID: "run-1", session: run, week: week.week))
            let hours = Double(plan.totalSeconds) / 3600
            // Between all walking and all jogging.
            #expect(plan.estimatedKm >= (hours * RunWalkPlan.walkKmh * 10).rounded(.down) / 10)
            #expect(plan.estimatedKm <= (hours * RunWalkPlan.jogKmh * 10).rounded(.up) / 10)
        }
        // A brisk walk is named too; without a loops file nothing is.
        let brisk = try #require(RunWalkPlan.briskWalk(sessionID: "run-1", session: run, week: 1))
        let hydePark = try library().runLoops["hyde-park"]
        #expect(brisk.naming(hydePark).loop != nil)
        #expect(brisk.naming(nil).loop == nil && brisk.loopLine == nil)
    }

    @Test func theLoopLineReadsNaturally() throws {
        let loops = try #require(library().runLoops["hyde-park"])
        let plan = try #require(library().programmes["phase-1"]).sessions["run-1"]
        guard case let .runWalk(run)? = plan else { Issue.record("no run-1"); return }
        let named = try #require(RunWalkPlan.make(sessionID: "run-1", session: run, week: 1)?.naming(loops))
        let line = try #require(named.loopLine)
        #expect(line.contains(", about ") && line.hasSuffix(" km") && !line.contains(".0 km"))
    }
}
