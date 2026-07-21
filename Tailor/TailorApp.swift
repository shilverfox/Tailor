import SwiftUI

@main
struct TailorApp: App {
    private let container: AppContainer

    init() {
        // UI automation must exercise the same feature flow without reaching
        // Photos, StoreKit, or a persisted user archive. The app remains on
        // production services for every normal launch.
        #if DEBUG
        container = ProcessInfo.processInfo.arguments.contains("-uiTesting")
            ? AppContainer.demo
            : AppContainer.makeProduction()
        #else
        container = AppContainer.makeProduction()
        #endif
    }

    var body: some Scene {
        WindowGroup { MilestoneRootView().environmentObject(container) }
    }
}

enum AppRoute: Int, CaseIterable, Hashable {
    case welcome, privacy, profile, references, scan, confirm, timeline, chapter, editor, preview, purchase, export, archive
    // v2 keeps the original route values stable for existing saved UI-test
    // fixtures while adding explicit product stages around the mature editor.
    case smartDraft, bookStyle, bookCheck, finalPreview, editorStyle, rechecking
}
