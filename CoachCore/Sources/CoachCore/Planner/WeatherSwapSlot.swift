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
