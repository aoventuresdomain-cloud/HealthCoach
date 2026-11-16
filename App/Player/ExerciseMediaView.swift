import CoachCore
import ImageIO
import SwiftUI
import UIKit

/// The exercise's own GIF, from `Content/exercises/media/<mediaId>.gif` in the
/// app bundle (fetched at build time; never at runtime, decision in
/// docs/spikes/s4-gifs.md). Falls back to a plain symbol when the build had no
/// GIFs, so a local build still runs.
struct ExerciseMediaView: View {
    let exercise: Exercise?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let url = Self.url(for: exercise), let image = AnimatedGIF.image(at: url) {
                AnimatedImageView(image: image)
                    .accessibilityLabel("\(exercise?.name ?? "Exercise") demonstration")
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 72))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("No demonstration in this build")
            }
            if let angle = exercise?.media?.angle {
                Text("\(angle.rawValue.capitalized) · GIF")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: .capsule)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityIdentifier("player.media")
    }

    static func url(for exercise: Exercise?) -> URL? {
        guard let id = exercise?.media?.mediaId,
              let root = Bundle.main.url(forResource: "Content", withExtension: nil) else { return nil }
        let url = root.appendingPathComponent("exercises/media/\(id).gif")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

private struct AnimatedImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        if view.image !== image { view.image = image }
    }
}

enum AnimatedGIF {
    nonisolated(unsafe) private static let cache = NSCache<NSURL, UIImage>()

    /// Decodes every frame with its delay; nil if the file isn't a readable GIF.
    static func image(at url: URL) -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        var frames: [UIImage] = []
        var duration = 0.0
        for index in 0..<count {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: frame))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            duration += delay < 0.02 ? 0.1 : delay
        }
        guard !frames.isEmpty else { return nil }
        let image = frames.count == 1 ? frames[0] : UIImage.animatedImage(with: frames, duration: duration)
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}
