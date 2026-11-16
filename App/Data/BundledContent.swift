import CoachCore
import Foundation

/// The `Content/` folder, copied into the app as a folder reference so its
/// `exercises/` and `programmes/` structure survives (board M1-01).
enum BundledContent {
    enum LoadError: Error { case missingFolder }

    static func load(bundle: Bundle = .main) throws -> ContentLibrary {
        guard let root = bundle.url(forResource: "Content", withExtension: nil) else {
            throw LoadError.missingFolder
        }
        return try ContentLibrary.load(from: root)
    }
}
