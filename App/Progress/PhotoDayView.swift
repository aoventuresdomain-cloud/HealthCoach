import CoachCore
import PhotosUI
import SwiftUI
import UIKit

/// Photo day (board M4-03): front and side. The camera on a phone; the photo
/// library in the simulator. Camera permission is asked here, on the first
/// photo day. The ghost outline is deferred (re-plan, 17 Nov).
struct PhotoDayView: View {
    let date: Date
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @State private var images: [ProgressStore.Pose: UIImage] = [:]
    @State private var shooting: ProgressStore.Pose?
    @State private var picking: ProgressStore.Pose?
    @State private var pickerItem: PhotosPickerItem?
    @State private var error: String?

    private var store: ProgressStore { .shared }
    private static let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Same spot, same light, phone at chest height as last time.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        ForEach(ProgressStore.Pose.allCases) { pose in
                            slot(pose)
                        }
                    }
                    if let error {
                        Text(error).foregroundStyle(.orange).accessibilityIdentifier("photo.error")
                    }
                }
                .padding(16)
            }
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
            .fullScreenCover(item: $shooting) { pose in
                CameraView { image in
                    if let image { images[pose] = image }
                    shooting = nil
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
                          selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { _, item in
                guard let item, let pose = picking else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        images[pose] = image
                    }
                    pickerItem = nil
                    picking = nil
                }
            }
        }
    }

    private func slot(_ pose: ProgressStore.Pose) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground))
                if let image = images[pose] {
                    Image(uiImage: image).resizable().scaledToFill()
                }
                if images[pose] == nil {
                    Image(systemName: pose == .front ? "figure.stand" : "figure.walk")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 220)
            .clipShape(.rect(cornerRadius: 14))
            Button(images[pose] == nil ? "Take \(pose.rawValue)" : "Retake") { take(pose) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("photo.take.\(pose.rawValue)")
        }
        .frame(maxWidth: .infinity)
    }

    private func take(_ pose: ProgressStore.Pose) {
        if LaunchOptions.current.isUITest {
            // No camera or library in UI tests: a drawn stand-in, never a real photo.
            images[pose] = Self.testImage(pose)
        } else if Self.hasCamera {
            shooting = pose
        } else {
            picking = pose
        }
    }

    private func save() {
        do {
            for (pose, image) in images {
                try store.save(image, pose: pose, on: date, calendar: calendar)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    static func testImage(_ pose: ProgressStore.Pose) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            UIColor.systemGray.setFill()
            let width: CGFloat = pose == .front ? 120 : 70
            context.cgContext.fillEllipse(in: CGRect(x: 150 - 30, y: 40, width: 60, height: 60))
            context.fill(CGRect(x: 150 - width / 2, y: 110, width: width, height: 250))
        }
    }
}

/// The system camera.
private struct CameraView: UIViewControllerRepresentable {
    var onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
