import CryptoKit
import XCTest

/// Ease budget §5: the app's icon is not the M0-02 placeholder (white
/// dumbbell on teal). Reads the asset from the repository checkout the test
/// was built from; fails while AppIcon.png is still the placeholder.
final class AppIconCheckTests: XCTestCase {
    static let placeholderSHA256 = "7866d597c0ecaa1839812b114310dae0ad3c97fa316e9501c93baa675da4b603"

    func testAppIconIsNotThePlaceholder() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        // Ease budget §5 builds the finished icon in Icon Composer: an AppIcon.icon replaces the PNG.
        if FileManager.default.fileExists(atPath: repo.appendingPathComponent("App/AppIcon.icon").path) { return }
        let icon = repo.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
        let data = try XCTUnwrap(try? Data(contentsOf: icon), "no AppIcon.icon and no AppIcon.png at \(icon.path)")
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertNotEqual(hash, Self.placeholderSHA256, "AppIcon.png is still the M0-02 placeholder (ease budget §5)")
    }
}
