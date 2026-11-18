import Foundation
import Testing
@testable import CoachCore

/// Board N2: one line per change, with its reason; no lines when nothing changed.
@Suite struct CoachChangesTests {
    let f = CoachFixture()
    let loop = CoachLoopTests()

    func names() throws -> (String) -> String {
        let lib = try ContentLibrary.load(from: contentRoot)
        return { lib.exercises.exercise($0)?.name ?? $0 }
    }

    func changes(_ p: Programme, history: [SessionLog] = [], weights: [WeightSample],
                 blocks: [CoachBlock] = [], at now: Date) throws -> [CoachChange] {
        CoachChanges.make(programme: p, profile: f.profile(), history: history, weights: weights, blocks: blocks,
                          now: now, name: try names(), calendar: f.calendar)
    }

    @Test func aCalorieDropSaysWhy() throws {
        let p = try f.phase1()
        // Flat weight: the week 3 check takes 100 off.
        let flat = f.weights(to: 16) { _ in 82 }
        let c = try changes(p, weights: flat, at: f.day(16, hour: 12))
        #expect(c == [CoachChange(kind: .calories, line: "Calories 2,000 → 1,900: weight flat for 2 weeks")])
        // Losing, but slowly.
        let slow = try changes(p, weights: f.losing(0.25, to: 16), at: f.day(16, hour: 12))
        #expect(slow.map(\.line) == ["Calories 2,000 → 1,900: losing 0.3 kg a week over 2 weeks (aim 0.4–0.8 kg)"])
        // Fast: up 100.
        let fast = try changes(p, weights: f.losing(1.5, to: 16), at: f.day(16, hour: 12))
        #expect(fast.map(\.line) == ["Calories 2,000 → 2,100: losing 1.5 kg a week over 2 weeks, faster than the aim 0.4–0.8 kg, so more to keep muscle"])
    }

    @Test func aLoadRiseSaysWhy() throws {
        let p = try f.phase1()
        let history = try loop.fourWeeks(p)
        let sunday = f.day(27, hour: 18)
        let c = try changes(p, history: history, weights: f.losing(0.5, to: 27), at: sunday)
        #expect(c == [CoachChange(kind: .load, line: "Farmer's carry 16 kg → 18 kg per dumbbell: top of the range done last time, so one step up")])
    }

    @Test func anImportedBlockGivesALinePerChange() throws {
        let p = try f.phase1()
        let history = try loop.fourWeeks(p)
        let weights = f.losing(0.5, to: 29)
        let reply = loop.reply("\"note\": \"Ease off full body, more food.\", \"dailyKcal\": 2100, \"proteinG\": 170, \"dropSessions\": [\"full-body\"]")
        let outcome = CoachImport.importing(reply, into: [], programme: p, profile: f.profile(),
                                            now: f.day(27, hour: 18), calendar: f.calendar)
        #expect(outcome.error == nil, "\(outcome.message)")
        // Sunday evening: imported, applies tomorrow.
        let sunday = try changes(p, history: history, weights: weights, blocks: outcome.blocks, at: f.day(27, hour: 19))
        #expect(sunday.first == CoachChange(kind: .coachReply,
                                            line: "Claude's reply imported Sun 13 Dec 2026, applies from tomorrow: Ease off full body, more food."))
        // Tuesday: in force.
        let tuesday = try changes(p, history: history, weights: weights, blocks: outcome.blocks, at: f.day(29, hour: 12))
        #expect(tuesday.map(\.line) == [
            "Claude's reply imported Sun 13 Dec 2026: Ease off full body, more food.",
            "Calories 2,000 → 2,100: set by Claude's reply",
            "Protein 160 → 170 g: set by Claude's reply",
            "Full body (light legs) left out: Claude's reply",
            // Saturday's log, inside the same week.
            "Farmer's carry 16 kg → 18 kg per dumbbell: top of the range done last time, so one step up",
        ])
    }

    @Test func theDumbbellLimitIsFlaggedOnce() throws {
        let p = try f.phase1()
        let history = try loop.fourWeeks(p)
        let weights = f.losing(0.5, to: 29)
        let reply = loop.reply("\"loads\": [{\"exercise\": \"dumbbell-goblet-squat\", \"kg\": 24}]")
        let outcome = CoachImport.importing(reply, into: [], programme: p, profile: f.profile(),
                                            now: f.day(27, hour: 18), calendar: f.calendar)
        #expect(outcome.error == nil, "\(outcome.message)")
        let c = try changes(p, history: history, weights: weights, blocks: outcome.blocks, at: f.day(29, hour: 12))
        let kinds = c.map(\.kind)
        #expect(kinds == [.coachReply, .load, .load, .dumbbellLimit], "\(c.map(\.line))")
        #expect(c.contains(CoachChange(kind: .load, line: "Goblet squat 12 kg → 24 kg per dumbbell: set by Claude's reply")),
                "\(c.map(\.line))")
        #expect(c.last?.line == "Goblet squat is at the 24 kg dumbbells: progress now comes from reps and a slower tempo. Worth asking the coach about heavier dumbbells.")
        // A week on, still at the limit but nothing new to say.
        let later = try changes(p, history: history, weights: f.losing(0.5, to: 36), blocks: outcome.blocks,
                                at: f.day(36, hour: 12))
        #expect(!later.contains { $0.kind == .dumbbellLimit })
    }

    @Test func aReducedWeekSaysWhy() throws {
        let p = try f.phase1()
        var history = try loop.fourWeeks(p)
        // The last two strength logs: week 4 Thu and Sat. Make both Sore.
        let strength = history.indices.filter { if case .strength = p.sessions[history[$0].sessionID] { true } else { false } }
        for index in strength.suffix(2) { history[index].recovery = .sore }
        let c = try changes(p, history: history, weights: f.losing(0.5, to: 29), at: f.day(29, hour: 12))
        #expect(c.contains(CoachChange(kind: .sessions,
                                       line: "Full body (light legs) left out: sore after the last 2 strength sessions, so an easier week")),
                "\(c.map(\.line))")
    }

    @Test func noLinesWhenNothingChanged() throws {
        let p = try f.phase1()
        #expect(try changes(p, weights: f.losing(0.5, to: 12), at: f.day(12, hour: 12)).isEmpty)
        // On track at the week 3 check: calories stay, so still nothing.
        #expect(try changes(p, weights: f.losing(0.5, to: 16), at: f.day(16, hour: 12)).isEmpty)
        // Before a week has passed since the start, or before onboarding.
        #expect(try changes(p, weights: f.losing(0.5, to: 3), at: f.day(3, hour: 12)).isEmpty)
        var none = f.profile()
        none.programme.startDate = nil
        #expect(CoachChanges.make(programme: p, profile: none, history: [], weights: [], blocks: [],
                                  now: f.day(16), calendar: f.calendar).isEmpty)
    }
}

/// Board N1: pain from the check-in shows in What changed (Advisor conditions).
@Suite struct CoachChangesPainTests {
    let f = CoachFixture()
    let loop = CoachLoopTests()

    func changes(_ checkIns: [CheckIn], at now: Date) throws -> [CoachChange] {
        let p = try f.phase1()
        let lib = try ContentLibrary.load(from: contentRoot)
        return CoachChanges.make(programme: p, profile: f.profile(), history: try loop.fourWeeks(p),
                                 weights: f.losing(0.5, to: 29), blocks: [], checkIns: checkIns,
                                 exercises: lib.exercises, now: now,
                                 name: { lib.exercises.exercise($0)?.name ?? $0 }, calendar: f.calendar)
    }

    @Test func kneePainGivesOneWalkLineAndASwapLine() throws {
        let now = f.day(29, hour: 12)
        // Still being answered: dated now, it counts from now.
        let c = try changes([CheckIn(date: now, pain: [.knee])], at: now)
        let walk = c.filter { $0.kind == .runWalk }
        #expect(walk.count == 1)
        #expect(walk.first?.line.hasPrefix("Run-walk is a brisk ") == true, "\(walk)")
        #expect(walk.first?.line.hasSuffix("-minute walk this week: easier on the knee.") == true, "\(walk)")
        #expect(c.contains(CoachChange(kind: .painSwap, line: "Goblet squat → Glute bridge this week: easier on the knee")),
                "\(c.map(\.line))")
        // Order: after sessions, before loads.
        let kinds = c.map(\.kind)
        if let lastPain = kinds.lastIndex(where: { $0 == .runWalk || $0 == .painSwap }),
           let firstLoad = kinds.firstIndex(of: .load) {
            #expect(lastPain < firstLoad)
        }
        #expect(kinds.firstIndex(of: .runWalk)! < kinds.firstIndex(of: .painSwap)!)
    }

    @Test func noCheckInOrOnlyOtherAddsNothing() throws {
        let now = f.day(29, hour: 12)
        let none = try changes([], at: now)
        #expect(!none.contains { $0.kind == .runWalk || $0.kind == .painSwap })
        let other = try changes([CheckIn(date: now, pain: [.other])], at: now)
        #expect(other == none, "Other never shows")
        let noPain = try changes([CheckIn(date: now)], at: now)
        #expect(noPain == none)
        // A week on, the knee answer is over.
        let later = try changes([CheckIn(date: f.day(21, hour: 12), pain: [.knee])], at: now)
        #expect(!later.contains { $0.kind == .runWalk || $0.kind == .painSwap })
    }

    @Test func shoulderPainSwapsWithoutAWalkLine() throws {
        let now = f.day(29, hour: 12)
        let c = try changes([CheckIn(date: now, pain: [.shoulder])], at: now)
        #expect(!c.contains { $0.kind == .runWalk })
        let swaps = c.filter { $0.kind == .painSwap }
        #expect(!swaps.isEmpty)
        #expect(swaps.allSatisfy { $0.line.hasSuffix("easier on the shoulder") }, "\(swaps.map(\.line))")
        #expect(Set(swaps.map(\.line)).count == swaps.count, "one line per exercise")
    }
}
