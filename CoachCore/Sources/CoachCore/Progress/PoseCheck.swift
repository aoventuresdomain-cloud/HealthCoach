import Foundation

/// N7: one plain hint when a progress photo's pose or distance is off, from
/// body points found on the phone (Vision's body pose, never a network call).
/// Pure, so the rules are tested on Linux. Thresholds are first guesses, to
/// be tuned on the phone once the paid account allows installs.
public enum PoseCheck {
    public enum Pose: String, Sendable { case front, side }

    /// Normalised image points, origin bottom-left (Vision's convention).
    public struct Point: Sendable, Equatable {
        public let x: Double
        public let y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }
    }

    /// The points the check needs; nil where the detector wasn't sure.
    public struct Body: Sendable, Equatable {
        public var head: Point?
        public var leftShoulder: Point?
        public var rightShoulder: Point?
        public var leftHip: Point?
        public var rightHip: Point?
        public var leftAnkle: Point?
        public var rightAnkle: Point?
        public init(head: Point? = nil, leftShoulder: Point? = nil, rightShoulder: Point? = nil,
                    leftHip: Point? = nil, rightHip: Point? = nil, leftAnkle: Point? = nil, rightAnkle: Point? = nil) {
            self.head = head
            self.leftShoulder = leftShoulder
            self.rightShoulder = rightShoulder
            self.leftHip = leftHip
            self.rightHip = rightHip
            self.leftAnkle = leftAnkle
            self.rightAnkle = rightAnkle
        }

        /// Head to the lower ankle, as a share of the image height.
        var height: Double? {
            guard let head, let ankle = [leftAnkle, rightAnkle].compactMap({ $0 }).map(\.y).min() else { return nil }
            return head.y - ankle
        }

        /// Middle of the shoulders and hips that were found.
        var centreX: Double? {
            let xs = [leftShoulder, rightShoulder, leftHip, rightHip].compactMap { $0?.x }
            return xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
        }

        /// Shoulder width over body height: wide facing the camera, narrow side on.
        var shoulderRatio: Double? {
            guard let l = leftShoulder, let r = rightShoulder, let h = height, h > 0 else { return nil }
            return abs(l.x - r.x) / h
        }
    }

    public static let notFound = "Can't see you. Stand back so you're in from head to feet."
    public static let headToFeet = "Step back so your head and feet are both in."
    public static let centre = "Move to the middle of the frame."
    public static let faceCamera = "Face the camera, arms by your sides."
    public static let sideOn = "Turn side on to the camera."
    public static let stepBack = "Step back a little, to match the first photo."
    public static let stepCloser = "Step a little closer, to match the first photo."

    /// Off-centre by more than this share of the width.
    static let centreTolerance = 0.15
    /// Shoulder ratio at or above this reads as facing the camera.
    static let facingRatio = 0.15
    /// Height differing from the first photo's by more than this share.
    static let distanceTolerance = 0.15

    /// The one hint to show, or nil when the photo is fine. `reference` is the
    /// first photo of the same pose, so later ones match its distance.
    public static func hint(_ body: Body?, pose: Pose, reference: Body? = nil) -> String? {
        guard let body, body.head != nil || body.centreX != nil else { return notFound }
        guard let height = body.height, height > 0 else { return headToFeet }
        if let x = body.centreX, abs(x - 0.5) > centreTolerance { return centre }
        if let ratio = body.shoulderRatio {
            if pose == .front, ratio < facingRatio { return faceCamera }
            if pose == .side, ratio >= facingRatio { return sideOn }
        }
        if let first = reference?.height, first > 0 {
            if height > first * (1 + distanceTolerance) { return stepBack }
            if height < first * (1 - distanceTolerance) { return stepCloser }
        }
        return nil
    }
}
