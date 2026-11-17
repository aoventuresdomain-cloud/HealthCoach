import SwiftUI

// Rest-timer layouts shared by the Live Activity (LiveActivity/) and the app's
// screenshot preview (App/Spikes/LiveActivityPreviewView.swift), so CI
// screenshots show exactly what the lock screen draws. Spike S3, board M0-06.

struct RestTimerLockScreenView: View {
    let title: String
    let nextUp: String
    let endsAt: Date

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(nextUp)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            RestCountdown(endsAt: endsAt)
                .font(.coachNumber(44))
        }
        .padding()
        .foregroundStyle(.white)
    }
}

/// Counts down to `endsAt` and stops at 0:00 rather than counting up.
struct RestCountdown: View {
    let endsAt: Date

    var body: some View {
        // Guard against an end date already in the past: a reversed range traps.
        let start = min(Date.now, endsAt)
        Text(timerInterval: start...endsAt, countsDown: true, showsHours: false)
            .multilineTextAlignment(.trailing)
    }
}

struct RunWalkLockScreenView: View {
    let title: String
    let state: RunWalkAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Text(state.label)
                    .font(.coachNumber(34, weight: .heavy))
                    .foregroundStyle(state.isJog ? .green : .blue)
                Text("\(state.progress) · \(state.nextUp)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            RunWalkClock(state: state)
                .font(.coachNumber(44))
        }
        .padding()
        .foregroundStyle(.white)
    }
}

/// Counts down to the segment's end, or shows the paused time still.
struct RunWalkClock: View {
    let state: RunWalkAttributes.ContentState

    var body: some View {
        if let paused = state.pausedRemaining {
            Text("\(paused / 60):\(String(format: "%02d", paused % 60))")
        } else {
            RestCountdown(endsAt: state.endsAt)
        }
    }
}
