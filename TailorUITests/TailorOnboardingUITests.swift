import XCTest
import UIKit

final class TailorOnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testWelcomeAndPrivacyFlowRendersAtPhoneSize() {
        launch()
        XCTAssertTrue(app.staticTexts["Keep a life close."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Create a memory book"].exists)
        app.buttons["Create a memory book"].tap()
        XCTAssertTrue(app.staticTexts["Your photos stay yours."].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.buttons["Allow photo access"].exists
                || app.buttons["Continue with selected photos"].exists
                || app.buttons["Import photos manually"].exists
        )
    }

    func testWelcomeContainsPhotoPrivacyExplanation() {
        launch()
        XCTAssertTrue(app.buttons["How we protect your photos"].waitForExistence(timeout: 5))
    }

    func testManualPhotoSelectionContinuesWhenFullLibraryAccessIsNotGranted() {
        launch(demoRoute: "privacy", demoState: "denied")
        XCTAssertTrue(app.buttons["Import photos manually"].waitForExistence(timeout: 3))
        app.buttons["Import photos manually"].tap()

        XCTAssertTrue(app.staticTexts["Tell us about them."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Choose reference photos"].exists)
    }

    func testDeniedManualImportRequiresThreePhotosBeforeReview() {
        // The current denied fixture enters the actual manual 04 surface;
        // it does not rely on obsolete privacy-button copy or Photos dialogs.
        launch(demoRoute: "references", demoState: "manual")

        XCTAssertTrue(app.staticTexts["Choose the moments you want to review."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0 / 500 selected · 3 more needed"].exists)
        let review = app.buttons["Review selected photos"]
        XCTAssertTrue(review.exists)
        XCTAssertFalse(review.isEnabled, "Two or fewer manual photos must not enter review or scanning")
        XCTAssertFalse(app.staticTexts["Looking through the moments."].exists, "Manual import must never invoke the PhotoKit scanner")
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
            ("confirm", "We found 112 moments."),
            ("timeline", "Milo’s life, in moments."),
            ("chapter", "Edit this chapter.")
        ])
    }

    func testScanDemoStatesExposeRunningPausedAndCompleteActions() {
        launch(demoRoute: "scan", demoState: "running")
        XCTAssertTrue(app.buttons["Pause scan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1,426 photos checked"].exists)

        launch(demoRoute: "scan", demoState: "paused")
        XCTAssertTrue(app.staticTexts["Scan paused at 42%. Your progress is saved."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Resume scan"].exists)

        launch(demoRoute: "scan", demoState: "complete")
        XCTAssertTrue(app.staticTexts["Matches ready for your review."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Review photos"].exists)
    }

    func testScanResilienceStatesExposeRecoveryActions() {
        launch(demoRoute: "scan", demoState: "interrupted")
        XCTAssertTrue(app.staticTexts["Ready to continue where you left off. Your progress is saved."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Resume scan"].exists)

        launch(demoRoute: "scan", demoState: "lowBattery")
        XCTAssertTrue(app.buttons["Pause now"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Continue later"].exists)

        launch(demoRoute: "scan", demoState: "failed")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Review matches so far"].exists)
    }

    func testReviewMakesPendingChoicesDiscoverableBeforeTimeline() {
        launch(demoRoute: "confirm")

        XCTAssertTrue(app.buttons["NEEDS REVIEW · 110"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Review 110 photos waiting for your choice"].exists)

        app.buttons["NEEDS REVIEW · 110"].tap()
        let candidate = app.buttons["Photo confidence 62 percent. Tap to decide whether this is Milo."]
        XCTAssertTrue(candidate.waitForExistence(timeout: 3))
        candidate.tap()
        XCTAssertTrue(app.buttons["This is Milo"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Not Milo"].exists)

        app.buttons["This is Milo"].firstMatch.tap()

        // Relaunch the deterministic demo route to retain an undecided candidate
        // and verify the timeline guard independently of the decision sheet.
        launch(demoRoute: "confirm", demoState: "review-pending-gate")
        XCTAssertTrue(app.buttons["Continue confirming photos"].waitForExistence(timeout: 3))
    }

    func testReviewCanQuicklyApproveSelectedCandidatesWithoutOpeningEachDecisionSheet() {
        launch(demoRoute: "confirm", demoState: "review-batch")
        app.buttons["NEEDS REVIEW · 3"].tap()

        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 3))
        app.buttons["Select"].tap()
        XCTAssertTrue(app.buttons["Select all shown"].waitForExistence(timeout: 3))
        app.buttons["Select all shown"].tap()
        XCTAssertTrue(app.buttons["Add 3 to archive"].waitForExistence(timeout: 3))
        app.buttons["Add 3 to archive"].tap()

        XCTAssertTrue(app.buttons["HIGH · 4"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["NEEDS REVIEW · 0"].exists)
    }

    func testMainArchiveFlowReachesACompletedPDFAfterReviewAndUnlock() {
        // This is the release-shape happy path, using only deterministic local
        // services: post-review confirmed photos, timeline creation,
        // editor/reader navigation, one-time unlock, then a completed local
        // PDF. Batch approval has its own dedicated regression above.
        launch(demoRoute: "confirm", demoState: "review-ready")
        let createTimeline = app.buttons["review.createTimeline"]
        XCTAssertTrue(createTimeline.waitForExistence(timeout: 3))
        createTimeline.tap()

        XCTAssertTrue(app.buttons["Continue to story"].waitForExistence(timeout: 4))
        app.buttons["Continue to story"].tap()
        XCTAssertTrue(app.buttons["Choose book style"].waitForExistence(timeout: 3))
        app.buttons["Choose book style"].tap()
        XCTAssertTrue(app.staticTexts["Choose how the story feels."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Create first draft"].exists)
        app.buttons["Create first draft"].tap()

        XCTAssertTrue(app.staticTexts["A book to keep."].waitForExistence(timeout: 4))
        app.buttons["Unlock complete book"].tap()
        XCTAssertTrue(app.buttons["Continue to final preview"].waitForExistence(timeout: 4))
        app.buttons["Continue to final preview"].tap()
        XCTAssertTrue(app.staticTexts["Create the complete book."].waitForExistence(timeout: 3))
        app.buttons["Unlock complete book"].tap()
        XCTAssertTrue(app.staticTexts["A book to keep."].waitForExistence(timeout: 4))
        app.buttons["Generate full PDF"].tap()
        XCTAssertTrue(app.staticTexts["Ready when you are."].waitForExistence(timeout: 3))
        app.buttons["Generate PDF"].tap()
        XCTAssertTrue(app.staticTexts["Your PDF is ready."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Save and share PDF"].exists)
    }

    func testLongReviewGridCanReturnToEarlierPhotosAfterReachingItsEnd() {
        launch(demoRoute: "confirm")
        app.buttons["NEEDS REVIEW · 110"].tap()

        let firstCandidate = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "review.photo.")).firstMatch
        XCTAssertTrue(firstCandidate.waitForExistence(timeout: 3))

        // Exercise the actual failure mode reported on device: reach the bottom
        // action, then return to the first candidate. A header's existence is not
        // sufficient because XCTest keeps off-screen elements in the hierarchy.
        for _ in 0..<16 { app.swipeUp() }
        XCTAssertTrue(app.buttons["review.createTimeline"].isHittable)

        for _ in 0..<16 { app.swipeDown() }

        XCTAssertTrue(firstCandidate.isHittable, "The review grid must return to earlier photos after reaching its end.")
    }

    func testReviewViewerAndPendingGateAreDiscoverableWithDedicatedFixtures() {
        launch(demoRoute: "confirm", demoState: "review-viewer")
        app.buttons["NEEDS REVIEW · 1"].tap()
        let candidate = app.buttons["Photo confidence 62 percent. Tap to decide whether this is Milo."]
        XCTAssertTrue(candidate.waitForExistence(timeout: 3))
        candidate.tap()
        XCTAssertTrue(app.buttons["This is Milo"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Set aside as sensitive"].exists)

        launch(demoRoute: "confirm", demoState: "review-pending-gate")
        XCTAssertTrue(app.buttons["Continue confirming photos"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Create timeline with 1 selected photo"].exists)
    }

    func testReviewSensitiveFixtureKeepsProtectiveGroupDiscoverable() {
        launch(demoRoute: "confirm", demoState: "review-sensitive")
        XCTAssertTrue(app.buttons["SENSITIVE · 1"].waitForExistence(timeout: 3))
        app.buttons["SENSITIVE · 1"].tap()
        XCTAssertTrue(app.staticTexts["Sensitive photos stay out of your archive"].waitForExistence(timeout: 3))
    }

    func testV22AdjudicationFixturesExposeDeniedStaleRecheckAndSinglePeriodPaths() {
        // S01/S03/S04/S06/S11/S12: each is independently reachable without
        // Photos, StoreKit, or a stale persisted archive.
        launch(demoRoute: "privacy", demoState: "denied")
        XCTAssertTrue(app.buttons["Import photos manually"].waitForExistence(timeout: 3))

        launch(demoRoute: "confirm", demoState: "review-stale")
        XCTAssertTrue(app.buttons["STALE · 1"].waitForExistence(timeout: 3))

        launch(demoRoute: "rechecking")
        XCTAssertTrue(app.otherElements["Checking latest edits"].waitForExistence(timeout: 3))

        launch(demoRoute: "preview", demoState: "single-period-six-pages")
        XCTAssertTrue(app.staticTexts["A book to keep."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["PAGE 1 OF 6"].exists)
    }

    func testStoryPlanMergeConfirmsImpactAndShowsResultSummary() {
        launch(demoRoute: "timeline")
        let merge = app.buttons["Merge chapter 1 with next"]
        XCTAssertTrue(merge.waitForExistence(timeout: 3))
        merge.tap()

        XCTAssertTrue(app.buttons["Merge as one chapter"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@",
            "Photo order is preserved; affected unlocked pages will be marked for review and locked pages stay unchanged."
        )).firstMatch.exists)
        app.buttons["Merge as one chapter"].tap()

        let summary = app.descendants(matching: .any)["Story plan impact summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@",
            "without losing or duplicating photos"
        )).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Pages need review"].exists)
    }

    func testStoryPlanSplitConfirmsImpactAndShowsResultSummary() {
        launch(demoRoute: "timeline")
        let split = app.buttons["Split chapter 1"]
        XCTAssertTrue(split.waitForExistence(timeout: 3))
        split.tap()

        let boundary = app.buttons["After photo 1 · 1 + 2"]
        XCTAssertTrue(boundary.waitForExistence(timeout: 3))
        boundary.tap()

        let confirm = app.buttons["Split into two chapters"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@",
            "Affected unlocked pages will need layout review; locked pages stay unchanged."
        )).firstMatch.exists)
        confirm.tap()

        let summary = app.descendants(matching: .any)["Story plan impact summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@",
            "exact photo order"
        )).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Pages need review"].exists)
    }

    func testCaptureWarmPaperReaderPagesForLetterAndA4Evidence() throws {
        XCUIDevice.shared.orientation = .portrait
        for paper in ["letter", "a4"] {
            if app.state != .notRunning { app.terminate() }
            app.launchArguments = [
                "-uiTesting",
                "-uiDemoRoute", "preview",
                "-uiDemoState", "visual-fixture",
                "-uiDemoStyle", "warmPaper",
                "-uiDemoPaper", paper
            ]
            app.launch()

            let reader = app.otherElements["Reader single page"]
            XCTAssertTrue(reader.waitForExistence(timeout: 5))
            let folder = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appending(path: "tailor-reader-visual-evidence-v1/warmPaper/\(paper)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for page in 1...7 {
                XCTAssertTrue(app.staticTexts["PAGE \(page) OF 7"].waitForExistence(timeout: 4))
                let screenshot = reader.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "reader-warmPaper-\(paper)-page-\(String(format: "%02d", page))"
                attachment.lifetime = .keepAlways
                add(attachment)
                let png = screenshot.pngRepresentation
                try png.write(to: folder.appending(path: String(format: "reader-page-%02d.png", page)), options: .atomic)
                if page < 7 { reader.swipeLeft() }
            }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" }.count, 7)
        }
    }

    func testVisualFixtureAlsoFeedsFinalPreviewAndKeepsNavigationOffPaper() {
        XCUIDevice.shared.orientation = .portrait
        launch(demoRoute: "finalPreview", demoState: "visual-fixture")
        let reader = app.otherElements["Reader single page"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["PAGE 1 OF 7"].waitForExistence(timeout: 3))
        reader.swipeLeft()
        reader.swipeLeft()
        XCTAssertTrue(app.staticTexts["PAGE 3 OF 7"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["Reader contents"].exists, "Reader navigation must not be painted over the Contents paper page")
        XCTAssertTrue(app.buttons["Contents"].exists, "Contents navigation remains available outside the paper")
    }

    func testDemoRoutes09Through12RenderAndCaptureEvidence() {
        renderAndCapture([
            ("editor", "1 of 8"),
            ("preview", "A book to keep."),
            ("purchase", "Create the complete book."),
            ("export", "Your PDF is ready."),
            ("archive", "Your archives.")
        ])
    }

    func testPreviewSupportsStylesPageSizeAndPurchasedExportPath() {
        launch(demoRoute: "preview")
        XCTAssertTrue(app.staticTexts["PAGE 1 OF 8"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Customize"].exists)
        XCTAssertTrue(app.buttons["Style"].exists)
        XCTAssertTrue(app.buttons["Paper"].exists)
        app.buttons["Paper"].tap()
        XCTAssertTrue(app.navigationBars["Print size"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["US Letter"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Back to editor"].exists)
        XCTAssertTrue(app.buttons["Unlock complete book"].exists)
        app.buttons["Style"].tap()
        XCTAssertTrue(app.staticTexts["Choose how the story feels."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Warm Paper"].exists)
        XCTAssertTrue(app.staticTexts["Quiet Night"].exists)
        XCTAssertTrue(app.staticTexts["Field Notes"].exists)
        XCTAssertTrue(app.staticTexts["Cinema"].exists)
        XCTAssertTrue(app.staticTexts["Film Album"].exists)

        launch(demoRoute: "preview", demoState: "preview-purchased")
        XCTAssertTrue(app.staticTexts["A book to keep."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share current page"].exists)
        XCTAssertTrue(app.buttons["Generate full PDF"].exists)
    }

    func testReaderContentsSwipeHintAndLandscapeSpreadUseSharedPages() {
        XCUIDevice.shared.orientation = .portrait
        launch(demoRoute: "preview", demoState: "preview-purchased")
        XCTAssertTrue(app.buttons["Contents"].waitForExistence(timeout: 3))
        let reader = app.otherElements["Reader single page"]
        XCTAssertTrue(reader.exists)
        XCTAssertTrue(app.staticTexts["Swipe left or right"].exists)
        reader.swipeLeft()
        XCTAssertTrue(app.staticTexts["PAGE 2 OF 8"].waitForExistence(timeout: 3))
        // TabView owns paging. One swipe must advance exactly one page, never
        // a second page from a competing manual drag recognizer.
        reader.swipeLeft()
        XCTAssertTrue(app.staticTexts["PAGE 3 OF 8"].waitForExistence(timeout: 3))
        reader.swipeRight()
        XCTAssertTrue(app.staticTexts["PAGE 2 OF 8"].waitForExistence(timeout: 3))
        reader.swipeRight()
        XCTAssertTrue(app.staticTexts["PAGE 1 OF 8"].waitForExistence(timeout: 3))

        // Pick the first chapter from the portrait contents. It is page 4 in
        // the deterministic demo book, so the assertion checks a real
        // MemoryBookPage position rather than a spread/tab index.
        app.buttons["Contents"].tap()
        XCTAssertTrue(app.navigationBars["Contents"].waitForExistence(timeout: 3))
        let chapter = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Contents jump ")).firstMatch
        XCTAssertTrue(chapter.waitForExistence(timeout: 3))
        chapter.tap()
        XCTAssertTrue(app.staticTexts["PAGE 4 OF 8"].waitForExistence(timeout: 3))

        // Portrait page 4 becomes the right page of a landscape spread. The
        // reader must preserve page 4, not reuse portrait tab index 3.
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.otherElements["Reader double-page spread"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["PAGE 4 OF 8"].waitForExistence(timeout: 3))

        // The top Contents tool also works from landscape and maps a logical
        // chapter page into the active two-page group.
        app.buttons["Contents"].tap()
        XCTAssertTrue(app.navigationBars["Contents"].waitForExistence(timeout: 3))
        let landscapeChapter = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "Contents jump "))
            .element(boundBy: 1)
        XCTAssertTrue(landscapeChapter.waitForExistence(timeout: 3))
        landscapeChapter.tap()
        XCTAssertTrue(app.staticTexts["PAGE 6 OF 8"].waitForExistence(timeout: 3))

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.otherElements["Reader single page"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["PAGE 6 OF 8"].waitForExistence(timeout: 3))
    }

    func testReaderLandscapeRightOddLastPageAndLifecycleKeepLogicalPage() {
        XCUIDevice.shared.orientation = .portrait
        launch(demoRoute: "preview", demoState: "preview-odd-purchased")
        let reader = app.otherElements["Reader single page"]
        XCTAssertTrue(reader.waitForExistence(timeout: 3))

        // Reach the ninth (odd final) logical page using the real pager.
        for expectedPage in 2...9 {
            reader.swipeLeft()
            XCTAssertTrue(app.staticTexts["PAGE \(expectedPage) OF 9"].waitForExistence(timeout: 3))
        }
        // Boundary stays put rather than producing an invalid TabView index.
        reader.swipeLeft()
        XCTAssertTrue(app.staticTexts["PAGE 9 OF 9"].exists)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.otherElements["Reader landscape single page"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["PAGE 9 OF 9"].exists)

        // Rapid side changes must keep page identity, even while the reader
        // rebuilds portrait groups into landscape spreads.
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(app.otherElements["Reader landscape single page"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["PAGE 9 OF 9"].exists)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.otherElements["Reader single page"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["PAGE 9 OF 9"].exists)

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["PAGE 9 OF 9"].waitForExistence(timeout: 4))
    }

    func testFreeReaderContentsExplainsWhenChapterIsOutsideSample() {
        XCUIDevice.shared.orientation = .portrait
        launch(demoRoute: "preview", demoState: "preview-sample-truncated")
        XCTAssertTrue(app.staticTexts["PAGE 1 OF 8"].waitForExistence(timeout: 3))

        app.buttons["Contents"].tap()
        XCTAssertTrue(app.navigationBars["Contents"].waitForExistence(timeout: 3))
        let chapters = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Contents jump "))
        XCTAssertGreaterThanOrEqual(chapters.count, 3)
        chapters.element(boundBy: 2).tap()

        XCTAssertTrue(app.staticTexts["This chapter is not in the free sample."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["A long summer is available after you unlock the complete book."].exists)
        XCTAssertTrue(app.buttons["Keep reading"].exists)
        app.buttons["Keep reading"].tap()
        XCTAssertTrue(app.navigationBars["Contents"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["PAGE 1 OF 8"].waitForExistence(timeout: 3))
    }

    func testPurchaseFailurePreservesTheUnlockScreenAndRestorePath() {
        launch(demoRoute: "purchase", demoState: "purchase-failed")
        XCTAssertTrue(app.descendants(matching: .any)["Localized unlock price"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your purchase could not be completed. Your book is still here."].exists)
        XCTAssertTrue(app.buttons["Unlock complete book"].exists)
        XCTAssertTrue(app.buttons["Restore purchase"].exists)
    }

    func testPurchaseCancelledAndPendingKeepTheArchiveEditable() {
        launch(demoRoute: "purchase", demoState: "purchase-cancelled")
        XCTAssertTrue(app.buttons["Unlock complete book"].waitForExistence(timeout: 3))
        app.buttons["Unlock complete book"].tap()
        XCTAssertTrue(app.staticTexts["Purchase cancelled. Your book and edits are still here."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Unlock complete book"].exists)
        XCTAssertTrue(app.buttons["Restore purchase"].exists)

        launch(demoRoute: "purchase", demoState: "purchase-pending")
        XCTAssertTrue(app.buttons["Unlock complete book"].waitForExistence(timeout: 3))
        app.buttons["Unlock complete book"].tap()
        XCTAssertTrue(app.staticTexts["Your purchase is pending approval. Your book and edits are still here."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Unlock complete book"].exists)
    }

    func testPurchasePriceUnavailableCanRetryAndEnableUnlock() {
        launch(demoRoute: "purchase", demoState: "purchase-price-retry")
        XCTAssertTrue(app.staticTexts["Price unavailable"].waitForExistence(timeout: 3))
        let unlock = app.buttons["Unlock complete book"]
        XCTAssertTrue(unlock.exists)
        XCTAssertFalse(unlock.isEnabled)

        let retry = app.buttons["Retry unlock price"]
        XCTAssertTrue(retry.exists && retry.isHittable)
        retry.tap()

        XCTAssertTrue(app.descendants(matching: .any)["Localized unlock price"].waitForExistence(timeout: 3))
        XCTAssertTrue(unlock.isEnabled)
        XCTAssertFalse(app.staticTexts["Price unavailable"].exists)
    }

    func testBookCheckSuggestionCanBeIgnoredAndUndone() {
        launch(demoRoute: "bookCheck", demoState: "book-check-ignore")
        let ignore = app.buttons["Keep and ignore suggestion"].firstMatch
        XCTAssertTrue(ignore.waitForExistence(timeout: 4))
        ignore.tap()

        let confirm = app.buttons["Confirm ignore Book Check suggestion"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Ignored by you · risk remains recorded"].waitForExistence(timeout: 3))
        let undo = app.buttons["Undo ignore"].firstMatch
        XCTAssertTrue(undo.exists && undo.isHittable)
        undo.tap()

        XCTAssertTrue(app.buttons["Keep and ignore suggestion"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Ignored by you · risk remains recorded"].exists)
    }

    func testFinalPreviewEditWithBlockingResultReturnsThroughBookCheck() {
        launch(demoRoute: "finalPreview")
        let reader = app.otherElements["Reader single page"]
        XCTAssertTrue(reader.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["PAGE 1 OF 8"].waitForExistence(timeout: 3))
        reader.swipeLeft()
        reader.swipeLeft()
        XCTAssertTrue(app.staticTexts["PAGE 3 OF 8"].waitForExistence(timeout: 3))

        app.buttons["Edit book"].tap()
        XCTAssertTrue(app.staticTexts["3 of 8"].waitForExistence(timeout: 4))
        app.buttons["Back"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["A few pages need attention."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Review blocking issues"].exists)
        XCTAssertFalse(reader.exists, "A newly blocked revision must not briefly reveal the stale Final Preview")
    }

    func testExportCompletionAndFailureKeepLocalActionsVisible() {
        launch(demoRoute: "export")
        XCTAssertTrue(app.staticTexts["Your PDF is ready."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Save and share PDF"].exists)
        XCTAssertTrue(app.buttons["Open archive"].exists)
        XCTAssertTrue(app.otherElements["Export book cover"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.otherElements["Export book cover"].label, "Exported book cover for Milo")
        XCTAssertEqual(app.otherElements["Export details"].label, "8 pages, US Letter, Milo-Life-Archive.pdf")
        XCTAssertTrue(app.buttons["Return to timeline"].exists)

        launch(demoRoute: "export", demoState: "export-failed")
        XCTAssertTrue(app.staticTexts["We couldn’t save the PDF. Your book is still here."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Try again"].exists)
        XCTAssertTrue(app.buttons["Return to timeline"].exists)
    }

    func testExportRenderingStatePreventsDuplicateActions() {
        launch(demoRoute: "export", demoState: "exporting")
        XCTAssertTrue(app.staticTexts["Making your book."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Rendering page 1 of 8 on this iPhone. Your edits are safely saved."].exists)
        XCTAssertTrue(app.buttons["Rendering PDF…"].exists)
        XCTAssertTrue(app.buttons["Cancel rendering"].exists)
        XCTAssertFalse(app.buttons["Return to timeline"].exists)
    }

    func testArchiveDeleteConfirmationDoesNotTouchSystemPhotos() {
        launch(demoRoute: "archive")
        XCTAssertTrue(app.staticTexts["Milo’s Memory Book"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Open Milo’s Memory Book"].exists)
        XCTAssertTrue(app.staticTexts["Archive metadata"].exists)
        app.buttons["Open Milo’s Memory Book"].tap()
        XCTAssertTrue(app.staticTexts["A book to keep."].waitForExistence(timeout: 3))

        launch(demoRoute: "archive")
        XCTAssertTrue(app.buttons["Rescan for new photos"].exists)
        XCTAssertTrue(app.buttons["Manage photo access"].exists)
        app.buttons["Delete all local Tailor data"].tap()
        XCTAssertTrue(app.staticTexts["Delete all local Tailor data?"].waitForExistence(timeout: 3))
        // The confirmation dialog exposes the long privacy copy as a composed
        // accessibility element on iOS 26, so assert its stable title and
        // destructive/cancel actions instead of requiring one StaticText node.
        XCTAssertTrue(app.staticTexts["Delete all local Tailor data?"].exists)
        XCTAssertTrue(app.buttons["Delete local data"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Create another archive"].waitForExistence(timeout: 3))
    }

    func testPreviewInsufficientFixtureKeepsEditingAndUnlockActionsAvailable() {
        launch(demoRoute: "preview", demoState: "preview-insufficient")
        XCTAssertTrue(app.staticTexts["A book to keep."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Every preview page is watermarked."].exists)
        XCTAssertTrue(app.buttons["Back to editor"].exists)
        XCTAssertTrue(app.buttons["Unlock complete book · $19.99"].exists)
    }

    func testEditorFixtureExposesPagePhotoTextAndStyleTools() {
        launch(demoRoute: "editor")
        XCTAssertTrue(app.staticTexts["1 of 8"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Pages"].exists)
        XCTAssertTrue(app.buttons["Photo"].exists)
        XCTAssertTrue(app.buttons["Text"].exists)
        XCTAssertTrue(app.buttons["Style"].exists)

        app.buttons["Pages"].tap()
        XCTAssertTrue(app.navigationBars["Pages"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["Page 1 canvas thumbnail"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Locked layout page"].exists)
        XCTAssertTrue(app.buttons["Page 1 card"].exists)
        app.buttons["Done"].tap()

        app.buttons["More editor actions"].tap()
        XCTAssertTrue(app.buttons["Auto arrange"].waitForExistence(timeout: 3))
        app.buttons["Auto arrange"].tap()
        XCTAssertTrue(app.buttons["This page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["This chapter"].exists)
        XCTAssertTrue(app.buttons["Entire book"].exists)
    }

    func testMissingPhotoIsVisibleAndCanBeReplacedBeforeExport() {
        launch(demoRoute: "editor", demoState: "missing-photo")
        let replace = app.buttons["Replace photo"]
        XCTAssertTrue(replace.waitForExistence(timeout: 3))
        XCTAssertEqual(replace.value as? String, "Photo unavailable. Replace it before export.")
        replace.tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(identifier: "Replace photo ui-timeline-photo-1").firstMatch.exists)
    }

    func testEditorTextUsesWhitelistedFieldsAndRoleSpecificAdd() {
        launch(demoRoute: "editor")
        app.buttons["Text"].tap()
        XCTAssertTrue(app.navigationBars["Edit text"].waitForExistence(timeout: 3), "Text sheet must be presented")
        attachScreenshot(named: "Tailor-editor-text-sheet-cover")
        print(app.debugDescription)
        let whitelist = app.descendants(matching: .any)["Text whitelist count"]
        XCTAssertTrue(whitelist.exists, "Sheet must expose a whitelist marker")
        XCTAssertTrue((whitelist.value as? String ?? "").contains("coverPetName"), "Actual whitelist: \(whitelist.value ?? "nil")")
        XCTAssertTrue(app.buttons["Text field coverPetName"].waitForExistence(timeout: 3), "Cover role must be exposed with its explicit label")
        XCTAssertFalse(app.descendants(matching: .any)["Add a new text box"].exists)
        attachScreenshot(named: "Tailor-editor-text-cover-whitelist")
        app.buttons["Text draft back"].tap()
        XCTAssertFalse(app.navigationBars["Edit text"].waitForExistence(timeout: 1), "Cover Text sheet must dismiss before changing page")

        XCTAssertTrue(app.buttons["Page 5"].waitForExistence(timeout: 3), "Page 5 thumbnail must exist")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3), "Page 5 must be the active editor page")
        app.buttons["Text"].tap()
        XCTAssertTrue(app.navigationBars["Edit text"].waitForExistence(timeout: 3), "Photo Text sheet must be presented")
        attachScreenshot(named: "Tailor-editor-text-sheet-photo")
        let photoWhitelist = app.descendants(matching: .any)["Text whitelist count"]
        XCTAssertTrue(photoWhitelist.exists, "Photo sheet must expose its whitelist marker")
        XCTAssertTrue((photoWhitelist.value as? String ?? "").contains("photoTitle"), "Actual photo whitelist: \(photoWhitelist.value ?? "nil")")
        XCTAssertTrue(app.buttons["Text field photoTitle"].waitForExistence(timeout: 3), "Photo title role must be tappable")
        let addCaption = app.buttons["Add text field photoCaption"]
        let existingCaption = app.buttons["Text field photoCaption"]
        XCTAssertTrue(addCaption.exists || existingCaption.exists, "Photo page must expose its optional caption role")
        (addCaption.exists ? addCaption : existingCaption).tap()
        XCTAssertTrue(app.textViews["Text draft input"].waitForExistence(timeout: 3), "Caption role must open the text draft input")
        attachScreenshot(named: "Tailor-editor-text-photo-role-add")
    }

    func testEditorTextAddsMissingOptionalCaption() {
        launch(demoRoute: "editor", demoState: "text-missing-caption")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        app.buttons["Text"].tap()
        XCTAssertTrue(app.navigationBars["Edit text"].waitForExistence(timeout: 3))
        let add = app.buttons["Add text field photoCaption"]
        XCTAssertTrue(add.waitForExistence(timeout: 3), "Fixture must omit caption before add")
        attachScreenshot(named: "Tailor-editor-text-caption-add")
        add.tap()
        let input = app.textViews["Text draft input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap(); input.typeText("A quiet afternoon")
        app.buttons["Text draft done"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        app.buttons["Text"].tap()
        XCTAssertTrue(app.buttons["Text field photoCaption"].waitForExistence(timeout: 3))
        app.buttons["Text field photoCaption"].tap()
        XCTAssertTrue(app.textViews["Text draft input"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews["Text draft input"].value as? String == "A quiet afternoon")
        attachScreenshot(named: "Tailor-editor-text-caption-saved")
    }

    func testEditorTypographyPresetAndCustomAlignmentApplyAsOneUndoableChange() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let title = app.descendants(matching: .any)["Text element photoTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        let original = marker(of: title)

        app.buttons["Text"].tap()
        app.buttons["Text field photoTitle"].tap()
        XCTAssertTrue(app.textViews["Text draft input"].waitForExistence(timeout: 3))
        let preset = app.buttons["Text preset Editorial title"]
        for _ in 0..<5 where !preset.exists { app.swipeUp() }
        XCTAssertTrue(preset.waitForExistence(timeout: 3))
        preset.tap()
        let center = app.buttons["Center"].firstMatch
        XCTAssertTrue(center.waitForExistence(timeout: 3))
        center.tap()
        attachScreenshot(named: "Tailor-editor-typography-draft")
        app.buttons["Text draft done"].tap()

        XCTAssertTrue(title.waitForExistence(timeout: 3))
        let applied = marker(of: title)
        XCTAssertNotEqual(applied, original)
        XCTAssertTrue(applied.contains("alignment=center"), "Custom alignment must persist in the shared text element: \(applied)")
        XCTAssertFalse(applied.contains("tracking=0.000"), "Custom tracking must persist in the shared text element: \(applied)")
        attachScreenshot(named: "Tailor-editor-typography-applied")
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(marker(of: title), original, "Typography Done must be one atomic history transaction")
    }

    func testEditorWarnsAboutLowContrastAndOffersCoordinatedRepair() {
        launch(demoRoute: "editor", demoState: "text-low-contrast")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        app.buttons["Text"].tap()
        XCTAssertTrue(app.navigationBars["Edit text"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews["Text draft input"].waitForExistence(timeout: 3), "The page's primary title should open by default")

        let warning = app.descendants(matching: .any)["Text contrast warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 3), "Unreadable custom text must be caught while editing")
        let readability = app.descendants(matching: .any)["Text print readability"]
        XCTAssertTrue(readability.exists)
        XCTAssertTrue((readability.value as? String ?? "").contains("1.0 to 1 contrast"))
        attachScreenshot(named: "Tailor-editor-text-contrast-warning")

        let repair = app.buttons["Use readable text color"]
        XCTAssertTrue(repair.isHittable)
        repair.tap()
        XCTAssertFalse(warning.waitForExistence(timeout: 1), "The recommended ink must resolve the warning immediately")
        attachScreenshot(named: "Tailor-editor-text-contrast-repaired")
    }

    func testEditorTextOverflowShowsAccessibleErrorAndFit() {
        launch(demoRoute: "editor", demoState: "text-fit-success")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        app.buttons["Text"].tap()
        XCTAssertTrue(app.buttons["Text field photoCaption"].waitForExistence(timeout: 3))
        app.buttons["Text field photoCaption"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Text draft error"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.descendants(matching: .any)["Text draft error"].value as? String, "invalid")
        let fit = app.buttons["Fit text"].firstMatch
        XCTAssertTrue(fit.waitForExistence(timeout: 3))
        XCTAssertTrue(fit.isHittable, "Fit must be actionable while overflow is shown")
        attachScreenshot(named: "Tailor-editor-text-overflow-fit-visible")
    }

    func testBookCheckGoOpensTheBlockingTextField() {
        launch(demoRoute: "editor", demoState: "text-book-check-overflow")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        app.buttons["More editor actions"].tap()
        let checkBook = app.buttons["Check book"]
        XCTAssertTrue(checkBook.waitForExistence(timeout: 3))
        checkBook.tap()
        let go = app.buttons["Book check go photoCaption"].firstMatch
        XCTAssertTrue(go.waitForExistence(timeout: 3))
        go.tap()
        XCTAssertTrue(app.navigationBars["Edit text"].waitForExistence(timeout: 3))
        let input = app.textViews["Text draft input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        XCTAssertEqual(input.value as? String, String(repeating: "n", count: 121), "Book Check must open the exact blocking text element, not only its page.")
    }

    func testBookCheckContrastRepairIsVisibleAndOneUndoRestoresTheDesign() {
        launch(demoRoute: "editor", demoState: "text-low-contrast")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let title = app.descendants(matching: .any)["Text element photoTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        let original = marker(of: title)

        app.buttons["More editor actions"].tap()
        XCTAssertTrue(app.buttons["Check book"].waitForExistence(timeout: 3))
        app.buttons["Check book"].tap()
        XCTAssertTrue(app.navigationBars["Book check"].waitForExistence(timeout: 3))
        let fix = app.buttons["Book check fix Improve contrast photoTitle"]
        XCTAssertTrue(fix.waitForExistence(timeout: 3) && fix.isHittable)
        attachScreenshot(named: "Tailor-book-check-guided-contrast-fix")
        fix.tap()
        XCTAssertFalse(fix.waitForExistence(timeout: 1), "A successful repair must remove the now-resolved issue")
        attachScreenshot(named: "Tailor-book-check-guided-contrast-resolved")
        app.buttons["Done"].tap()

        XCTAssertTrue(title.waitForExistence(timeout: 3))
        let repaired = marker(of: title)
        XCTAssertNotEqual(repaired, original)
        XCTAssertTrue(repaired.contains("color=custom"))
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(marker(of: title), original, "Book Check repair must be one atomic history transaction")
    }

    func testBookCheckAlignmentRepairSnapsExactlyAndOneUndoRestoresTheDesign() {
        launch(demoRoute: "editor", demoState: "composition-near-align")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let title = app.descendants(matching: .any)["Text element photoTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        let original = marker(of: title)
        XCTAssertTrue(original.contains("x=0.092"))

        app.buttons["More editor actions"].tap()
        XCTAssertTrue(app.buttons["Check book"].waitForExistence(timeout: 3))
        app.buttons["Check book"].tap()
        let fix = app.buttons["Book check fix Align photoTitle"]
        XCTAssertTrue(fix.waitForExistence(timeout: 3) && fix.isHittable)
        attachScreenshot(named: "Tailor-book-check-guided-alignment-fix")
        fix.tap()
        XCTAssertFalse(fix.waitForExistence(timeout: 1))
        app.buttons["Done"].tap()

        XCTAssertTrue(title.waitForExistence(timeout: 3))
        let aligned = marker(of: title)
        XCTAssertTrue(aligned.contains("x=0.080"), "Book Check should snap to the exact shared guide: \(aligned)")
        XCTAssertNotEqual(aligned, original)
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(marker(of: title), original, "Alignment repair must be one atomic history transaction")
    }

    func testChapterStyleScopePreservesLockedOpenerAndUndoesAtomically() {
        launch(demoRoute: "editor")
        app.buttons["Page 4"].tap()
        XCTAssertTrue(app.staticTexts["4 of 8"].waitForExistence(timeout: 3))
        let paper = app.descendants(matching: .any)["Page paper"].firstMatch
        XCTAssertTrue(paper.waitForExistence(timeout: 3))
        let lockedOpenerPaper = paper.value as? String

        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let originalPhotoPagePaper = paper.value as? String
        app.buttons["Style"].tap()
        XCTAssertTrue(app.navigationBars["Style"].waitForExistence(timeout: 3))
        let apply = app.buttons["Apply chapter style cinema"]
        for _ in 0..<5 where !apply.exists { app.swipeUp() }
        XCTAssertTrue(apply.waitForExistence(timeout: 3) && apply.isHittable)
        apply.tap()

        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        XCTAssertNotEqual(paper.value as? String, originalPhotoPagePaper)
        attachScreenshot(named: "Tailor-guided-style-chapter-photo-page")
        app.buttons["Page 4"].tap()
        XCTAssertTrue(app.staticTexts["4 of 8"].waitForExistence(timeout: 3))
        XCTAssertEqual(paper.value as? String, lockedOpenerPaper, "Chapter styling must not overwrite its locked structural opener")

        app.buttons["Editor undo"].tap()
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        XCTAssertEqual(paper.value as? String, originalPhotoPagePaper, "The whole chapter style action must undo as one transaction")
    }

    func testEditorTextFitSuccessUsesOneUndo() {
        launch(demoRoute: "editor", demoState: "text-fit-success")
        app.buttons["Page 5"].tap(); XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        app.buttons["Text"].tap(); XCTAssertTrue(app.buttons["Text field photoCaption"].waitForExistence(timeout: 3))
        app.buttons["Text field photoCaption"].tap()
        let original = app.textViews["Text draft input"].value as? String
        let fit = app.buttons["Fit text"]
        XCTAssertTrue(fit.waitForExistence(timeout: 3) && fit.isHittable)
        fit.tap()
        XCTAssertFalse(app.descendants(matching: .any)["Text draft error"].waitForExistence(timeout: 1), "Fit must clear overflow before the post-Fit assertions")
        XCTAssertEqual(app.textViews["Text draft input"].value as? String, original)
        attachScreenshot(named: "Tailor-editor-text-fit-success")
        app.buttons["Text draft back"].tap()
        app.buttons["Editor undo"].tap()
        app.buttons["Text"].tap(); app.buttons["Text field photoCaption"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Text draft error"].waitForExistence(timeout: 3), "One Undo must restore the pre-Fit overflow")
        attachScreenshot(named: "Tailor-editor-text-fit-success-undo")
    }

    func testEditorTextFitFailurePreservesDraftAndDoesNotCommit() {
        launch(demoRoute: "editor", demoState: "text-fit-failure")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let captionFrame = app.descendants(matching: .any)["Text element photoCaption"]
        XCTAssertTrue(captionFrame.waitForExistence(timeout: 3))
        let originalFrame = captionFrame.value as? String

        app.buttons["Text"].tap()
        XCTAssertTrue(app.buttons["Text field photoCaption"].waitForExistence(timeout: 3))
        app.buttons["Text field photoCaption"].tap()
        let input = app.textViews["Text draft input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        let originalText = input.value as? String
        let fit = app.buttons["Fit text"]
        XCTAssertTrue(fit.waitForExistence(timeout: 3) && fit.isHittable)
        fit.tap()

        XCTAssertTrue(app.staticTexts["Text draft error"].waitForExistence(timeout: 3), "A Fit failure must retain the visible validation error")
        XCTAssertEqual(input.value as? String, originalText, "A Fit failure must retain the complete draft text")
        attachScreenshot(named: "Tailor-editor-text-fit-failure")

        app.buttons["Text draft back"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        XCTAssertEqual(captionFrame.value as? String, originalFrame, "A Fit failure must not mutate the persisted text frame")
        XCTAssertFalse(app.buttons["Editor undo"].isEnabled, "A Fit failure must not create an undo transaction")

        app.buttons["Text"].tap(); app.buttons["Text field photoCaption"].tap()
        XCTAssertEqual(app.textViews["Text draft input"].value as? String, originalText, "A Fit failure must not persist a truncated or altered draft")
        XCTAssertTrue(app.staticTexts["Text draft error"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Tailor-editor-text-fit-failure-reopen")
    }

    func testEditorTextUnicodePasteRespects120And240GraphemeBoundaries() {
        // The payload intentionally contains Chinese, Arabic/RTL characters,
        // a ZWJ family emoji, a combining-accent grapheme and explicit line
        // breaks. `String.count` is the user-visible grapheme count used by
        // the production draft validator.
        let text120 = unicodePayload(graphemeCount: 120)
        let text121 = unicodePayload(graphemeCount: 121)
        let text240 = unicodePayload(graphemeCount: 240)
        let text241 = unicodePayload(graphemeCount: 241)
        XCTAssertEqual(text120.count, 120); XCTAssertEqual(text121.count, 121)
        XCTAssertEqual(text240.count, 240); XCTAssertEqual(text241.count, 241)

        launch(demoRoute: "editor", demoState: "text-unicode-photo")
        app.buttons["Page 5"].tap(); app.buttons["Text"].tap()
        app.buttons["Text field photoCaption"].tap()
        paste(text120, into: app.textViews["Text draft input"])
        XCTAssertEqual(app.textViews["Text draft input"].value as? String, text120, "A 120-grapheme paste must remain complete")
        assertCharacterCount("120/120")
        XCTAssertFalse(app.descendants(matching: .any)["Text draft character limit error"].exists, "Exactly at the 120 limit must not be cut or treated as over-limit")
        attachScreenshot(named: "Tailor-editor-text-unicode-120")

        launch(demoRoute: "editor", demoState: "text-unicode-photo")
        app.buttons["Page 5"].tap(); app.buttons["Text"].tap()
        app.buttons["Text field photoCaption"].tap()
        paste(text121, into: app.textViews["Text draft input"])
        XCTAssertEqual(app.textViews["Text draft input"].value as? String, text121, "A +1 grapheme paste must be retained for correction, never silently truncated")
        assertCharacterCount("121/120")
        assertCharacterLimitError()
        attachScreenshot(named: "Tailor-editor-text-unicode-121")

        launch(demoRoute: "editor", demoState: "text-unicode-dedication")
        app.buttons["Page 2"].tap(); app.buttons["Text"].tap()
        app.buttons["Text field dedicationMessage"].tap()
        paste(text240, into: app.textViews["Text draft input"])
        XCTAssertEqual(app.textViews["Text draft input"].value as? String, text240, "A 240-grapheme paste must remain complete")
        assertCharacterCount("240/240")
        XCTAssertFalse(app.descendants(matching: .any)["Text draft character limit error"].exists, "Exactly at the 240 limit must not be treated as over-limit")
        attachScreenshot(named: "Tailor-editor-text-unicode-240")

        launch(demoRoute: "editor", demoState: "text-unicode-dedication")
        app.buttons["Page 2"].tap(); app.buttons["Text"].tap()
        app.buttons["Text field dedicationMessage"].tap()
        paste(text241, into: app.textViews["Text draft input"])
        XCTAssertEqual(app.textViews["Text draft input"].value as? String, text241, "A +1 grapheme paste must be retained for correction, never silently truncated")
        assertCharacterCount("241/240")
        assertCharacterLimitError()
        attachScreenshot(named: "Tailor-editor-text-unicode-241")
    }

    func testEditorTextDirtyBackKeepSaveDiscardAndInvalidSave() {
        // Keep editing: the keyboard-safe status bar and text must stay in
        // place after the dialog is dismissed without a persistence action.
        launch(demoRoute: "editor", demoState: "text-missing-caption")
        openMissingCaptionDraft()
        let keepInput = app.textViews["Text draft input"]
        keepInput.typeText("Keep this draft")
        app.buttons["Text draft back"].tap()
        let keep = app.buttons["Text draft keep editing"].firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 3))
        keep.tap()
        XCTAssertTrue(keepInput.waitForExistence(timeout: 3))
        XCTAssertEqual(keepInput.value as? String, "Keep this draft")
        attachScreenshot(named: "Tailor-editor-text-dirty-keep")

        // Save: a valid optional role is written once and appears as a
        // persisted field when the sheet opens again.
        launch(demoRoute: "editor", demoState: "text-missing-caption")
        openMissingCaptionDraft()
        app.textViews["Text draft input"].typeText("Saved from the exit dialog")
        app.buttons["Text draft back"].tap()
        let save = app.buttons["Text draft save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        openPersistedCaption()
        XCTAssertEqual(app.textViews["Text draft input"].value as? String, "Saved from the exit dialog")
        attachScreenshot(named: "Tailor-editor-text-dirty-save")
        app.buttons["Text draft back"].tap()
        app.buttons["Editor undo"].tap()
        app.buttons["Text"].tap()
        XCTAssertTrue(app.buttons["Add text field photoCaption"].waitForExistence(timeout: 3), "One Undo must remove the single Save transaction")
        app.buttons["Text draft back"].tap()
        app.buttons["Editor redo"].tap()
        openPersistedCaption()
        XCTAssertEqual(app.textViews["Text draft input"].value as? String, "Saved from the exit dialog", "One Redo must restore the single Save transaction")

        // Discard: the optional role itself must not be created as a side
        // effect of opening/typing in a temporary draft.
        launch(demoRoute: "editor", demoState: "text-missing-caption")
        openMissingCaptionDraft()
        app.textViews["Text draft input"].typeText("Discard this draft")
        app.buttons["Text draft back"].tap()
        let discard = app.buttons["Text draft discard"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 3))
        discard.tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Editor undo"].isEnabled, "Discard must not create a history transaction")
        app.buttons["Text"].tap()
        XCTAssertTrue(app.buttons["Add text field photoCaption"].waitForExistence(timeout: 3), "Discard must leave the optional role absent")
        attachScreenshot(named: "Tailor-editor-text-dirty-discard")

        // Invalid Save is explicitly blocked: it must leave the sheet open,
        // preserve the full draft and expose the validation repair surface.
        launch(demoRoute: "editor", demoState: "text-fit-failure")
        app.buttons["Page 5"].tap(); app.buttons["Text"].tap(); app.buttons["Text field photoCaption"].tap()
        let invalidInput = app.textViews["Text draft input"]
        let invalidText = (invalidInput.value as? String ?? "") + "x"
        invalidInput.typeText("x")
        app.buttons["Text draft back"].tap()
        let invalidSave = app.buttons["Text draft save"].firstMatch
        XCTAssertTrue(invalidSave.waitForExistence(timeout: 3))
        invalidSave.tap()
        XCTAssertTrue(invalidInput.waitForExistence(timeout: 3), "Invalid Save must keep the editor open")
        XCTAssertEqual(invalidInput.value as? String, invalidText)
        XCTAssertTrue(app.buttons["Fit text"].waitForExistence(timeout: 3), "Invalid Save must retain a visible repair action")
        attachScreenshot(named: "Tailor-editor-text-dirty-invalid-save")
    }

    func testEditorTextDragClampsToSafeGeometryAndUndoRestoresDocument() {
        launch(demoRoute: "editor", demoState: "text-safe-drag")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let text = app.descendants(matching: .any)["Text element photoCaption"].firstMatch
        let canvas = app.descendants(matching: .any)["Editor page canvas"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 3) && canvas.waitForExistence(timeout: 3))
        let original = textSafetyMarker(text)

        // First aim directly at the preview watermark; then aim at the
        // footer/page-number direction. Both are protected by the plan that
        // the editor, preview and PDF renderer share.
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.12, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.30)))
        let watermarkAttempt = textSafetyMarker(text)
        XCTAssertNotEqual(watermarkAttempt, original)
        assertSafeTextMarker(watermarkAttempt)
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.12, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.98)))
        let footerAttempt = textSafetyMarker(text)
        XCTAssertNotEqual(footerAttempt, watermarkAttempt)
        assertSafeTextMarker(footerAttempt)
        attachScreenshot(named: "Tailor-editor-text-safe-drag")

        XCTAssertTrue(app.buttons["Editor undo"].isEnabled)
        app.buttons["Editor undo"].tap()
        let afterOneUndo = textSafetyMarker(text)
        XCTAssertEqual(afterOneUndo, watermarkAttempt, "Undo must restore the prior committed drag atomically")
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(textSafetyMarker(text), original, "Second Undo must restore the original text frame")
        attachScreenshot(named: "Tailor-editor-text-safe-drag-undo")
    }

    func testEditorPrecisionCanvasZoomsAndFits() {
        launch(demoRoute: "editor")
        let fit = app.buttons["Fit canvas"]
        let zoomIn = app.buttons["Zoom in canvas"]
        let zoomOut = app.buttons["Zoom out canvas"]
        XCTAssertTrue(fit.waitForExistence(timeout: 3))
        XCTAssertEqual(fit.value as? String, "100 percent")
        XCTAssertFalse(zoomOut.isEnabled)

        zoomIn.tap()
        XCTAssertEqual(fit.value as? String, "125 percent")
        XCTAssertTrue(zoomOut.isEnabled)
        attachScreenshot(named: "Tailor-editor-precision-canvas-125")

        fit.tap()
        XCTAssertEqual(fit.value as? String, "100 percent")
        XCTAssertFalse(zoomOut.isEnabled)
    }

    func testEditorResizeHandleCommitsOneUndoableFrameChange() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let photo = app.descendants(matching: .any)["Photo element"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        photo.tap()

        let handle = app.descendants(matching: .any)["Element resize handle"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 3))
        let original = handle.frame
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.12, thenDragTo: start.withOffset(CGVector(dx: 28, dy: 28)))
        let resized = handle.frame
        XCTAssertNotEqual(resized, original, "The visible resize handle must write a real document-frame change")
        attachScreenshot(named: "Tailor-editor-resize-handle")

        XCTAssertTrue(app.buttons["Editor undo"].isEnabled)
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(handle.frame, original, "One Undo must restore the complete resize transaction")
    }

    func testEditorArrangeMenuLocksAlignsAndDuplicatesSelection() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let photos = app.descendants(matching: .any).matching(identifier: "Photo element")
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 3))
        let originalCount = photos.count
        photos.firstMatch.tap()

        let arrange = app.buttons["Arrange selected element"]
        XCTAssertTrue(arrange.waitForExistence(timeout: 3))
        arrange.tap()
        app.buttons["Lock element"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Locked element indicator"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["Element resize handle"].exists)

        app.buttons["Arrange selected element"].tap()
        app.buttons["Unlock element"].tap()
        let handle = app.descendants(matching: .any)["Element resize handle"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 3))
        let beforeAlign = handle.frame
        app.buttons["Arrange selected element"].tap()
        app.buttons["Align"].tap()
        app.buttons["Align horizontal center"].tap()
        XCTAssertNotEqual(handle.frame, beforeAlign)
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(handle.frame, beforeAlign)

        app.buttons["Arrange selected element"].tap()
        app.buttons["Duplicate element"].tap()
        XCTAssertEqual(photos.count, originalCount + 1)
        XCTAssertTrue(app.buttons["Editor undo"].isEnabled)
        attachScreenshot(named: "Tailor-editor-arrange-duplicate")
    }

    func testEditorPhotoAppearanceAppliesAsOneUndoableDocumentChange() {
        launch(demoRoute: "editor", demoState: "crop-landscape")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let photo = app.descendants(matching: .any)["Photo element"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        photo.tap()
        let selectedTransform = app.descendants(matching: .any)["Selected photo transform"].firstMatch
        XCTAssertTrue(selectedTransform.waitForExistence(timeout: 3))
        let original = marker(of: selectedTransform)

        app.buttons["Photo"].tap()
        XCTAssertTrue(app.buttons["Photo appearance"].waitForExistence(timeout: 3))
        app.buttons["Photo appearance"].tap()
        XCTAssertTrue(app.navigationBars["Photo appearance"].waitForExistence(timeout: 3))
        app.buttons["Oval"].tap()
        app.buttons["Solid"].tap()
        app.swipeUp()
        let shadow = app.buttons["Toggle photo shadow"].firstMatch
        XCTAssertTrue(shadow.waitForExistence(timeout: 3))
        shadow.tap()
        attachScreenshot(named: "Tailor-editor-photo-appearance-draft")
        let preset = app.buttons["Photo preset Warm memory"].firstMatch
        for _ in 0..<4 where !preset.exists { app.swipeUp() }
        XCTAssertTrue(preset.waitForExistence(timeout: 3))
        preset.tap()
        app.buttons["Apply"].tap()

        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(selectedTransform.waitForExistence(timeout: 3))
        let applied = marker(of: selectedTransform)
        XCTAssertNotEqual(applied, original)
        XCTAssertTrue(applied.contains("mask=ellipse") && applied.contains("border=solid") && applied.contains("shadow=0.24") && applied.contains("warmth=0.28"), "Applied appearance and finishing must be persisted in the shared element: \(applied)")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.57)).tap()
        attachScreenshot(named: "Tailor-editor-photo-appearance-applied")

        let appliedPhoto = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND value == %@", "Photo element", applied)
        ).firstMatch
        XCTAssertTrue(appliedPhoto.waitForExistence(timeout: 3))
        appliedPhoto.tap()
        let reselectedTransform = app.descendants(matching: .any)["Selected photo transform"].firstMatch
        XCTAssertTrue(reselectedTransform.waitForExistence(timeout: 3))
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(marker(of: reselectedTransform), original, "Appearance Apply must be one atomic history transaction")
    }

    func testEditorPhotoGeometryAndAutoEnhanceApplyAsOneSharedChange() {
        launch(demoRoute: "editor", demoState: "crop-landscape")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let photo = app.descendants(matching: .any)["Photo element"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        photo.tap()
        let selectedTransform = app.descendants(matching: .any)["Selected photo transform"].firstMatch
        XCTAssertTrue(selectedTransform.waitForExistence(timeout: 3))
        let original = marker(of: selectedTransform)

        app.buttons["Photo"].tap()
        app.buttons["Photo appearance"].tap()
        XCTAssertTrue(app.navigationBars["Photo appearance"].waitForExistence(timeout: 3))
        for _ in 0..<3 where !app.buttons["Flip photo horizontal"].exists { app.swipeUp() }
        app.buttons["Flip photo horizontal"].tap()
        let straighten = app.descendants(matching: .any)["Adjustment slider Straighten"].firstMatch
        XCTAssertTrue(straighten.waitForExistence(timeout: 3))
        straighten.adjust(toNormalizedSliderPosition: 0.75)
        for _ in 0..<3 where !app.buttons["Photo auto enhance"].exists { app.swipeUp() }
        let autoEnhance = app.buttons["Photo auto enhance"]
        XCTAssertTrue(autoEnhance.waitForExistence(timeout: 3))
        autoEnhance.tap()
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: autoEnhance)
        waitForExpectations(timeout: 5)
        attachScreenshot(named: "Tailor-editor-photo-geometry-auto-draft")
        app.buttons["Apply"].tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        XCTAssertTrue(selectedTransform.waitForExistence(timeout: 3))
        let applied = marker(of: selectedTransform)
        XCTAssertTrue(applied.contains("flipH=true"), "Horizontal flip must persist in the shared element: \(applied)")
        XCTAssertFalse(applied.contains("straighten=0.0"), "Straighten must persist in the shared element: \(applied)")
        XCTAssertFalse(applied.contains("ev=0.00"), "Auto Enhance must produce a visible but conservative adjustment: \(applied)")
        attachScreenshot(named: "Tailor-editor-photo-geometry-auto-applied")
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(marker(of: selectedTransform), original, "Geometry and Auto Enhance Apply must be one atomic history transaction")
    }

    func testEditorDecorationCanBeDesignedManagedAsALayerAndUndone() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let decorations = app.descendants(matching: .any).matching(identifier: "Decoration element")
        XCTAssertEqual(decorations.count, 0)

        app.buttons["More editor actions"].tap()
        app.buttons["Add decoration"].tap()
        XCTAssertTrue(app.navigationBars["Decoration appearance"].waitForExistence(timeout: 3))
        app.buttons["Oval"].tap()
        app.buttons["Solid"].tap()
        app.swipeUp()
        let shadow = app.buttons["Toggle decoration shadow"].firstMatch
        XCTAssertTrue(shadow.waitForExistence(timeout: 3))
        // Decorations start with a subtle default shadow. Exercise both states:
        // remove it once, then add the stronger editable shadow back.
        shadow.tap()
        XCTAssertTrue(shadow.waitForExistence(timeout: 3))
        shadow.tap()
        attachScreenshot(named: "Tailor-editor-decoration-appearance-draft")
        app.buttons["Apply"].tap()

        let decoration = decorations.firstMatch
        XCTAssertTrue(decoration.waitForExistence(timeout: 3))
        let applied = marker(of: decoration)
        XCTAssertTrue(applied.contains("mask=ellipse") && applied.contains("border=solid") && applied.contains("shadow=0.24"), "Decoration styling must persist in the shared element: \(applied)")
        XCTAssertTrue(app.descendants(matching: .any)["Element resize handle"].waitForExistence(timeout: 3), "A decoration needs the same direct-manipulation resize affordance as a photo")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.57)).tap()
        attachScreenshot(named: "Tailor-editor-decoration-applied")

        app.buttons["More editor actions"].tap()
        app.buttons["Layers"].tap()
        XCTAssertTrue(app.navigationBars["Layers"].waitForExistence(timeout: 3))
        let hideDecoration = app.buttons["Hide Decoration layer"].firstMatch
        XCTAssertTrue(hideDecoration.waitForExistence(timeout: 3))
        hideDecoration.tap()
        app.buttons["Done"].tap()
        XCTAssertEqual(decorations.count, 0)
        app.buttons["Editor undo"].tap()
        XCTAssertTrue(decorations.firstMatch.waitForExistence(timeout: 3), "One Undo must restore a decoration hidden from the Layers panel")
    }

    func testEditorPageBackgroundAppliesAsOneUndoableSharedChange() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let paper = app.descendants(matching: .any)["Page paper"].firstMatch
        XCTAssertTrue(paper.waitForExistence(timeout: 3))
        let original = marker(of: paper)

        app.buttons["Style"].tap()
        XCTAssertTrue(app.navigationBars["Style"].waitForExistence(timeout: 3))
        app.buttons["Customize background"].tap()
        XCTAssertTrue(app.navigationBars["Page background"].waitForExistence(timeout: 3))
        app.buttons["Background preset Quiet sage"].tap()
        attachScreenshot(named: "Tailor-editor-page-background-draft")
        app.buttons["Apply"].tap()
        XCTAssertTrue(app.navigationBars["Style"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        XCTAssertEqual(marker(of: paper), "red=0.820;green=0.870;blue=0.780")
        XCTAssertNotEqual(marker(of: paper), original)
        attachScreenshot(named: "Tailor-editor-page-background-applied")
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(marker(of: paper), original, "Background Apply must create exactly one Undo transaction")
    }

    func testEditorMultiSelectGroupsMovesAndUndoesAsOneTransaction() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let photos = app.descendants(matching: .any).matching(identifier: "Photo element")
        XCTAssertGreaterThanOrEqual(photos.count, 2)

        app.buttons["Select multiple elements"].tap()
        photos.element(boundBy: 0).tap()
        photos.element(boundBy: 1).tap()
        let bounds = app.descendants(matching: .any)["Multi-selection bounds"].firstMatch
        XCTAssertTrue(bounds.waitForExistence(timeout: 3))
        XCTAssertEqual(bounds.label, "2 selected elements")

        app.buttons["Arrange 2 selected elements"].tap()
        app.buttons["Group selected"].tap()
        app.buttons["Arrange 2 selected elements"].tap()
        XCTAssertTrue(app.buttons["Ungroup selected"].waitForExistence(timeout: 3), "Grouping must be reflected by the persisted selection model")
        app.staticTexts["5 of 8"].tap()
        app.buttons["Finish multiple selection"].tap()

        let original = bounds.value as? String
        let start = bounds.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.12, thenDragTo: start.withOffset(CGVector(dx: 20, dy: 18)))
        XCTAssertNotEqual(bounds.value as? String, original)
        XCTAssertTrue(app.buttons["Editor undo"].isEnabled)
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(bounds.value as? String, original, "One Undo must restore every member of the group move")
        attachScreenshot(named: "Tailor-editor-multi-select-group")
    }

    func testEditorLayersPanelHidesAndUndoRestoresPhoto() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let photos = app.descendants(matching: .any).matching(identifier: "Photo element")
        let originalCount = photos.count
        XCTAssertGreaterThan(originalCount, 0)

        app.buttons["More editor actions"].tap()
        app.buttons["Layers"].tap()
        XCTAssertTrue(app.navigationBars["Layers"].waitForExistence(timeout: 3))
        let hidePhoto = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Hide Photo layer'")).firstMatch
        XCTAssertTrue(hidePhoto.waitForExistence(timeout: 3))
        hidePhoto.tap()
        app.buttons["Done"].tap()
        XCTAssertEqual(photos.count, originalCount - 1)

        app.buttons["Editor undo"].tap()
        XCTAssertEqual(photos.count, originalCount)
        attachScreenshot(named: "Tailor-editor-layers-visibility-undo")
    }

    func testEditorCopiesPhotoAcrossCompatiblePagesAndUndoesPaste() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let source = app.descendants(matching: .any)["Photo element"].firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 3))
        source.tap()
        app.buttons["Arrange selected element"].tap()
        app.buttons["Copy element"].tap()

        let pageSeven = app.buttons["Page 7"]
        XCTAssertTrue(pageSeven.waitForExistence(timeout: 3))
        app.buttons["Page 6"].swipeLeft()
        XCTAssertTrue(waitUntilHittable(pageSeven))
        pageSeven.tap()
        XCTAssertTrue(app.staticTexts["7 of 8"].waitForExistence(timeout: 3))
        let targetPhotos = app.descendants(matching: .any).matching(identifier: "Photo element")
        let originalCount = targetPhotos.count
        app.buttons["More editor actions"].tap()
        app.buttons["Paste copied elements"].tap()
        XCTAssertEqual(targetPhotos.count, originalCount + 1)
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(targetPhotos.count, originalCount)
        attachScreenshot(named: "Tailor-editor-cross-page-copy")
    }

    func testEditorTextBridgeRendersFixtureCaption() {
        launch(demoRoute: "editor", demoState: "text-safe-drag")
        let pageFive = app.buttons["Page 5"]
        XCTAssertTrue(waitUntilHittable(pageFive), "Page 5 thumbnail must be visible and tappable before bridge diagnostics")
        pageFive.tap()
        attachScreenshot(named: "Tailor-editor-text-bridge-after-page-five-tap")
        print(app.debugDescription)
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let diagnostic = app.descendants(matching: .any)["Text renderer diagnostic photoCaption"].firstMatch
        XCTAssertTrue(diagnostic.waitForExistence(timeout: 3), "UIKit text bridge must expose a rendered diagnostic in UI-test mode")
        let value = diagnostic.value as? String ?? ""
        XCTAssertTrue(value.contains("snapshot=21") && value.contains("attributed=21"), "Expected non-empty B1 attributed caption: \(value)")
        XCTAssertFalse(value.contains("bounds=unresolved") || value.contains("bounds=0.0x0.0"), "UIKit label must receive a finite, nonzero SwiftUI frame: \(value)")
        XCTAssertTrue(value.contains("alpha=1.0") && value.contains("hidden=false"), "Caption bridge must remain visible: \(value)")
        // The screenshot is the visual assertion. `Editor page canvas` is an
        // accessibility container, so its label intentionally supersedes the
        // nested UILabel's spoken text in the tree; use the bridge's explicit
        // renderer diagnostic instead of treating that container policy as a
        // rendering failure.
        attachScreenshot(named: "Tailor-editor-text-bridge-caption")
    }

    func testEditorFixtureExposesExplicitLayoutChoices() {
        launch(demoRoute: "editor")
        // The fixture opens on the structural cover. Layout changes are only
        // available on editable photo pages, so select the first photo page.
        XCTAssertTrue(app.buttons["Page 5"].waitForExistence(timeout: 3))
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.buttons["Layout"].waitForExistence(timeout: 3))
        app.buttons["Layout"].tap()
        XCTAssertTrue(app.navigationBars["Layout"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Single"].exists)
        XCTAssertTrue(app.buttons["Two-up"].exists)
        XCTAssertTrue(app.buttons["Grid 2×2"].exists)
        XCTAssertTrue(app.buttons["Grid 3×2"].exists)
        XCTAssertTrue(app.buttons["Note"].exists)
        app.buttons["Note"].tap()
        XCTAssertTrue(app.buttons["Apply layout"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Tailor-editor-note-layout-confirm")
        let keepCurrentLayout = app.buttons["Keep current layout"]
        XCTAssertTrue(keepCurrentLayout.waitForExistence(timeout: 3))
        keepCurrentLayout.tap()
        XCTAssertTrue(app.buttons["Layout"].waitForExistence(timeout: 3))
    }

    func testEditorCropHasStableIdentifiersAndCancelDoneFlow() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        let photo = app.descendants(matching: .any)["Photo element"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        photo.tap()
        app.buttons["Photo"].tap()
        let crop = app.buttons["Photo tool crop"]
        XCTAssertTrue(crop.waitForExistence(timeout: 3))
        crop.tap()
        XCTAssertTrue(app.buttons["Crop reset"].waitForExistence(timeout: 3))
        app.buttons["Crop cancel bottom"].tap()
        XCTAssertTrue(app.buttons["Photo"].waitForExistence(timeout: 3))
        app.buttons["Photo"].tap()
        XCTAssertTrue(app.buttons["Photo tool crop"].waitForExistence(timeout: 3))
        app.buttons["Photo tool crop"].tap()
        XCTAssertTrue(app.buttons["Crop done primary"].waitForExistence(timeout: 3))
        app.buttons["Crop done primary"].tap()
        XCTAssertTrue(app.buttons["Photo"].waitForExistence(timeout: 3))
    }

    func testEditorInitialFocalCropUsesDetectedOffCentreSubject() {
        launch(demoRoute: "editor", demoState: "crop-landscape-focal-right")
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        let photos = app.descendants(matching: .any).matching(identifier: "Photo element")
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 3))
        let candidates = (0..<photos.count).map { photos.element(boundBy: $0) }
        let focalPhoto = candidates.first { marker(of: $0).contains("offsetX=-") }
        XCTAssertNotNil(focalPhoto, "Exactly the asset with local subject geometry must receive an off-centre initial crop")
        let value = marker(of: focalPhoto ?? photos.firstMatch)
        let fields = Dictionary(uniqueKeysWithValues: value.split(separator: ";").compactMap { part -> (String, String)? in
            let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
            return pieces.count == 2 ? (pieces[0], pieces[1]) : nil
        })
        let offsetX = Double(fields["offsetX"] ?? "")
        XCTAssertNotNil(offsetX, "The shared document marker must expose the persisted initial crop")
        XCTAssertLessThan(offsetX ?? 0, -0.05, "A subject on the right must shift left toward the frame centre without user input")
        XCTAssertEqual(fields["scale"], "1.000", "Aspect-fill excess should be used before inventing extra zoom")
        focalPhoto?.tap()
        attachScreenshot(named: "Tailor-editor-initial-focal-crop-right")
    }

    func testM7PhotorealisticPhotoKitEditorPreflight() throws {
        if app.state != .notRunning { app.terminate() }
        addUIInterruptionMonitor(withDescription: "Photos permission") { alert in
            for label in ["Allow Full Access", "Allow Access to All Photos", "Allow", "允许完全访问", "允许访问所有照片", "允许"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        app.launchArguments = ["-uiRealPhotoQA", "-uiBypassPurchase"]
        app.launch()
        app.tap()
        guard app.buttons["Page 5"].waitForExistence(timeout: 8) else {
            let diagnostic = app.descendants(matching: .any)["M7 real photo diagnostic"]
            let detail = diagnostic.waitForExistence(timeout: 1) ? diagnostic.label : "diagnostic-unavailable"
            throw XCTSkip("The four local M7 PhotoKit assets are intentionally absent from a clean CI simulator (\(detail))")
        }
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 6"].waitForExistence(timeout: 3))
        let photoElements = app.descendants(matching: .any).matching(identifier: "Photo element")
        XCTAssertEqual(photoElements.count, 4)
        let diagnostic = app.descendants(matching: .any)["M7 real photo diagnostic"]
        let transforms = (0..<photoElements.count).map { String(describing: photoElements.element(boundBy: $0).value ?? "nil") }.joined(separator: "\n")
        let cropEvidence = XCTAttachment(string: "\(diagnostic.label)\n\(transforms)")
        cropEvidence.name = "Tailor-M7-photorealistic-focal-diagnostic"
        cropEvidence.lifetime = .keepAlways
        add(cropEvidence)
        attachScreenshot(named: "Tailor-M7-photorealistic-PhotoKit-editor")

        let more = app.buttons["More editor actions"]
        XCTAssertTrue(more.waitForExistence(timeout: 3))
        more.tap()
        let preview = app.buttons["Reading preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        preview.tap()
        XCTAssertTrue(app.staticTexts["A book to keep."].waitForExistence(timeout: 5))
        attachScreenshot(named: "Tailor-M7-photorealistic-PhotoKit-reader")

        app.buttons["Edit book"].tap()
        XCTAssertTrue(app.buttons["More editor actions"].waitForExistence(timeout: 3))
        app.buttons["More editor actions"].tap()
        XCTAssertTrue(app.buttons["Export PDF"].waitForExistence(timeout: 3))
        app.buttons["Export PDF"].tap()
        XCTAssertTrue(app.navigationBars["Book check"].waitForExistence(timeout: 5))
        let cropBlocker = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "no subject focus is available")
        ).firstMatch
        XCTAssertTrue(
            cropBlocker.waitForExistence(timeout: 3),
            "A severe automatic crop without focal metadata must not reach PDF export until the user reviews it"
        )
        XCTAssertFalse(app.staticTexts["Ready when you are."].exists)
        attachScreenshot(named: "Tailor-M7-photorealistic-severe-crop-blocked")

        // Confirm each severe portrait crop through the production UI. This
        // proves the quality gate is recoverable, persists user ownership, and
        // allows the same real PhotoKit book to reach PDF only afterwards.
        for reviewIndex in 1...2 {
            let reviewCrop = app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@", "confirm the framing before export")
            ).firstMatch
            XCTAssertTrue(reviewCrop.waitForExistence(timeout: 3))
            reviewCrop.tap()
            XCTAssertTrue(app.buttons["Photo"].waitForExistence(timeout: 3))
            app.buttons["Photo"].tap()
            if reviewIndex == 1 {
                // Use the production precision controls for a deterministic,
                // printable composition: 1.3x creates enough pan slack while
                // retaining about 176 PPI, then three small downward nudges
                // bring the high cat subject into the landscape frame.
                let zoomIn = app.buttons["Photo crop zoom in"]
                let nudgeDown = app.buttons["Photo crop nudge down"]
                XCTAssertTrue(zoomIn.waitForExistence(timeout: 3))
                XCTAssertTrue(nudgeDown.exists)
                for _ in 0..<3 { zoomIn.tap() }
                for _ in 0..<3 { nudgeDown.tap() }
            }
            XCTAssertTrue(app.buttons["Photo tool crop"].waitForExistence(timeout: 3))
            app.buttons["Photo tool crop"].tap()
            XCTAssertTrue(app.buttons["Crop done primary"].waitForExistence(timeout: 3))
            if reviewIndex == 1 {
                // The first blocker is the tall cat photo. Its centered fill
                // places the face above the landscape aperture, so exercise a
                // real corrective composition instead of merely acknowledging
                // the warning and approving an unattractive crop.
                let crop = app.descendants(matching: .any)["Crop canvas"].firstMatch
                XCTAssertTrue(crop.waitForExistence(timeout: 3))
                let reviewedComposition = marker(of: crop)
                XCTAssertTrue(reviewedComposition.contains("scale=1.300"))
                XCTAssertFalse(reviewedComposition.contains("offsetY=0.000"))
            }
            attachScreenshot(named: "Tailor-M7-photorealistic-crop-review-\(reviewIndex)")
            app.buttons["Crop done primary"].tap()
            XCTAssertTrue(app.buttons["More editor actions"].waitForExistence(timeout: 3))
            app.buttons["More editor actions"].tap()
            XCTAssertTrue(app.buttons["Export PDF"].waitForExistence(timeout: 3))
            app.buttons["Export PDF"].tap()
            if reviewIndex == 1 {
                XCTAssertTrue(app.navigationBars["Book check"].waitForExistence(timeout: 5))
            }
        }

        XCTAssertTrue(app.staticTexts["Ready when you are."].waitForExistence(timeout: 5))
        app.buttons["Generate PDF"].tap()
        XCTAssertTrue(app.staticTexts["Your PDF is ready."].waitForExistence(timeout: 15))
        attachScreenshot(named: "Tailor-M7-photorealistic-reviewed-PDF-complete")
    }

    func testEditorCropDraftExitOffersKeepSaveAndDiscard() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        let photo = app.descendants(matching: .any)["Photo element"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        photo.tap()
        app.buttons["Photo"].tap()
        XCTAssertTrue(app.buttons["Photo tool crop"].waitForExistence(timeout: 3))
        // Seed a committed crop, then Reset in the independent sheet. This
        // gives the exit-state test a deterministic dirty draft without
        // relying on screen-coordinate gestures.
        app.buttons["Photo crop zoom in"].tap()
        app.buttons["Photo crop nudge right"].tap()
        app.buttons["Photo tool crop"].tap()
        XCTAssertTrue(app.buttons["Crop reset"].waitForExistence(timeout: 3))
        // Reset changes only this session draft; Back must ask whether it is
        // kept, saved, or discarded.
        app.buttons["Crop reset"].tap()
        XCTAssertTrue(app.buttons["Crop reset confirm"].waitForExistence(timeout: 3))
        app.buttons["Crop reset confirm"].firstMatch.tap()
        app.buttons["Crop cancel"].tap()
        XCTAssertTrue(app.buttons["Crop keep editing"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Crop save and leave"].exists)
        XCTAssertTrue(app.buttons["Crop discard"].exists)
        attachScreenshot(named: "Tailor-editor-crop-unsaved-exit")

        app.buttons["Crop keep editing"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Crop done primary"].waitForExistence(timeout: 3))
        app.buttons["Crop cancel bottom"].tap()
        XCTAssertTrue(app.buttons["Crop discard"].waitForExistence(timeout: 3))
        app.buttons["Crop discard"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Photo"].waitForExistence(timeout: 3))
    }

    /// F-P02-CROP-UI: exercise a genuine sheet-local drag rather than only
    /// tapping controls. The screenshot attachments are the design-review
    /// evidence for the fixed aperture, 72% outside mask and rotated source.
    func testCropDraftCancelDoneUndoRedoAndResetConfirmation() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        let photo = app.descendants(matching: .any)["Photo element"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        let baselineMarker = marker(of: photo)
        photo.tap()
        app.buttons["Photo"].tap()
        XCTAssertTrue(app.buttons["Photo tool crop"].waitForExistence(timeout: 3))
        app.buttons["Photo tool crop"].tap()
        let crop = app.descendants(matching: .any)["Crop canvas"].firstMatch
        XCTAssertTrue(crop.waitForExistence(timeout: 3))
        XCTAssertEqual(marker(of: crop), baselineMarker, "Crop entry must read the persisted element transform")
        XCTAssertTrue(app.descendants(matching: .any)["Crop fixed frame"].firstMatch.exists)
        // At the legal minimum fill scale an offset is intentionally clamped
        // to zero. Pinch first, then drag, so this is a real non-zero draft.
        crop.pinch(withScale: 1.25, velocity: 1.0)
        let start = crop.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50))
        start.press(forDuration: 0.12, thenDragTo: crop.coordinate(withNormalizedOffset: CGVector(dx: 0.67, dy: 0.42)))
        // Re-query after the gesture: XCUIElement caches accessibility values
        // across a gesture transaction, while the SwiftUI state has rerendered.
        let discardedDraftMarker = marker(of: cropCanvas())
        XCTAssertNotEqual(discardedDraftMarker, baselineMarker, "A real pinch + stage drag must change the sheet-local draft marker")
        attachScreenshot(named: "Tailor-crop-portrait-rotated-72-mask-draft")
        app.buttons["Crop cancel bottom"].tap()
        XCTAssertTrue(app.buttons["Crop discard"].waitForExistence(timeout: 3))
        app.buttons["Crop discard"].firstMatch.tap()

        let afterCancel = persistedPhotoElement()
        XCTAssertTrue(afterCancel.waitForExistence(timeout: 3))
        XCTAssertEqual(marker(of: afterCancel), baselineMarker, "Cancel/Discard must not mutate the document")

        // Re-enter and commit a genuine sheet gesture. The editor's marker is
        // read back after every history transition, not inferred from control
        // visibility.
        afterCancel.tap()
        app.buttons["Photo"].tap()
        XCTAssertTrue(app.buttons["Photo tool crop"].waitForExistence(timeout: 3))
        app.buttons["Photo tool crop"].tap()
        let committedDraft = app.descendants(matching: .any)["Crop canvas"].firstMatch
        XCTAssertTrue(committedDraft.waitForExistence(timeout: 3))
        committedDraft.pinch(withScale: 1.25, velocity: 1.0)
        let origin = committedDraft.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.52))
        origin.press(forDuration: 0.12, thenDragTo: committedDraft.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.63)))
        let doneMarker = marker(of: cropCanvas())
        XCTAssertNotEqual(doneMarker, baselineMarker)
        app.buttons["Crop done primary"].tap()
        let afterDone = persistedPhotoElement()
        XCTAssertTrue(afterDone.waitForExistence(timeout: 3))
        XCTAssertEqual(marker(of: afterDone), doneMarker, "Done must persist the crop draft")
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(marker(of: persistedPhotoElement()), baselineMarker, "Undo must restore the pre-Done document")
        app.buttons["Editor redo"].tap()
        XCTAssertEqual(marker(of: persistedPhotoElement()), doneMarker, "Redo must restore the committed document")

        // Reset begins from the persisted Done state, is confirmed, and then
        // commits as a separate operation. Undo must bring back `doneMarker`.
        persistedPhotoElement().tap()
        app.buttons["Photo"].tap()
        app.buttons["Photo tool crop"].tap()
        XCTAssertEqual(marker(of: app.descendants(matching: .any)["Crop canvas"].firstMatch), doneMarker)
        app.buttons["Crop reset"].tap()
        XCTAssertTrue(app.buttons["Crop reset confirm"].waitForExistence(timeout: 3))
        app.buttons["Crop reset confirm"].firstMatch.tap()
        let resetMarker = marker(of: app.descendants(matching: .any)["Crop canvas"].firstMatch)
        XCTAssertNotEqual(resetMarker, doneMarker, "Reset confirmation must modify only the current draft")
        attachScreenshot(named: "Tailor-crop-reset-confirmed-fixed-frame")
        app.buttons["Crop done primary"].tap()
        XCTAssertEqual(marker(of: persistedPhotoElement()), resetMarker, "Reset → Done must persist reset")
        app.buttons["Editor undo"].tap()
        XCTAssertEqual(marker(of: persistedPhotoElement()), doneMarker, "Undo after Reset → Done must restore its entry transform")
        app.buttons["Editor redo"].tap()
        XCTAssertEqual(marker(of: persistedPhotoElement()), resetMarker, "Redo after Reset → Done must restore reset")
        attachScreenshot(named: "Tailor-crop-done-undo-redo-editor")
    }

    /// Product/design visual fixtures: each reaches the actual full-screen
    /// Crop stage through the editor, rather than rendering an isolated mock.
    func testCropStageFixtureScreenshotsForAspectAndRotation() {
        for fixture in ["crop-landscape", "crop-portrait-plus15", "crop-portrait-minus15", "crop-square-plus15"] {
            launch(demoRoute: "editor", demoState: fixture)
            app.buttons["Page 5"].tap()
            let photo = app.descendants(matching: .any)["Photo element"].firstMatch
            XCTAssertTrue(photo.waitForExistence(timeout: 3), fixture)
            photo.tap()
            app.buttons["Photo"].tap()
            XCTAssertTrue(app.buttons["Photo tool crop"].waitForExistence(timeout: 3), fixture)
            app.buttons["Photo tool crop"].tap()
            let canvas = app.descendants(matching: .any)["Crop canvas"].firstMatch
            let topCancel = app.buttons["Crop cancel"].firstMatch
            let topDone = app.buttons["Crop done navigation"].firstMatch
            XCTAssertTrue(canvas.waitForExistence(timeout: 5), fixture)
            XCTAssertTrue(topCancel.waitForExistence(timeout: 5), fixture)
            XCTAssertTrue(topDone.waitForExistence(timeout: 5), fixture)
            XCTAssertTrue(app.buttons["Crop reset"].waitForExistence(timeout: 5), fixture)
            XCTAssertTrue(app.buttons["Crop cancel bottom"].waitForExistence(timeout: 5), fixture)
            XCTAssertTrue(app.buttons["Crop done primary"].waitForExistence(timeout: 5), fixture)
            XCTAssertTrue(app.descendants(matching: .any)["Crop fixed frame"].firstMatch.exists, fixture)
            // `exists` occurs near the start of UIKit's full-screen-cover
            // transition. A real pinch/drag and top-Cancel behavior have
            // their own CRP-003 evidence. The visual fixture gate is instead
            // the complete window's controls/frame plus an explicit settle;
            // XCUITest can incorrectly report an otherwise visible SwiftUI
            // navigation button as not hittable in this full-screen cover.
            Thread.sleep(forTimeInterval: 0.7)
            attachScreenshot(named: "Tailor-crop-stage-\(fixture)-fixed-frame-72-mask")
            app.buttons["Crop cancel bottom"].tap()
        }
    }

    /// A Crop session is a modal editing state: the page rail is not
    /// interactive/visible until the user explicitly keeps, saves or discards
    /// its draft. This is the executable page-change branch of the exit-state
    /// machine (the pure model tests cover every source enum value).
    func testCropBlocksPageSwitchUntilDraftDecision() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        app.descendants(matching: .any)["Photo element"].firstMatch.tap()
        app.buttons["Photo"].tap()
        app.buttons["Photo tool crop"].tap()
        let crop = app.descendants(matching: .any)["Crop canvas"].firstMatch
        XCTAssertTrue(crop.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Page 1"].exists, "Page rail must not be reachable while Crop owns the draft")
        crop.pinch(withScale: 1.2, velocity: 1)
        let dragStart = crop.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50))
        dragStart.press(forDuration: 0.12, thenDragTo: crop.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.45)))
        app.buttons["Crop cancel bottom"].tap()
        XCTAssertTrue(app.buttons["Crop keep editing"].waitForExistence(timeout: 3))
        app.buttons["Crop keep editing"].firstMatch.tap()
        XCTAssertTrue(crop.exists)
        XCTAssertFalse(app.buttons["Page 5"].exists)
        app.buttons["Crop cancel bottom"].tap()
        app.buttons["Crop discard"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Page 1"].waitForExistence(timeout: 3), "Page rail returns only after a decision")
    }

    /// Physical home/background followed by activation must preserve the
    /// draft and show the same deliberate exit decision instead of silently
    /// dismissing the Crop stage.
    func testCropForegroundRequestsDecisionForDirtyDraft() {
        launch(demoRoute: "editor")
        app.buttons["Page 5"].tap()
        app.descendants(matching: .any)["Photo element"].firstMatch.tap()
        app.buttons["Photo"].tap()
        app.buttons["Photo tool crop"].tap()
        let crop = app.descendants(matching: .any)["Crop canvas"].firstMatch
        XCTAssertTrue(crop.waitForExistence(timeout: 3))
        crop.pinch(withScale: 1.2, velocity: 1)
        let dragStart = crop.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50))
        dragStart.press(forDuration: 0.12, thenDragTo: crop.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.45)))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["Crop keep editing"].waitForExistence(timeout: 8), "Foreground must request a decision for a dirty draft")
        attachScreenshot(named: "Tailor-crop-background-foreground-exit-decision")
        app.buttons["Crop discard"].firstMatch.tap()
    }

    /// Replacement must use the real PhotoPicker → document.replacePhoto
    /// route before entering Crop. The attachment is intentionally captured
    /// after that production mutation, not from an isolated fixture view.
    func testReplacePhotoThenCropProductionPathScreenshot() {
        launch(demoRoute: "editor", demoState: "crop-landscape")
        app.buttons["Page 5"].tap()
        let photo = app.descendants(matching: .any)["Photo element"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        photo.tap()
        app.buttons["Photo"].tap()
        let replacement = app.descendants(matching: .any)["Replace photo ui-timeline-photo-5-crop-landscape"].firstMatch
        // The production picker is a lazy List; the replacement fixture is
        // intentionally below the edit actions. Scroll its real UI rather
        // than shortcutting document.replacePhoto in the test.
        for _ in 0..<4 where !replacement.exists { app.swipeUp() }
        XCTAssertTrue(replacement.waitForExistence(timeout: 3))
        replacement.tap()
        let replaced = app.descendants(matching: .any)["Photo element"].firstMatch
        XCTAssertTrue(replaced.waitForExistence(timeout: 3))
        replaced.tap()
        app.buttons["Photo"].tap()
        XCTAssertTrue(app.buttons["Photo tool crop"].waitForExistence(timeout: 3))
        app.buttons["Photo tool crop"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Crop canvas"].firstMatch.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.7)
        attachScreenshot(named: "Tailor-crop-after-production-photo-replacement")
        app.buttons["Crop cancel bottom"].tap()
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

    private func launch(demoRoute: String? = nil, demoState: String? = nil) {
        if app.state != .notRunning { app.terminate() }
        app.launchArguments = ["-uiTesting"]
        if let demoRoute { app.launchArguments += ["-uiDemoRoute", demoRoute] }
        if let demoState { app.launchArguments += ["-uiDemoState", demoState] }
        app.launch()
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// `waitForExistence` reports early during a full-screen-cover animation.
    /// Capture evidence only once UIKit reports a genuinely tappable control,
    /// otherwise a whole-window screenshot can still contain a partial stage.
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists && element.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        } while Date() < deadline
        return element.exists && element.isHittable
    }

    private func marker(of element: XCUIElement) -> String {
        guard let marker = element.value as? String else {
            XCTFail("Expected transform marker on \(element)")
            return ""
        }
        return marker
    }

    private func unicodePayload(graphemeCount: Int) -> String {
        // One explicit break per 30 user-visible graphemes keeps the 240
        // boundary fixture inside its deliberately generous text frame. Thus
        // a red state in the +1 case is unambiguously the character-limit
        // rule, not an incidental line-wrap overflow.
        let units: [Character] = ["点", "你", "م", "ر", "ح", "ب", "ا", "👩‍👩‍👧‍👦", "e\u{301}", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "\n"]
        return String((0..<graphemeCount).map { units[$0 % units.count] })
    }

    private func assertCharacterCount(_ expected: String) {
        let counter = app.descendants(matching: .any)["Text character count"]
        XCTAssertTrue(counter.waitForExistence(timeout: 3), "Character count must be exposed through stable accessibility semantics")
        XCTAssertEqual(counter.value as? String, expected)
    }

    private func assertCharacterLimitError() {
        let error = app.descendants(matching: .any)["Text draft character limit error"]
        XCTAssertTrue(error.waitForExistence(timeout: 3), "An over-limit paste must expose an accessible correction error")
        XCTAssertEqual(error.value as? String, "invalid")
    }

    private func openMissingCaptionDraft() {
        app.buttons["Page 5"].tap()
        XCTAssertTrue(app.staticTexts["5 of 8"].waitForExistence(timeout: 3))
        app.buttons["Text"].tap()
        XCTAssertTrue(app.buttons["Add text field photoCaption"].waitForExistence(timeout: 3))
        app.buttons["Add text field photoCaption"].tap()
        XCTAssertTrue(app.textViews["Text draft input"].waitForExistence(timeout: 3))
    }

    private func openPersistedCaption() {
        XCTAssertTrue(app.buttons["Text"].waitForExistence(timeout: 3))
        app.buttons["Text"].tap()
        let caption = app.buttons["Text field photoCaption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 3))
        caption.tap()
        XCTAssertTrue(app.textViews["Text draft input"].waitForExistence(timeout: 3))
    }

    private func textSafetyMarker(_ element: XCUIElement) -> String {
        guard let value = element.value as? String else {
            XCTFail("Expected text safety marker")
            return ""
        }
        return value
    }

    private func assertSafeTextMarker(_ marker: String) {
        let fields = Dictionary(uniqueKeysWithValues: marker.split(separator: ";").compactMap { part -> (String, String)? in
            let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
            return pieces.count == 2 ? (pieces[0], pieces[1]) : nil
        })
        func rect(_ key: String) -> CGRect? {
            guard let value = fields[key] else { return nil }
            let values = value.split(separator: ",").compactMap { Double($0) }
            guard values.count == 4 else { return nil }
            return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
        }
        guard let x = Double(fields["x"] ?? ""), let y = Double(fields["y"] ?? ""),
              let width = Double(fields["width"] ?? ""), let height = Double(fields["height"] ?? ""),
              let editable = rect("editable") else {
            XCTFail("Malformed text safety marker: \(marker)")
            return
        }
        let frame = CGRect(x: x, y: y, width: width, height: height)
        XCTAssertTrue(editable.contains(frame), "Dragged text must remain inside editableSafeRect: \(marker)")
        let protected = (fields["protected"] ?? "").split(separator: "|").compactMap { raw -> CGRect? in
            let values = raw.split(separator: ",").compactMap { Double($0) }
            return values.count == 4 ? CGRect(x: values[0], y: values[1], width: values[2], height: values[3]) : nil
        }
        XCTAssertFalse(protected.isEmpty, "Fixture must expose footer and preview-watermark protected rectangles")
        XCTAssertFalse(protected.contains(where: frame.intersects), "Dragged text must not overlap footer, watermark, page number or fixed marks: \(marker)")
    }

    /// Uses the simulator pasteboard and the native edit menu rather than
    /// synthetic per-key typing. This exercises the production TextEditor
    /// insertion path where composed Unicode can otherwise be accidentally
    /// sliced by UTF-16 or scalar offsets.
    private func paste(_ value: String, into input: XCUIElement) {
        UIPasteboard.general.string = value
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()
        input.press(forDuration: 1.1)
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 3), "Native Paste action must be available for Unicode boundary validation")
        paste.tap()
    }

    private func selectedPhotoElement() -> XCUIElement {
        // The persisted image itself is the source of truth. Selection-only
        // accessibility overlays are recreated during full-screen-cover
        // dismissal, so using one for document readback makes an otherwise
        // valid Cancel race the overlay lifecycle.
        app.descendants(matching: .any)["Photo element"].firstMatch
    }

    private func persistedPhotoElement() -> XCUIElement {
        app.descendants(matching: .any)["Photo element"].firstMatch
    }

    private func cropCanvas() -> XCUIElement {
        app.descendants(matching: .any)["Crop canvas"].firstMatch
    }

}
