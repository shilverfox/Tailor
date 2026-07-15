import XCTest

final class TailorOnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testWelcomeAndPrivacyFlowRendersAtPhoneSize() {
        launch()
        XCTAssertTrue(app.staticTexts["Keep a life close."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Create a life archive"].exists)
        app.buttons["Create a life archive"].tap()
        XCTAssertTrue(app.staticTexts["Your photos stay yours."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Allow photo access"].exists)
    }

    func testWelcomeContainsPhotoPrivacyExplanation() {
        launch()
        XCTAssertTrue(app.buttons["How we protect your photos"].waitForExistence(timeout: 5))
    }

    func testManualPhotoSelectionContinuesWhenFullLibraryAccessIsNotGranted() {
        launch()
        app.buttons["Create a life archive"].tap()
        XCTAssertTrue(app.buttons["Choose photos manually instead"].waitForExistence(timeout: 3))

        app.buttons["Choose photos manually instead"].tap()

        XCTAssertTrue(app.staticTexts["Tell us about them."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Choose reference photos"].exists)
    }

    func testDemoRoutes01Through04RenderAndCaptureEvidence() {
        renderAndCapture([
            ("welcome", "Keep a life close."),
            ("privacy", "Your photos stay yours."),
            ("profile", "Tell us about them."),
            ("references", "Help us recognize them.")
        ])
    }

    func testDemoRoutes05Through08RenderAndCaptureEvidence() {
        renderAndCapture([
            ("scan", "Looking through the moments."),
            ("confirm", "We found 3 moments."),
            ("timeline", "Milo’s life, in moments."),
            ("chapter", "Edit this chapter.")
        ])
    }

    func testDemoRoutes09Through12RenderAndCaptureEvidence() {
        renderAndCapture([
            ("preview", "A book to keep."),
            ("purchase", "Keep every page."),
            ("export", "Your archive is ready."),
            ("archive", "Your\narchives.")
        ])
    }

    private func renderAndCapture(_ routes: [(name: String, title: String)]) {
        for route in routes {
            XCTContext.runActivity(named: "Render \(route.name)") { _ in
                launch(demoRoute: route.name)
                XCTAssertTrue(app.staticTexts[route.title].waitForExistence(timeout: 5), "Expected \(route.name) screen")
                attachScreenshot(named: "Tailor-\(route.name)")
            }
        }
    }

    private func launch(demoRoute: String? = nil) {
        if app.state != .notRunning { app.terminate() }
        app.launchArguments = ["-uiTesting"]
        if let demoRoute { app.launchArguments += ["-uiDemoRoute", demoRoute] }
        app.launch()
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
