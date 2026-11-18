import Testing
@testable import CoachCore

/// N7: one plain hint when the pose or distance is off; nothing when it's fine.
@Suite struct PoseCheckTests {
    typealias P = PoseCheck.Point

    /// Standing in the middle, head at 0.9, ankles at 0.1; shoulders `width` apart.
    private func body(width: Double = 0.2, centre: Double = 0.5, top: Double = 0.9, bottom: Double = 0.1) -> PoseCheck.Body {
        PoseCheck.Body(head: P(x: centre, y: top),
                       leftShoulder: P(x: centre - width / 2, y: 0.75), rightShoulder: P(x: centre + width / 2, y: 0.75),
                       leftHip: P(x: centre - 0.06, y: 0.5), rightHip: P(x: centre + 0.06, y: 0.5),
                       leftAnkle: P(x: centre - 0.05, y: bottom), rightAnkle: P(x: centre + 0.05, y: bottom))
    }

    @Test func aGoodFrontPhotoHasNoHint() {
        #expect(PoseCheck.hint(body(), pose: .front) == nil)
        #expect(PoseCheck.hint(body(), pose: .front, reference: body()) == nil)
    }

    @Test func nobodyOrNoFeet() {
        #expect(PoseCheck.hint(nil, pose: .front) == PoseCheck.notFound)
        var noFeet = body()
        noFeet.leftAnkle = nil
        noFeet.rightAnkle = nil
        #expect(PoseCheck.hint(noFeet, pose: .front) == PoseCheck.headToFeet)
    }

    @Test func offCentre() {
        #expect(PoseCheck.hint(body(centre: 0.75), pose: .front) == PoseCheck.centre)
    }

    @Test func facingTheWrongWay() {
        #expect(PoseCheck.hint(body(width: 0.05), pose: .front) == PoseCheck.faceCamera)
        #expect(PoseCheck.hint(body(width: 0.05), pose: .side) == nil)
        #expect(PoseCheck.hint(body(width: 0.2), pose: .side) == PoseCheck.sideOn)
    }

    @Test func distanceMatchesTheFirstPhoto() {
        let first = body(top: 0.8, bottom: 0.2)          // 0.6 tall
        #expect(PoseCheck.hint(body(top: 0.95, bottom: 0.05), pose: .front, reference: first) == PoseCheck.stepBack)
        #expect(PoseCheck.hint(body(top: 0.7, bottom: 0.3), pose: .front, reference: first) == PoseCheck.stepCloser)
        #expect(PoseCheck.hint(body(top: 0.82, bottom: 0.2), pose: .front, reference: first) == nil)
    }
}

extension PoseCheckTests {
    @Test func hintsAreFourWordsAtMost() {
        for hint in [PoseCheck.notFound, PoseCheck.headToFeet, PoseCheck.centre, PoseCheck.faceCamera,
                     PoseCheck.sideOn, PoseCheck.stepBack, PoseCheck.stepCloser] {
            #expect(hint.split(separator: " ").count <= 4, "\(hint)")
        }
    }
}
