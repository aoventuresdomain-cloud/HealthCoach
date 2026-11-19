import AVFoundation
import CoachCore
import SwiftUI
import UIKit
import Vision

/// N7: the photo-day camera. Front lens so the owner sees the ghost and the
/// hint from where they stand; a body-pose check on a frame about twice a
/// second (Vision, on the phone, no network); a still on demand. Nothing
/// here leaves the phone.
@MainActor
@Observable
final class PhotoCamera {
    /// The latest body found in the preview; nil before the first check or when nobody is in view.
    private(set) var body: PoseCheck.Body?
    /// Frames checked so far; 0 means no hint yet.
    private(set) var checks = 0

    @ObservationIgnored let controller = CaptureController()

    var session: AVCaptureSession { controller.session }

    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    init() {
        controller.onBody = { [weak self] body in
            guard let self else { return }
            Task { @MainActor in
                self.body = body
                self.checks += 1
            }
        }
    }

    /// Asks once; false when the owner said no (the library stands in).
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func start() { controller.start() }
    func stop() { controller.stop() }
    func capture() async -> UIImage? { await controller.capture() }
}

/// The capture session and its delegates, on their own queue.
nonisolated final class CaptureController: NSObject, @unchecked Sendable,
    AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    var onBody: (@Sendable (PoseCheck.Body?) -> Void)?

    private let stillOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "photo.camera")
    private var configured = false
    private var lastCheck = Date.distantPast
    private var pending: CheckedContinuation<UIImage?, Never>?

    func start() {
        queue.async {
            guard self.configure() else { return }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func capture() async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.configured, self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                self.pending = continuation
                self.stillOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    private func configure() -> Bool {
        if configured { return true }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(stillOutput) { session.addOutput(stillOutput) }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        // Portrait stills and frames, so Vision's points match the preview.
        for connection in [stillOutput.connection(with: .video), videoOutput.connection(with: .video)].compactMap({ $0 })
        where connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        session.commitConfiguration()
        configured = true
        return true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastCheck) >= 0.5,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastCheck = now
        onBody?(BodyPoseReader.body(VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)))
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: (any Error)?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        queue.async {
            self.pending?.resume(returning: image)
            self.pending = nil
        }
    }
}

/// Vision's body pose, mapped to the points `PoseCheck` reads.
nonisolated enum BodyPoseReader {
    static func body(_ handler: VNImageRequestHandler) -> PoseCheck.Body? {
        let request = VNDetectHumanBodyPoseRequest()
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              let points = try? observation.recognizedPoints(.all) else { return nil }
        func point(_ name: VNHumanBodyPoseObservation.JointName) -> PoseCheck.Point? {
            guard let p = points[name], p.confidence > 0.3 else { return nil }
            return PoseCheck.Point(x: Double(p.location.x), y: Double(p.location.y))
        }
        return PoseCheck.Body(head: point(.nose),
                              leftShoulder: point(.leftShoulder), rightShoulder: point(.rightShoulder),
                              leftHip: point(.leftHip), rightHip: point(.rightHip),
                              leftAnkle: point(.leftAnkle), rightAnkle: point(.rightAnkle))
    }

    static func body(in image: UIImage) -> PoseCheck.Body? {
        guard let cgImage = image.cgImage else { return nil }
        return body(VNImageRequestHandler(cgImage: cgImage, orientation: orientation(image.imageOrientation)))
    }

    private static func orientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

/// The live preview, filling its frame like the ghost over it.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}
