import CoachCore
import Foundation
import UIKit

/// Progress photos (board M4-03), kept on the
/// phone only. Photos are JPEGs in Application Support, which the owner's
/// own iCloud device backup includes; nothing here is ever sent anywhere.
@MainActor
final class ProgressStore {
    static let shared = ProgressStore()

    enum Pose: String, CaseIterable, Identifiable {
        case front, side
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    struct PhotoSet: Identifiable, Equatable {
        let day: String
        let date: Date
        var id: String { day }
    }

    private let folder: URL

    private init() {
        let options = LaunchOptions.current
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if options.isUITest {
            // UI tests: a clean folder every launch.
            folder = base.appendingPathComponent("uitest-progress-photos", isDirectory: true)
            try? FileManager.default.removeItem(at: folder)
        } else {
            folder = base.appendingPathComponent("ProgressPhotos", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    // MARK: Photos

    /// Saves one pose for `date`'s set, replacing any earlier one that day.
    func save(_ image: UIImage, pose: Pose, on date: Date, calendar: Calendar) throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw StoreError.encoding }
        try data.write(to: url(day: PhotoSchedule.dayKey(date, calendar: calendar), pose: pose),
                       options: [.atomic, .completeFileProtection])
    }

    func image(day: String, pose: Pose) -> UIImage? {
        UIImage(contentsOfFile: url(day: day, pose: pose).path)
    }

    /// Every day with at least one photo, oldest first.
    func sets(calendar: Calendar) -> [PhotoSet] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let days = Set(names.compactMap { name -> String? in
            guard name.hasSuffix(".jpg"), let dash = name.lastIndex(of: "-") else { return nil }
            return String(name[..<dash])
        })
        return days.sorted().compactMap { day in
            Self.date(day, calendar: calendar).map { PhotoSet(day: day, date: $0) }
        }
    }

    private func url(day: String, pose: Pose) -> URL {
        folder.appendingPathComponent("\(day)-\(pose.rawValue).jpg")
    }

    private static func date(_ day: String, calendar: Calendar) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    nonisolated enum StoreError: LocalizedError {
        case encoding
        var errorDescription: String? { "The photo couldn't be saved." }
    }
}
