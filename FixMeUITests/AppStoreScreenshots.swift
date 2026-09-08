import XCTest

/// Captures App Store screenshots by driving the real app.
///
/// An earlier version rendered the screens with `ImageRenderer` from a unit test, which
/// was faster and gave exact dimensions — but every screen came out as SwiftUI's grey
/// "cannot render" placeholder. `NavigationStack` and `@Query` need a real UI host, so
/// there is no headless shortcut here: the app has to actually run.
///
/// Run on a 6.9" device, which is the only iPhone size App Store Connect still demands.
/// `XCUIScreen.main.screenshot()` captures at native resolution, so an iPhone 16 Pro Max
/// gives exactly the 1320x2868 Apple wants:
///
///     xcodebuild -project FixMe.xcodeproj -scheme FixMeScreenshots \
///       -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
///
/// PNGs land in /private/tmp/fixme-screenshots — the simulator writes straight to the
/// host filesystem there.
final class AppStoreScreenshots: XCTestCase {

    private static let outputDirectory = URL(
        fileURLWithPath: ProcessInfo.processInfo.environment["FIXME_SCREENSHOT_DIR"]
            ?? "/private/tmp/fixme-screenshots"
    )

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(
            at: Self.outputDirectory, withIntermediateDirectories: true
        )
        app = XCUIApplication()
        // Seeds a populated day-17 journey and skips onboarding, so the shots show a real
        // run rather than an empty first launch.
        app.launchArguments = ["-FixMeSeedDemo"]
        app.launch()
    }

    /// Saves a full-screen capture, and fails if it is blank.
    ///
    /// The previous approach passed its own size assertion while producing six identical
    /// placeholder images, so "it wrote a file of the right dimensions" is explicitly not
    /// enough to call this working.
    private func snap(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let data = screenshot.pngRepresentation
        let url = Self.outputDirectory.appendingPathComponent("\(name).png")
        try data.write(to: url)

        let image = screenshot.image
        let pixels = CGSize(width: image.size.width * image.scale,
                            height: image.size.height * image.scale)
        print("SHOT \(name): \(Int(pixels.width))x\(Int(pixels.height)) \(data.count) bytes -> \(url.path)")

        // A flat or near-flat image compresses to almost nothing; a real screen doesn't.
        XCTAssertGreaterThan(data.count, 40_000, "\(name) looks blank — \(data.count) bytes")
        XCTAssertEqual(pixels, CGSize(width: 1320, height: 2868),
                       "\(name) is the wrong size — run on an iPhone 16 Pro Max")
    }

    private func tapTab(_ label: String) {
        let tab = app.tabBars.buttons[label]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
            // Let the tab settle before capturing, or the shot catches a transition.
            _ = app.wait(for: .runningForeground, timeout: 1)
        } else {
            XCTFail("no \(label) tab — the tab bar labels may have changed")
        }
    }

    func testCaptureAppStoreScreenshots() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "app never came up")
        // Onboarding is skipped by the seed flag; if it ever isn't, this is where it shows.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20),
                      "no tab bar — onboarding may not have been skipped")

        try snap("01-today")

        for (index, tab) in ["Journey", "Explore", "Social", "Profile"].enumerated() {
            tapTab(tab)
            try snap(String(format: "%02d-%@", index + 2, tab.lowercased()))
        }
    }
}
