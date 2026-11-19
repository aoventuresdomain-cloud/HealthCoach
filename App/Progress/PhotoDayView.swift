import AudioToolbox
import CoachCore
import PhotosUI
import SwiftUI
import UIKit

/// Photo day (board M4-03, N7): front, then side, each on a full-screen
/// camera with a ghost of the first photo of that pose and one hint line;
/// the shutter starts a 3 s self-timer so the phone can sit on a shelf. Then
/// one review screen and Save. Camera permission is asked here, on the first
/// photo day; without a camera (the simulator) or without permission, a
/// library photo stands in for the viewfinder. Everything stays on the phone.
struct PhotoDayView: View {
    let date: Date
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @State private var images: [ProgressStore.Pose: UIImage] = [:]
    /// The pose being shot; nil shows the review.
    @State private var shooting: ProgressStore.Pose? = .front
    @State private var error: String?
    /// N7: the waist row, only when turned on in Preferences; pre-filled with the last value.
    @State private var waistCm = WaistStore.shared.log.prefillCm

    private var store: ProgressStore { .shared }

    var body: some View {
        if let pose = shooting {
            PhotoCaptureView(pose: pose, ghost: firstPhoto(pose), onCancel: { dismiss() }) { image in
                if let image { images[pose] = image }
                shooting = next(after: pose)
            }
        } else {
            review
        }
    }

    /// The pose after `pose` that has no photo yet; nil when both are done.
    private func next(after pose: ProgressStore.Pose) -> ProgressStore.Pose? {
        ProgressStore.Pose.allCases.first { $0 != pose && images[$0] == nil }
    }

    /// The first photo of this pose, for the ghost.
    private func firstPhoto(_ pose: ProgressStore.Pose) -> UIImage? {
        let sets = store.sets(calendar: calendar).filter { store.image(day: $0.day, pose: pose) != nil }
        return PhotoPairing.ghost(sets.map(\.date)).flatMap { store.image(day: sets[$0].day, pose: pose) }
    }

    private var review: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(ProgressStore.Pose.allCases) { pose in
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground))
                                if let image = images[pose] {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else {
                                    Image(systemName: pose == .front ? "figure.stand" : "figure.walk")
                                        .font(.coachSymbol(64))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(height: 260)
                            .clipShape(.rect(cornerRadius: 14))
                            .accessibilityLabel("\(pose.title) photo")
                            Button(images[pose] == nil ? "Take \(pose.rawValue)" : "Retake") { shooting = pose }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("photo.retake.\(pose.rawValue)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                if WaistStore.shared.isOn {
                    waistRow
                }
                if let error {
                    Text(error).foregroundStyle(.orange).accessibilityIdentifier("photo.error")
                }
                Spacer()
            }
            .padding(16)
            .navigationTitle("Photo day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not today") { dismiss() }.accessibilityIdentifier("photo.cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                ActionBar {
                    Button("Save") { save() }
                        .buttonStyle(PrimaryActionStyle())
                        .disabled(images.isEmpty)
                        .accessibilityIdentifier("photo.save")
                }
            }
        }
    }

    /// A stepper in 0.5 cm steps, so no typing (E4), with the one measuring rule.
    private var waistRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Stepper(value: $waistCm, in: WaistLog.rangeCm, step: WaistLog.stepCm) {
                HStack {
                    Text("Waist")
                    Spacer()
                    Text(WaistStore.text(waistCm)).monospacedDigit()
                }
            }
            .accessibilityValue(WaistStore.text(waistCm))
            .accessibilityIdentifier("photo.waist")
            Text("At the navel, after breathing out")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private func save() {
        do {
            for (pose, image) in images {
                try store.save(image, pose: pose, on: date, calendar: calendar)
            }
            if WaistStore.shared.isOn {
                WaistStore.shared.save(waistCm, on: date, calendar: calendar)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// A drawn figure for UI tests; `widen` makes later sets look different in a compare.
    static func testImage(_ pose: ProgressStore.Pose, widen: CGFloat = 0) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            UIColor.systemGray.setFill()
            let width: CGFloat = (pose == .front ? 120 : 70) + widen
            context.cgContext.fillEllipse(in: CGRect(x: 150 - 30, y: 40, width: 60, height: 60))
            context.fill(CGRect(x: 150 - width / 2, y: 110, width: width, height: 250))
        }
    }
}

/// One pose on the full-screen camera (`photo.view`): ghost, hint, "Front · 1 of 2", shutter.
private struct PhotoCaptureView: View {
    let pose: ProgressStore.Pose
    let ghost: UIImage?
    var onCancel: () -> Void
    var onShot: (UIImage?) -> Void

    @State private var camera: PhotoCamera?
    /// The viewfinder's stand-in when there is no camera: the drawn figure in
    /// UI tests, a library photo in the simulator or without permission.
    @State private var standIn: UIImage?
    @State private var standInBody: PoseCheck.Body?
    @State private var standInChecked = false
    @State private var reference: PoseCheck.Body?
    @State private var pickerItem: PhotosPickerItem?
    @State private var countdown: Int?

    static let selfTimerSeconds = 3

    var body: some View {
        // The controls set the size; the viewfinder and ghost sit behind them. A scaledToFill
        // image in the same ZStack would widen it past the screen and push the close button off.
        VStack(spacing: 12) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Not today")
                // Its own id: the review screen's "Not today" (photo.cancel) sits under the camera.
                .accessibilityIdentifier("photo.camera.cancel")
                Spacer()
                Text("\(pose.title) · \(index) of \(ProgressStore.Pose.allCases.count)")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .accessibilityIdentifier("photo.step")
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            if let hint {
                Text(hint)
                    .font(.title3.bold())
                    .foregroundStyle(Color.caution)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55), in: .capsule)
                    .accessibilityIdentifier("photo.hint")
            }
            Spacer()
            if let countdown {
                Text("\(countdown)")
                    .font(.coachNumber(120))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                    .accessibilityIdentifier("photo.countdown")
            }
            Spacer()
            shutter
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.black
                viewfinder
                if let ghost {
                    // The first photo of this pose, faint, to line up against.
                    Image(uiImage: ghost)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(x: camera == nil ? 1 : -1, y: 1) // match the mirrored preview
                        .opacity(0.3)
                        .allowsHitTesting(false)
                        .accessibilityLabel("Outline of your first \(pose.rawValue) photo")
                        .accessibilityIdentifier("photo.ghost")
                }
            }
            .ignoresSafeArea()
        }
        .accessibilityElement(children: .contain) // keep the children's own ids
        .accessibilityIdentifier("photo.view")
        .sensoryFeedback(trigger: countdown) { _, new in new == nil ? nil : .impact(weight: .light) }
        .task(id: pose) { await prepare() }
        .onDisappear { camera?.stop() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    setStandIn(image)
                }
                pickerItem = nil
            }
        }
    }

    private var index: Int { (ProgressStore.Pose.allCases.firstIndex(of: pose) ?? 0) + 1 }

    @ViewBuilder
    private var viewfinder: some View {
        if let camera {
            CameraPreview(session: camera.session) // the front camera's preview is a mirror
        } else if let standIn {
            Image(uiImage: standIn).resizable().scaledToFill()
        } else if !LaunchOptions.current.isUITest {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose a photo", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .padding()
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .accessibilityIdentifier("photo.library")
        }
    }

    /// One hint, or nothing when the pose is right (or not checked yet).
    private var hint: String? {
        let check = pose == .front ? PoseCheck.Pose.front : .side
        if let camera {
            guard camera.checks > 0 else { return nil }
            return PoseCheck.hint(camera.body, pose: check, reference: reference)
        }
        guard standInChecked else { return nil }
        return PoseCheck.hint(standInBody, pose: check, reference: reference)
    }

    private var shutter: some View {
        Button {
            Task { await shoot() }
        } label: {
            ZStack {
                Circle().fill(.white).frame(width: 72, height: 72)
                Circle().strokeBorder(.white, lineWidth: 4).frame(width: 86, height: 86)
            }
            .frame(minWidth: 88, minHeight: 88)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(countdown != nil || (camera == nil && standIn == nil))
        .accessibilityLabel("Take \(pose.rawValue) photo in \(Self.selfTimerSeconds) seconds")
        .accessibilityIdentifier("photo.take.\(pose.rawValue)")
    }

    private func prepare() async {
        reference = ghost.flatMap { BodyPoseReader.body(in: $0) }
        if LaunchOptions.current.isUITest {
            // No camera or library in UI tests: a drawn stand-in, never a real photo.
            setStandIn(PhotoDayView.testImage(pose))
        } else if PhotoCamera.isAvailable, await PhotoCamera.requestAccess() {
            let camera = camera ?? PhotoCamera()
            camera.start()
            self.camera = camera
        } else {
            standIn = nil
            standInChecked = false
        }
    }

    private func setStandIn(_ image: UIImage) {
        standIn = image
        standInBody = BodyPoseReader.body(in: image)
        standInChecked = true
    }

    /// The 3 s self-timer with a tick each second, then the still.
    private func shoot() async {
        for second in stride(from: Self.selfTimerSeconds, through: 1, by: -1) {
            countdown = second
            AudioServicesPlaySystemSound(1104) // the keyboard tick
            try? await Task.sleep(for: .seconds(1))
        }
        countdown = nil
        var image = standIn
        if let camera {
            image = await camera.capture()
            camera.stop()
        }
        onShot(image)
    }
}
