import Foundation

extension DayPlan.SessionSlot {
    /// Today's slot after a weather swap (M2-03): the indoor session at the
    /// same start, for the swap's length. nil when the swap isn't for this
    /// slot or names a session the programme doesn't have.
    public func swapped(by swap: WeatherSwap, programme: Programme) -> DayPlan.SessionSlot? {
        guard swap.from == id, let session = programme.sessions[swap.to] else { return nil }
        return DayPlan.SessionSlot(id: swap.to, name: session.name, session: session, start: start,
                                   minutes: swap.durationMinutes, movedFrom: movedFrom)
    }
}

extension DayPlan {
    /// The whole day after a weather swap (QA-20): the session and its
    /// timeline row both become the indoor session, so the row never says
    /// "Run-walk" under an "Indoor circuit" header. Unchanged when there's no
    /// swap or it isn't for today's session.
    public func swapped(by swap: WeatherSwap?, programme: Programme) -> DayPlan {
        guard let swap, let slot = session, let indoor = slot.swapped(by: swap, programme: programme) else { return self }
        let timeline = timeline.map { item in
            item.kind == .session
                ? TimelineItem(kind: .session, time: indoor.start, title: indoor.name,
                               detail: indoor.end.map { "Done by \($0)" })
                : item
        }
        return DayPlan(planned: planned, alarm: alarm, session: indoor, leave: leave,
                       windDown: windDown, lightsOut: lightsOut, timeline: timeline)
    }
}
