import Foundation
import Testing
@testable import CoachCore

/// Board N9: one route per notification kind, shared by the real tap and `-openFrom`.
@Suite struct NotificationRouteTests {
    @Test func eachKindHasItsScreen() {
        #expect(NotificationRoute.destination(for: .morningBrief) == .today)
        #expect(NotificationRoute.destination(for: .leaveNow) == .today)
        #expect(NotificationRoute.destination(for: .windDown) == .today)
        #expect(NotificationRoute.destination(for: .sundayPrompt) == .sundayPrompt)
        #expect(NotificationRoute.destination(for: .deliveryReminder) == .shopping)
        #expect(NotificationRoute.destination(for: .checkpoint) == .askCoach)
        #expect(NotificationRoute.destination(for: .photoDay) == .today)  // until N12
    }

    /// The planner's ids are what the real tap hands back; each one routes to its kind.
    @Test func plannedIdsRouteLikeTheLaunchArgument() {
        for kind in CoachNotification.Kind.allCases {
            let id = "\(kind.rawValue)-2026-11-22"
            #expect(NotificationRoute.kind(identifier: id) == kind)
            #expect(NotificationRoute.kind(openFrom: "notification:\(kind.rawValue)") == kind)
            #expect(NotificationRoute.destination(for: NotificationRoute.kind(identifier: id)!)
                    == NotificationRoute.destination(for: NotificationRoute.kind(openFrom: "notification:\(kind.rawValue)")!))
        }
    }

    @Test func unknownOnesGoNowhere() {
        #expect(NotificationRoute.kind(identifier: "someone-else") == nil)
        #expect(NotificationRoute.kind(identifier: "morningBrief") == nil)   // no day part: not ours
        #expect(NotificationRoute.kind(openFrom: nil) == nil)
        #expect(NotificationRoute.kind(openFrom: "sundayPrompt") == nil)
        #expect(NotificationRoute.kind(openFrom: "notification:nope") == nil)
    }
}
