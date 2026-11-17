import CoachCore
import SwiftUI

/// First launch (board M1-04): confirm the pre-filled profile, then the
/// permissions screen, then save. Under 5 minutes of taps with every default
/// left alone: "Looks right", "Continue".
struct OnboardingFlow: View {
    let programme: Programme
    let skipSystemPrompts: Bool
    /// Called with the confirmed profile; the caller stores it.
    var onFinish: (Profile) -> Void

    @State private var profile: Profile
    @State private var step = Step.confirm

    private enum Step { case confirm, permissions }

    init(profile: Profile, programme: Programme, skipSystemPrompts: Bool, onFinish: @escaping (Profile) -> Void) {
        _profile = State(initialValue: OnboardingFlow.preFilled(profile))
        self.programme = programme
        self.skipSystemPrompts = skipSystemPrompts
        self.onFinish = onFinish
    }

    /// QA-10: requirements §12 gives the owner's own height and weight, so
    /// the "You" row starts with them. Stored only on the phone.
    static let startHeightCm = 178.0
    static let startWeightKg = 82.0

    static func preFilled(_ profile: Profile) -> Profile {
        guard !profile.confirmed else { return profile }
        var p = profile
        if p.about.heightCm == nil { p.about.heightCm = startHeightCm }
        if p.about.weightKg == nil { p.about.weightKg = startWeightKg }
        return p
    }

    var body: some View {
        switch step {
        case .confirm:
            OnboardingConfirmView(profile: $profile, programme: programme) {
                step = .permissions
            }
        case .permissions:
            PermissionsView(skipSystemPrompts: skipSystemPrompts) {
                var confirmed = profile
                confirmed.confirmed = true
                confirmed.programme.programmeID = programme.id
                if confirmed.programme.startDate == nil {
                    confirmed.programme.startDate = Programme.startDate(confirmedOn: AppClock.now(), calendar: .coach)
                }
                onFinish(confirmed)
            }
        }
    }
}

extension Calendar {
    /// The owner's calendar with Monday-first weeks; used for every plan date.
    static var coach: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }
}
