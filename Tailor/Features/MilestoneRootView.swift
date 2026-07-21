import SwiftUI
import Photos
import PhotosUI
import Vision
import ImageIO

struct MilestoneRootView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var route: AppRoute = .welcome; @State private var scope: PhotoAccessScope = .notDetermined; @State private var name = "Milo"; @State private var species: PetSpecies = .dog; @State private var year = "2024"; @State private var referenceAssetIdentifiers: [String] = []; @State private var profileID = UUID(); @State private var restoredDraft = false; @State private var hasSavedArchive = false; @State private var scanProgress = 0.0; @State private var scanCompletedAssets = 0; @State private var scanTotalAssets = 0; @State private var scanMatchCount = 0; @State private var paused = false; @State private var isScanning = false; @State private var scanDisplayState = ""; @State private var scanTask: Task<Void, Never>?; @State private var style: AlbumStyle = .warmPaper; @State private var pageSize: PDFPageSize = .letter; @State private var selectedChapterID: UUID?; @State private var purchased = false; @State private var isPurchasing = false; @State private var productDisplayPrice: String?; @State private var document: ArchiveDocument?; @State private var memoryBook: MemoryBookDocument?; @State private var operationError: String?; @State private var purchaseNotice: String?; @State private var exportURL: URL?; @State private var isExporting = false; @State private var exportCompletedPages = 0; @State private var exportTotalPages = 0; @State private var exportTask: Task<Void, Never>?; @State private var isPreparingSmartDraft = false; @State private var smartDraftError: String?; @State private var editorReturnRoute: AppRoute = .preview; @State private var bookCheckTarget: BookCheckNavigationTarget?; @State private var bookCheckFocusKey: String?; @State private var didInitializeRoot = false; @State private var realPhotoQADiagnostic = "not-started"; @StateObject private var photoLibrary = PhotoLibraryAccess()
    @State private var arrivalYear = ""
    @State private var previewLogicalPageID: UUID?
    @State private var finalPreviewLogicalPageID: UUID?
    @State private var editorInitialPageID: UUID?
    @State private var isLoadingProductPrice = false
    @State private var productPriceLoadFailed = false
    @State private var manualImportMode = false
    @State private var isCreatingBook = false
    @State private var editorStylePageID: UUID?

    var body: some View { Group { switch route {
    case .welcome: WelcomeFeatureView(hasSavedArchive: hasSavedArchive, next: advance, openArchives: { go(.archive) })
    case .privacy: PrivacyFeatureView(scope: $scope, photoLibrary: photoLibrary, next: { enterProfile(manual: false) }, manualImport: { enterProfile(manual: true) }, back: back)
    case .profile: ProfileFeatureView(name: $name, species: $species, arrivalYear: $arrivalYear, departureYear: $year, next: completeProfile, continueLater: saveProfileForLater, back: back)
    case .references:
        if isManualImportFlow {
            ManualImportFeatureView(manualAssets: document?.manualAssets ?? [], importItems: importManualItems, removeAsset: removeManualAsset, next: completeManualImport, continueLater: saveCurrentCheckpointForLater, back: back)
        } else {
            ReferencesFeatureView(referenceAssetIdentifiers: $referenceAssetIdentifiers, next: completeReferences, selectionChanged: persistReferenceSelection, continueLater: saveCurrentCheckpointForLater, back: back)
        }
    case .scan: ScanFeatureView(progress: $scanProgress, completedAssets: scanCompletedAssets, totalAssets: scanTotalAssets, matchCount: scanMatchCount, previewAssetIdentifiers: Array((document?.photos ?? []).prefix(4).map(\.assetLocalIdentifier)), displayState: scanDisplayState, paused: $paused, isScanning: isScanning, errorMessage: operationError, start: startScan, pause: pauseScan, next: completeScanReview, back: leaveScan)
    case .confirm: ReviewFeatureView(name: name, activeGenerationID: document?.activeRecognitionGeneration?.matchGenerationID, photos: photosBinding, next: beginSmartDraft, back: { go(isManualImportFlow ? .references : .scan) }, continueLater: saveCurrentCheckpointForLater, appendManualItems: isManualImportFlow ? importManualItems : nil, showsPendingTimelinePromptOnAppear: isPendingTimelineUITestFixture)
    case .smartDraft: SmartDraftFeatureView(summary: draftSummary, isPreparing: isPreparingSmartDraft, errorMessage: smartDraftError, continueToStory: continueToStoryPlan, retry: beginSmartDraft, useSimpleTimeline: useSimpleTimeline, continueLater: { persistDocument(); go(.archive) }, back: { go(.confirm) })
    case .timeline: TimelineFeatureView(name: name, chapters: chaptersBinding, photos: document?.photos ?? [], edit: { chapterID in selectedChapterID = chapterID; go(.chapter) }, next: confirmStoryPlan, continueLater: saveCurrentCheckpointForLater, back: { go(.smartDraft) })
    case .chapter: ChapterEditorFeatureView(chapters: chaptersBinding, photos: document?.photos ?? [], selectedChapterID: selectedChapterID, next: { persistDocument(); go(.timeline) }, back: { go(.timeline) })
    case .bookStyle: BookStyleFeatureView(style: $style, pageSize: $pageSize, book: memoryBook, isApplying: isCreatingBook, errorMessage: operationError, apply: applySelectedBookStyle, continueLater: saveCurrentCheckpointForLater, back: { go(memoryBook == nil ? .timeline : .preview) })
    case .editor: AlbumEditorFeatureView(memoryBook: $memoryBook, purchased: purchased || isPurchaseBypassed, back: closeEditor, preview: { persistDocument(); bookCheckTarget = nil; go(.preview) }, export: { persistDocument(); bookCheckTarget = nil; enterBookCheck() }, persist: persistDocument, openStyle: openEditorStyle, initialBookCheckTarget: bookCheckTarget, initialPageID: editorInitialPageID).onAppear { ensureMemoryBook() }
    case .editorStyle: EditorStyleFeatureView(book: $memoryBook, selectedPageID: editorStylePageID, apply: finishEditorStyle, cancel: cancelEditorStyle)
    case .preview: PreviewFeatureView(name: name, style: $style, pageSize: $pageSize, chapters: document?.chapters ?? [], photos: document?.photos ?? [], memoryBook: $memoryBook, selectedLogicalPageID: $previewLogicalPageID, purchased: purchased || isPurchaseBypassed, next: { persistDocument(); enterBookCheck() }, back: { go(.timeline) }, editPage: { pageID in openEditor(returningTo: .preview, pageID: pageID) }, changeStyle: { go(.bookStyle) }).onAppear { ensureMemoryBook() }.onChange(of: pageSize) { _, newSize in updateBookPageSize(newSize) }
    case .bookCheck: BookCheckFeatureView(book: $memoryBook, focusedIssueKey: $bookCheckFocusKey, editIssue: openBookCheckIssue, continueFlow: continueFromBookCheck, back: { go(.preview) }, persist: persistDocument).onAppear { ensureMemoryBook(); evaluateAndPersistBookCheck() }
    case .purchase: PurchaseFeatureView(revisionID: memoryBook?.documentRevisionID, paperSize: memoryBook?.pageSize ?? pageSize, displayPrice: productDisplayPrice, isLoadingPrice: isLoadingProductPrice, priceLoadFailed: productPriceLoadFailed, retryPrice: { Task { await loadProductPrice() } }, purchase: purchase, restore: restorePurchase, errorMessage: operationError, noticeMessage: purchaseNotice, isPurchasing: isPurchasing, next: { purchased = true; go(.finalPreview) }, back: { go(.bookCheck) }).task { guard let book = memoryBook, let checked = document?.cachedBookCheckResult(for: book), checked.status != .blocked else { go(.bookCheck); return }; if productDisplayPrice == nil { await loadProductPrice() } }
    case .finalPreview: PreviewFeatureView(name: name, style: $style, pageSize: $pageSize, chapters: document?.chapters ?? [], photos: document?.photos ?? [], memoryBook: $memoryBook, selectedLogicalPageID: $finalPreviewLogicalPageID, purchased: true, next: { persistDocument(); guard hasCurrentBookCheckPass else { enterBookCheck(); return }; go(.export) }, back: { openEditor(returningTo: .finalPreview, pageID: finalPreviewLogicalPageID) }, editPage: { pageID in openEditor(returningTo: .finalPreview, pageID: pageID) }, changeStyle: { go(.bookStyle) }).onAppear { ensureMemoryBook(); if !hasCurrentBookCheckPass && !isUITestFixtureSession { enterBookCheck() } }.onChange(of: pageSize) { _, newSize in updateBookPageSize(newSize) }
    case .rechecking: LatestEditsCheckingView()
    case .export: ExportFeatureView(name: name, exportURL: exportURL, exportRecord: latestExportRecord, memoryBook: memoryBook ?? document?.memoryBook, errorMessage: operationError, isExporting: isExporting, completedPages: exportCompletedPages, totalPages: exportTotalPages, createPDF: exportPDF, cancelPDF: cancelExport, done: { go(.archive) }, back: { go(.finalPreview) }).onAppear { ensureMemoryBook() }
    case .archive: ArchivesFeatureView(name: name, pdfURL: storedPDFURL, exportRecord: latestExportRecord, resumeActionLabel: document?.archiveCheckpoint?.resumeRoute.actionLabel ?? "Continue archive", canRescan: document?.archiveCheckpoint?.stage == .documentReady, openArchive: resumeArchive, rescan: rescanArchive, restart: restartArchive, delete: deleteArchive)
    } }
    .animation(.easeInOut(duration: 0.2), value: route)
    .overlay(alignment: .topLeading) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiRealPhotoQA") {
            Text(realPhotoQADiagnostic)
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .clipped()
                .accessibilityIdentifier("M7 real photo diagnostic")
        }
        #endif
    }
    .task {
        guard !didInitializeRoot else { return }
        didInitializeRoot = true
        guard !configureUITestDemoIfRequested() else { return }
        guard !(await configureRealPhotoQAIfRequested()) else { return }
        await restoreLatestDraftIfNeeded()
        if isPurchaseBypassed { purchased = true }
        else { purchased = await container.purchase.isEntitled() }
    }
    .onChange(of: scenePhase) { _, phase in
        // v1 scans only while the user keeps Tailor active. Persisted
        // checkpoints make this a resumable pause instead of allowing work to
        // continue unpredictably while the app is backgrounded or locked.
        if phase != .active, isScanning { pauseScan() }
        // StoreKit may complete an Ask to Buy or out-of-app transaction while
        // Tailor is suspended. UI fixtures deliberately remain isolated.
        guard phase == .active,
              !isPurchaseBypassed,
              !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
        Task {
            photoLibrary.refresh()
            await reconcileManualAssetsIfAuthorized()
            purchased = await container.purchase.isEntitled()
        }
    }

    }

    /// Debug/test-only escape hatch for running the complete local flow. The
    /// production StoreKit path is unchanged when the launch argument is absent.
    private var isPurchaseBypassed: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // The bypass is reachable only from an explicit UI-automation session.
        // Ordinary Debug launches, TestFlight and App Store builds all use StoreKit.
        return arguments.contains("-uiTesting") && arguments.contains("-uiBypassPurchase")
        #else
        return false
        #endif
    }

    private var isUITestFixtureSession: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
        #else
        false
        #endif
    }

    private var hasCurrentBookCheckPass: Bool {
        guard let book = memoryBook,
              let result = document?.cachedBookCheckResult(for: book) else { return false }
        return result.status != .blocked
    }

    private var isPendingTimelineUITestFixture: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting"),
              let stateIndex = arguments.firstIndex(of: "-uiDemoState"),
              arguments.indices.contains(stateIndex + 1) else { return false }
        return arguments[stateIndex + 1] == "review-pending-gate"
    }

    private var storedPDFURL: URL? {
        if let recorded = document?.exportRecords
            .filter({ !$0.watermarked && FileManager.default.fileExists(atPath: $0.fileURL.path) })
            .max(by: { $0.exportedAt < $1.exportedAt }) {
            return recorded.fileURL
        }
        // Compatibility fallback for PDFs created before ExportRecord existed.
        let prefix = "\(profileID.uuidString)-life-archive"
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: .documentsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let latest = urls
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension.lowercased() == "pdf" }
            .max { lhs, rhs in
                let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate < rightDate
            }
        return latest ?? exportURL
    }

    private var latestExportRecord: MemoryBookExportRecord? {
        document?.exportRecords
            .filter { !$0.watermarked }
            .max(by: { $0.exportedAt < $1.exportedAt })
    }

    private func advance() {
        guard let next = AppRoute(rawValue: route.rawValue + 1) else { return }
        go(next)
    }
    private func back() { guard let previous = AppRoute(rawValue: route.rawValue - 1) else { return }; go(previous) }
    private func leaveScan() {
        if isScanning { pauseScan() }
        back()
    }
    private func go(_ newRoute: AppRoute) { route = newRoute; container.router.navigate(to: newRoute) }

    private var isManualImportFlow: Bool {
        manualImportMode || scope == .denied || scope == .restricted || !(document?.manualAssets.isEmpty ?? true)
    }

    private func enterProfile(manual: Bool) {
        manualImportMode = manual
        let profile = PetProfile(id: profileID, name: name, species: species, arrivalYear: Int(arrivalYear), departureYear: Int(year) ?? Calendar.current.component(.year, from: .now), lifecycle: .draft, albumStyle: style)
        var value = document ?? ArchiveDocument(profile: profile)
        value.profile = profile
        commit(value, checkpoint: .profile, route: .profile)
    }

    private func completeProfile() {
        let profile = PetProfile(id: profileID, name: name.trimmingCharacters(in: .whitespacesAndNewlines), species: species, arrivalYear: Int(arrivalYear), departureYear: Int(year) ?? Calendar.current.component(.year, from: .now), lifecycle: .draft, referenceAssetIdentifiers: referenceAssetIdentifiers, albumStyle: style)
        var value = document ?? ArchiveDocument(profile: profile)
        value.profile = profile
        commit(value, checkpoint: .references, route: .references)
    }

    private func saveProfileForLater() {
        let profile = PetProfile(id: profileID, name: name.trimmingCharacters(in: .whitespacesAndNewlines), species: species, arrivalYear: Int(arrivalYear), departureYear: Int(year) ?? Calendar.current.component(.year, from: .now), lifecycle: .draft, referenceAssetIdentifiers: referenceAssetIdentifiers, albumStyle: style)
        var value = document ?? ArchiveDocument(profile: profile)
        value.profile = profile
        commit(value, checkpoint: .profile, route: .archive)
    }

    private func persistReferenceSelection() {
        guard var value = document else { return }
        value.profile.referenceAssetIdentifiers = referenceAssetIdentifiers
        value.archiveCheckpoint = ArchiveCheckpoint(stage: .references)
        value.updatedAt = .now
        document = value
        persistDocument()
    }

    private func saveCurrentCheckpointForLater() {
        guard let value = document else { go(.archive); return }
        commit(value, checkpoint: value.archiveCheckpoint?.stage ?? .profile, route: .archive)
    }

    private func completeReferences() {
        guard var value = document, referenceAssetIdentifiers.count >= 3 else { return }
        value.profile.referenceAssetIdentifiers = referenceAssetIdentifiers
        commit(value, checkpoint: .scan, route: .scan)
    }

    private func completeManualImport() {
        guard let value = document, value.manualAssets.count >= 3 else { return }
        commit(value, checkpoint: .review, route: .confirm)
    }

    private func completeScanReview() {
        guard let value = document else { return }
        commit(value, checkpoint: .review, route: .confirm)
    }

    private func commit(_ source: ArchiveDocument, checkpoint stage: ArchiveCheckpointStage, route destination: AppRoute? = nil) {
        var value = source
        value.archiveCheckpoint = ArchiveCheckpoint(stage: stage)
        value.updatedAt = .now
        Task { @MainActor in
            do {
                try await container.repository.save(document: value)
                document = value
                memoryBook = value.memoryBook
                hasSavedArchive = true
                if let destination { go(destination) }
            } catch { operationError = error.localizedDescription }
        }
    }

    private func resumeArchive() {
        guard let resume = document?.archiveCheckpoint?.resumeRoute else { go(.profile); return }
        let destination: AppRoute = switch resume {
        case .profile: .profile
        case .references: .references
        case .scan: .scan
        case .photoReview: .confirm
        case .smartDraft: .smartDraft
        case .storyPlan: .timeline
        case .bookStyle: .bookStyle
        case .bookPreview: .preview
        }
        go(destination)
    }

    /// UI automation only: `-uiTesting -uiDemoRoute <route>` supplies local, deterministic
    /// content so every product screen can be rendered without Photos, Vision, or StoreKit.
    /// Production launches never enter this branch.
    private func configureUITestDemoIfRequested() -> Bool {
        #if !DEBUG
        return false
        #else
        let arguments = ProcessInfo.processInfo.arguments
        let routes: [String: AppRoute] = [
            "welcome": .welcome, "privacy": .privacy, "profile": .profile, "references": .references,
            "scan": .scan, "confirm": .confirm, "timeline": .timeline, "chapter": .chapter, "editor": .editor,
            "preview": .preview, "purchase": .purchase, "export": .export, "archive": .archive,
            "smartDraft": .smartDraft, "bookStyle": .bookStyle, "bookCheck": .bookCheck, "finalPreview": .finalPreview,
            "editorStyle": .editorStyle, "rechecking": .rechecking
        ]
        guard arguments.contains("-uiTesting"),
              let routeIndex = arguments.firstIndex(of: "-uiDemoRoute"),
              arguments.indices.contains(routeIndex + 1),
              let requestedRoute = routes[arguments[routeIndex + 1]] else { return false }
        let demoState: String
        if let stateIndex = arguments.firstIndex(of: "-uiDemoState"), arguments.indices.contains(stateIndex + 1) {
            demoState = arguments[stateIndex + 1]
        } else {
            demoState = ""
        }
        // Visual QA may choose a template and paper independently of the
        // route. These switches only exist behind `-uiTesting`; production
        // continues to load the user's persisted style and size.
        let demoStyle: AlbumStyle = {
            guard let index = arguments.firstIndex(of: "-uiDemoStyle"), arguments.indices.contains(index + 1) else { return .warmPaper }
            return AlbumStyle(rawValue: arguments[index + 1]) ?? .warmPaper
        }()
        let demoPaper: PDFPageSize = {
            guard let index = arguments.firstIndex(of: "-uiDemoPaper"), arguments.indices.contains(index + 1) else { return .letter }
            return PDFPageSize(rawValue: arguments[index + 1]) ?? .letter
        }()

        let demoProfile = PetProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Milo",
            species: .dog,
            arrivalYear: 2017,
            departureYear: 2024,
            lifecycle: requestedRoute == .archive ? .exported : .ready,
            referenceAssetIdentifiers: ["ui-reference-1", "ui-reference-2", "ui-reference-3"],
            albumStyle: demoStyle
        )
        let isFocalCropFixture = demoState == "crop-landscape-focal-right"
        let firstPhoto = ArchivePhoto(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            assetLocalIdentifier: demoState.hasPrefix("crop-") ? "ui-timeline-photo-0-\(demoState)" : "ui-photo-1",
            decision: .selected,
            confidence: 0.96,
            createdAt: .now,
            pixelSize: demoState.hasPrefix("crop-landscape")
                ? CGSize(width: 1_600, height: 900)
                : ((demoState == "crop-portrait-plus15" || demoState == "crop-portrait-minus15")
                    ? CGSize(width: 900, height: 1_600)
                    : (demoState == "crop-square-plus15" ? CGSize(width: 1_200, height: 1_200) : nil)),
            subjectRegion: isFocalCropFixture ? CGRect(x: 0.72, y: 0.30, width: 0.20, height: 0.34) : nil
        )
        let uncertainPhoto = ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, assetLocalIdentifier: "ui-photo-2", decision: .pending, confidence: 0.62, createdAt: .now)
        let excludedPhoto = ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!, assetLocalIdentifier: "ui-photo-3", decision: .excluded, confidence: 0.22, createdAt: .now)
        let chapter = Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, title: "Days together", dateLabel: "2018–2024", photoIDs: [firstPhoto.id], isHidden: false, sortOrder: 0)

        profileID = demoProfile.id
        name = demoProfile.name
        species = demoProfile.species
        year = String(demoProfile.departureYear)
        // The privacy reference state represents first launch. Other direct
        // route fixtures retain limited access so they never request Photos.
        scope = (requestedRoute == .privacy && demoState == "denied") || demoState == "manual" ? .denied : (requestedRoute == .privacy ? .notDetermined : .limited)
        referenceAssetIdentifiers = demoProfile.referenceAssetIdentifiers
        var demoPhotos = [firstPhoto, uncertainPhoto, excludedPhoto]
        var demoChapters = [chapter]
        if requestedRoute == .confirm && demoState.isEmpty {
            let additionalHigh = ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!, assetLocalIdentifier: "ui-high-2", decision: .selected, confidence: 0.91, createdAt: .now)
            let pending = (0..<110).map { index in
                ArchivePhoto(id: UUID(), assetLocalIdentifier: "ui-review-\(index + 1)", decision: .pending, confidence: index == 0 ? 0.62 : 0.58, createdAt: .now)
            }
            demoPhotos = [firstPhoto, additionalHigh] + pending
        }
        if [.smartDraft, .timeline, .chapter, .bookStyle, .editor, .preview, .bookCheck, .purchase, .finalPreview, .export, .archive].contains(requestedRoute) {
            let cropFixtureSize: CGSize? = switch demoState {
            case "crop-landscape", "crop-landscape-focal-right": CGSize(width: 1_600, height: 900)
            case "crop-portrait-plus15", "crop-portrait-minus15": CGSize(width: 900, height: 1_600)
            case "crop-square-plus15": CGSize(width: 1_200, height: 1_200)
            default: nil
            }
            let timelinePhotos = (0..<5).map { index in
                ArchivePhoto(
                    id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 31 + index))!,
                    assetLocalIdentifier: demoState.hasPrefix("crop-") ? "ui-timeline-photo-\(index + 1)-\(demoState)" : "ui-timeline-photo-\(index + 1)",
                    decision: .selected,
                    confidence: 0.94,
                    createdAt: .now,
                    pixelSize: cropFixtureSize
                )
            }
            demoPhotos = [firstPhoto] + timelinePhotos
            demoChapters = [
                Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, title: "Days together", dateLabel: "2018–2019", photoIDs: [firstPhoto.id, timelinePhotos[0].id, timelinePhotos[1].id], isHidden: false, sortOrder: 0),
                Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!, title: "Days together", dateLabel: "2023", photoIDs: [timelinePhotos[2].id, timelinePhotos[3].id], isHidden: false, sortOrder: 1)
            ]
        }
        // Deterministic UI-only fixtures for the preview boundary. They do not
        // alter real archive data or purchase state outside `-uiTesting`.
        if requestedRoute == .preview, demoState == "preview-insufficient" {
            demoChapters = [
                Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, title: "Days together", dateLabel: "2018–2019", photoIDs: [firstPhoto.id], isHidden: false, sortOrder: 0)
            ]
        }
        if requestedRoute == .preview, demoState == "preview-odd-purchased" {
            // 3 structural pages + two chapter/photo pairs + a final empty
            // chapter + closing = 9. This exercises a lone final landscape
            // page without changing production book construction.
            demoChapters.append(
                Chapter(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000023")!,
                    title: "A quiet year",
                    dateLabel: "2024",
                    photoIDs: [],
                    isHidden: false,
                    sortOrder: 2
                )
            )
        }
        if requestedRoute == .preview, demoState == "preview-sample-truncated" {
            // Five chapters make a full book larger than the free sample. The
            // third Contents entry is deliberately absent from that sample.
            demoChapters = [
                Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, title: "First days", dateLabel: "2018", photoIDs: [firstPhoto.id], isHidden: false, sortOrder: 0),
                Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!, title: "Days together", dateLabel: "2019", photoIDs: [firstPhoto.id], isHidden: false, sortOrder: 1),
                Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000023")!, title: "A long summer", dateLabel: "2020", photoIDs: [firstPhoto.id], isHidden: false, sortOrder: 2),
                Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000024")!, title: "Small adventures", dateLabel: "2022", photoIDs: [firstPhoto.id], isHidden: false, sortOrder: 3),
                Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000025")!, title: "Kept close", dateLabel: "2024", photoIDs: [firstPhoto.id], isHidden: false, sortOrder: 4)
            ]
        }
        if requestedRoute == .confirm, demoState == "review-batch" {
            demoPhotos += [
                ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!, assetLocalIdentifier: "ui-photo-4", decision: .pending, confidence: 0.69, createdAt: .now),
                ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!, assetLocalIdentifier: "ui-photo-5", decision: .pending, confidence: 0.58, createdAt: .now)
            ]
        }
        // A deterministic post-review state for the complete archive-flow
        // regression. Batch approval itself has dedicated tests; this fixture
        // starts at the exact hand-off contract where every chosen photo is
        // confirmed and timeline creation must proceed without another prompt.
        if requestedRoute == .confirm, demoState == "review-ready" {
            // This is the real hand-off state from 06 to Smart Draft, not a
            // visually similar shortcut: the production planner requires at
            // least three eligible, confirmed moments before it will create a
            // draft. Keep every photo selected and safety-approved so the
            // complete 06 → 07 → 08 → 09 route remains executable in UI tests.
            let thirdConfirmed = ArchivePhoto(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!,
                assetLocalIdentifier: "ui-photo-4",
                decision: .selected,
                confidence: 0.89,
                createdAt: .now,
                sensitivityState: .normal
            )
            demoPhotos = [firstPhoto, uncertainPhoto, thirdConfirmed]
            demoPhotos[1].decision = .selected
            demoPhotos[1].sensitivityState = .normal
        }
        if requestedRoute == .confirm, demoState == "review-sensitive" {
            demoPhotos.append(ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!, assetLocalIdentifier: "ui-photo-6", decision: .pending, confidence: 0.51, createdAt: .now, sensitivityState: .sensitive))
        }
        if requestedRoute == .confirm, demoState == "review-stale" {
            demoPhotos.append(ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000017")!, assetLocalIdentifier: "ui-photo-stale", decision: .pending, confidence: 0.88, createdAt: .now, staleDecision: .selected))
        }
        if requestedRoute == .preview, demoState == "single-period-six-pages" {
            let periodPhotos = (0..<3).map { index in
                ArchivePhoto(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 81 + index))!, assetLocalIdentifier: "ui-single-period-\(index)", decision: .selected, confidence: 0.94, createdAt: .now)
            }
            demoPhotos = periodPhotos
            demoChapters = [Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000081")!, title: "One season together", dateLabel: "2024", photoIDs: periodPhotos.map(\.id), isHidden: false, sortOrder: 0)]
        }
        let demoExportRecords: [MemoryBookExportRecord] = [.export, .archive].contains(requestedRoute)
            ? [MemoryBookExportRecord(
                fileName: "Milo-Life-Archive.pdf",
                exportedAt: Date(timeIntervalSince1970: 1_752_675_600),
                pageCount: 8,
                pageSize: .letter,
                watermarked: false
            )]
            : []
        document = ArchiveDocument(profile: demoProfile, photos: demoPhotos, chapters: demoChapters, exportRecords: demoExportRecords)
        if demoState == "visual-fixture", [.editor, .preview, .finalPreview].contains(requestedRoute) {
            let fixture = MemoryBookVisualQAFixture.make(style: demoStyle, paper: demoPaper)
            // A UI-test-only replacement. Production routes never enter this
            // branch, and both surfaces bind to this exact document instance.
            document = ArchiveDocument(profile: fixture.profile, photos: fixture.photos, chapters: fixture.chapters, memoryBook: fixture)
            memoryBook = fixture
            name = fixture.profile.name
        }
        if demoState == "production-default-fixture", [.editor, .preview, .finalPreview].contains(requestedRoute) {
            let fixture = MemoryBookProductionDefaultFixture.make(style: demoStyle, paper: demoPaper)
            document = ArchiveDocument(profile: fixture.profile, photos: fixture.photos, chapters: fixture.chapters, memoryBook: fixture)
            memoryBook = fixture
            name = fixture.profile.name
        }
        if requestedRoute == .purchase, demoState.hasPrefix("purchase-") {
            // Payment is guarded by the same cache key as production: current
            // revision + current paper + current rules version.  Build a
            // fully-valid deterministic document and persist the evaluated
            // result rather than bypassing the Purchase route's Book Check
            // gate. This keeps failure/cancel/offline UI independently
            // testable while preserving the normal redirect for stale checks.
            let fixture = MemoryBookVisualQAFixture.make(style: demoStyle, paper: demoPaper)
            var purchaseDocument = ArchiveDocument(
                profile: fixture.profile,
                photos: fixture.photos,
                chapters: fixture.chapters,
                memoryBook: fixture
            )
            let result = BookCheckWorkflow.evaluate(fixture, assetIsAvailable: PhotoAssetAvailability.isAvailable)
            purchaseDocument.storeBookCheckResult(result)
            document = purchaseDocument
            memoryBook = fixture
            name = fixture.profile.name
            profileID = fixture.profile.id
        }
        selectedChapterID = demoChapters.first?.id
        scanProgress = requestedRoute == .scan ? 0.42 : 1; scanCompletedAssets = requestedRoute == .scan ? 1_426 : 100; scanTotalAssets = requestedRoute == .scan ? 4_281 : 100; scanMatchCount = requestedRoute == .scan ? 39 : 2
        paused = requestedRoute == .scan
        scanDisplayState = requestedRoute == .scan ? demoState : ""
        isScanning = false
        if requestedRoute == .scan {
            switch demoState {
            case "running": paused = false; isScanning = true
            case "paused": paused = true
            case "interrupted": paused = true
            case "lowBattery": paused = false; operationError = "Battery is low. You can pause now and continue later."
            case "failed": paused = false; operationError = "We couldn’t finish this scan. Your references and reviewed photos are still here."
            case "complete": paused = false; scanProgress = 1; scanCompletedAssets = 4_281
            default: break
            }
        }
        style = demoStyle
        pageSize = demoPaper
        purchased = isPurchaseBypassed || demoState == "visual-fixture" || demoState == "production-default-fixture" || requestedRoute == .finalPreview || (requestedRoute == .preview && ["preview-purchased", "preview-odd-purchased"].contains(demoState))
        if requestedRoute != .scan || demoState.isEmpty { operationError = nil }
        // Export and archive demo routes represent the post-render state so
        // UI tests and visual review can exercise the real completion CTA
        // without depending on a simulator PhotoKit/PDF write.
        exportURL = requestedRoute == .export && demoState != "export-failed" && demoState != "exporting"
            ? URL.documentsDirectory.appending(path: "Milo-Life-Archive.pdf")
            : nil
        isExporting = requestedRoute == .export && demoState == "exporting"
        exportCompletedPages = 0
        exportTotalPages = isExporting ? 8 : 0
        if requestedRoute == .export && demoState == "export-failed" {
            operationError = "We couldn’t save the PDF. Your archive is still here."
        }
        if requestedRoute == .purchase, demoState == "purchase-failed" {
            operationError = "Your purchase could not be completed. Your album is still here."
        }
        route = requestedRoute
        container.router.reset()
        if requestedRoute != .welcome { container.router.navigate(to: requestedRoute) }
        return true
        #endif
    }

    /// Debug-only bridge from the simulator's real Photos library into the
    /// normal book/editor renderer. Unlike the deterministic UI fixtures this
    /// keeps PhotoKit identifiers and source pixels intact. It is intentionally
    /// The asset reads are synchronous only after the normal system permission
    /// boundary has completed because the four local QA assets are downloaded.
    private func configureRealPhotoQAIfRequested() async -> Bool {
        #if !DEBUG
        return false
        #else
        guard ProcessInfo.processInfo.arguments.contains("-uiRealPhotoQA") else { return false }
        var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        realPhotoQADiagnostic = "authorization=\(authorization.rawValue);requesting=\(authorization == .notDetermined)"
        if authorization == .notDetermined {
            authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        let fetched = PHAsset.fetchAssets(with: .image, options: nil)
        realPhotoQADiagnostic = "authorization=\(authorization.rawValue);assets=\(fetched.count)"
        var inputs: [(name: String, asset: PHAsset)] = []
        fetched.enumerateObjects { asset, _, _ in
            let name = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? asset.localIdentifier
            if (name as NSString).pathExtension.lowercased() == "png" {
                inputs.append((name, asset))
            }
        }
        inputs.sort {
            let leftDate = $0.asset.creationDate ?? .distantPast
            let rightDate = $1.asset.creationDate ?? .distantPast
            return leftDate == rightDate
                ? $0.asset.localIdentifier < $1.asset.localIdentifier
                : leftDate < rightDate
        }
        var uniqueInputs: [(name: String, asset: PHAsset)] = []
        var seenImageData = Set<Data>()
        for input in inputs.reversed() {
            guard let data = realPhotoQAImageData(for: input.asset), seenImageData.insert(data).inserted else { continue }
            uniqueInputs.append(input)
            if uniqueInputs.count == 4 { break }
        }
        inputs = Array(uniqueInputs.reversed())
        guard inputs.count == 4 else {
            realPhotoQADiagnostic += ";png=\(inputs.count);selected=0"
            return false
        }
        realPhotoQADiagnostic += ";pngUnique=\(inputs.count);selected=\(inputs.count)"

        let qaProfile = PetProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000009001")!,
            name: "Milo",
            species: .dog,
            arrivalYear: 2017,
            departureYear: 2024,
            lifecycle: .ready,
            albumStyle: .warmPaper
        )
        let qaPhotos = inputs.enumerated().map { index, input in
            ArchivePhoto(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 9_100 + index))!,
                assetLocalIdentifier: input.asset.localIdentifier,
                decision: .selected,
                confidence: 1,
                createdAt: input.asset.creationDate ?? Date(timeIntervalSince1970: 1_704_067_200 + TimeInterval(index * 86_400)),
                pixelSize: CGSize(width: input.asset.pixelWidth, height: input.asset.pixelHeight),
                subjectRegion: realPhotoQASubjectRegion(for: input.asset)
            )
        }
        let focalRegions = qaPhotos.enumerated().map { index, photo in
            guard let region = photo.subjectRegion else { return "p\(index)=none" }
            return String(format: "p%d=%.3f,%.3f", index, region.midX, region.midY)
        }.joined(separator: "|")
        let qaChapter = Chapter(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000009201")!,
            title: "Days together",
            dateLabel: "Photorealistic QA",
            photoIDs: qaPhotos.map(\.id),
            isHidden: false,
            sortOrder: 0
        )
        let qaBook = MemoryBookBuilder.build(
            profile: qaProfile,
            photos: qaPhotos,
            chapters: [qaChapter],
            style: .warmPaper,
            pageSize: .letter
        )
        let cropOffsets = qaBook.pages
            .flatMap(\.elements)
            .filter { element in element.kind == .image && qaPhotos.contains(where: { $0.id == element.assetID }) }
            .map { String(format: "%.3f,%.3f", $0.cropOffset.width, $0.cropOffset.height) }
            .joined(separator: "|")
        realPhotoQADiagnostic += ";focal=\(focalRegions);offsets=\(cropOffsets)"
        profileID = qaProfile.id
        name = qaProfile.name
        species = qaProfile.species
        year = String(qaProfile.departureYear)
        scope = .full
        style = qaBook.style
        pageSize = qaBook.pageSize
        selectedChapterID = qaChapter.id
        document = ArchiveDocument(profile: qaProfile, photos: qaPhotos, chapters: [qaChapter], memoryBook: qaBook)
        memoryBook = qaBook
        purchased = true
        route = .editor
        container.router.reset()
        container.router.navigate(to: .editor)
        return true
        #endif
    }

    #if DEBUG
    private func realPhotoQAImageData(for asset: PHAsset) -> Data? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        var result: Data?
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            result = data
        }
        return result
    }

    private func realPhotoQASubjectRegion(for asset: PHAsset) -> CGRect? {
        guard let data = realPhotoQAImageData(for: asset),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        do {
            return try VisionFocalRegionDetector.animalRecognition(in: cgImage, preferredSpecies: nil).subjectRegion
        } catch {
            realPhotoQADiagnostic += ";visionError=\(error.localizedDescription)"
            return nil
        }
    }
    #endif

    private func saveDraft() async {
        let profile = PetProfile(
            id: profileID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            species: species,
            arrivalYear: Int(arrivalYear),
            departureYear: Int(year) ?? Calendar.current.component(.year, from: .now),
            lifecycle: .draft,
            referenceAssetIdentifiers: referenceAssetIdentifiers,
            albumStyle: style
        )
        var updated = document ?? ArchiveDocument(profile: profile)
        updated.profile = profile
        updated.updatedAt = .now
        document = updated
        try? await container.repository.save(document: updated)
    }

    private func importManualItems(_ items: [PhotosPickerItem]) async throws -> Int {
        guard var value = document else { return 0 }
        let remaining = max(0, 500 - value.manualAssets.count)
        guard remaining > 0 else { return value.manualAssets.count }
        let imported = try await ManualAssetStore.importItems(Array(items.prefix(remaining)), profileID: value.id)
        let knownFingerprints = Set(value.manualAssets.map(\.contentFingerprint))
        let additions = imported.filter { !knownFingerprints.contains($0.asset.contentFingerprint) }
        for duplicate in imported where knownFingerprints.contains(duplicate.asset.contentFingerprint) {
            try? FileManager.default.removeItem(at: ManualAssetStore.url(for: duplicate.asset.relativePath))
        }
        value.manualAssets.append(contentsOf: additions.map(\.asset))
        value.photos.append(contentsOf: additions.map(\.photo))
        value.recognitionFeedback = .make(from: value.photos)
        value.archiveCheckpoint = ArchiveCheckpoint(stage: route == .confirm ? .review : .references)
        value.updatedAt = .now
        try await container.repository.save(document: value)
        document = value
        manualImportMode = true
        return value.manualAssets.count
    }

    private func removeManualAsset(_ id: UUID) {
        guard var value = document, let asset = value.manualAssets.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: ManualAssetStore.url(for: asset.relativePath))
        value.manualAssets.removeAll { $0.id == id }
        value.photos.removeAll { $0.manualAssetID == id }
        value.archiveCheckpoint = ArchiveCheckpoint(stage: .references)
        value.updatedAt = .now
        document = value
        persistDocument()
    }

    private func restoreLatestDraftIfNeeded() async {
        guard !restoredDraft else { return }
        restoredDraft = true
        scope = photoLibrary.scope
        guard let profile = try? await container.repository.allProfiles().first else { return }
        profileID = profile.id
        name = profile.name
        species = profile.species
        arrivalYear = profile.arrivalYear.map(String.init) ?? ""
        year = String(profile.departureYear)
        referenceAssetIdentifiers = profile.referenceAssetIdentifiers
        style = profile.albumStyle
        document = try? await container.repository.document(id: profile.id)
        manualImportMode = !(document?.manualAssets.isEmpty ?? true)
        memoryBook = document?.memoryBook
        if let memoryBook { pageSize = memoryBook.pageSize }
        hasSavedArchive = document != nil
        await reconcileManualAssetsIfAuthorized()
        if document?.profile.lifecycle == .exported, storedPDFURL != nil { exportURL = storedPDFURL }
        if let checkpoint = document?.scanCheckpoint, document?.profile.lifecycle == .scanning {
            scanCompletedAssets = checkpoint.progress.completedAssets; scanTotalAssets = checkpoint.progress.totalAssets; scanMatchCount = checkpoint.candidates.count; scanProgress = Double(checkpoint.progress.completedAssets) / Double(max(checkpoint.progress.totalAssets, 1))
            paused = true
            // Recovery is user-driven from Archive. Restoring must never
            // silently restart an expensive operation.
        }
    }

    private var photosBinding: Binding<[ArchivePhoto]> { Binding(get: { document?.photos ?? [] }, set: { updatePhotos($0) }) }

    @MainActor
    private func reconcileManualAssetsIfAuthorized() async {
        guard var value = document else { return }
        let pending = value.manualAssets.filter { $0.copyState == .privateCopy }
        guard !pending.isEmpty else { return }
        photoLibrary.refresh()
        let mappings = await photoLibrary.fingerprintMappings(for: Set(pending.map(\.contentFingerprint)))
        guard !mappings.isEmpty else { return }
        ManualAssetStore.applyingMappings(mappings, to: &value, deleteCopies: false)
        do {
            try await container.repository.save(document: value)
            ManualAssetStore.deleteMappedCopies(in: value)
            document = value
        } catch {
            operationError = "Mapped photos were found, but Tailor could not save the updated references. The private copies were kept for recovery."
        }
    }
    private var chaptersBinding: Binding<[Chapter]> { Binding(get: { document?.storyPlanDraft?.chapters ?? document?.chapters ?? [] }, set: { updateChapters($0) }) }
    private func updatePhotos(_ photos: [ArchivePhoto]) {
        guard var value = document else { return }
        value.photos = photos
        value.recognitionFeedback = .make(from: photos)
        // Review decisions take effect immediately. This removes a newly sensitive or
        // never-use asset from every chapter, including the first (cover) position.
        let eligibleIDs = Set(photos.filter(\.isEligibleForArchive).map(\.id))
        value.chapters = value.chapters.map { chapter in
            var safeChapter = chapter
            safeChapter.photoIDs = chapter.photoIDs.filter { eligibleIDs.contains($0) }
            return safeChapter
        }
        value.updatedAt = .now
        document = value
        if var book = memoryBook {
            let oldByID = Dictionary(uniqueKeysWithValues: book.photos.map { ($0.id, $0) })
            let changedIDs = Set(photos.compactMap { oldByID[$0.id] == $0 ? nil : $0.id })
                .union(oldByID.keys.filter { id in !photos.contains(where: { $0.id == id }) })
            book.photos = photos
            book.chapters = value.chapters
            for index in book.pages.indices where !book.pages[index].isLocked && !changedIDs.isDisjoint(with: book.pages[index].photoIDs) {
                book.pages[index].needsReflow = true
            }
            book.documentRevisionID = UUID()
            book.updatedAt = .now
            memoryBook = book
        }
        persistDocument()
    }
    private func updateChapters(_ chapters: [Chapter]) {
        guard var value = document else { return }
        let oldChapters = value.storyPlanDraft?.chapters ?? value.chapters
        let oldByID = Dictionary(uniqueKeysWithValues: oldChapters.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: chapters.map { ($0.id, $0) })
        let affected = Set(oldByID.keys).union(newByID.keys).filter { oldByID[$0] != newByID[$0] }
        if var draft = value.storyPlanDraft {
            draft.replaceChapters(chapters)
            value.storyPlanDraft = draft
        } else {
            value.chapters = chapters
        }
        value.updatedAt = .now
        document = value
        if var book = memoryBook {
            book.chapters = chapters
            _ = book.markPagesNeedsReflow(chapterIDs: Set(affected))
            book.updatedAt = .now
            memoryBook = book
        }
        persistDocument()
    }

    private func openEditor(returningTo route: AppRoute, pageID: UUID? = nil) {
        persistDocument()
        editorReturnRoute = route
        editorInitialPageID = pageID
        bookCheckTarget = nil
        pushReturnContext(source: route == .finalPreview ? .finalPreview : .bookPreview, pageID: pageID, issue: nil)
        go(.editor)
    }

    /// Page-editor Style is a real child return frame, never an editor sheet.
    /// That makes Apply and Cancel strictly return to the same editor instance
    /// while preserving the Preview/Check/Final frame below it.
    private func openEditorStyle() {
        let pageID = editorInitialPageID ?? previewLogicalPageID ?? finalPreviewLogicalPageID
        editorStylePageID = pageID
        pushReturnContext(source: .pageEditorStyle, pageID: pageID, issue: nil)
        go(.editorStyle)
    }

    private func finishEditorStyle() {
        persistDocument()
        popEditorStyleFrame()
    }

    private func cancelEditorStyle() {
        popEditorStyleFrame()
    }

    private func popEditorStyleFrame() {
        guard var value = document else { go(.editor); return }
        _ = value.returnContextStack.pop()
        document = value
        persistDocument()
        go(.editor)
    }

    private func openBookCheckIssue(_ target: BookCheckNavigationTarget) {
        editorReturnRoute = .bookCheck
        bookCheckTarget = target
        editorInitialPageID = target.issue.pageID
        bookCheckFocusKey = target.issue.persistenceKey
        pushReturnContext(source: .bookCheck, pageID: target.issue.pageID, issue: target)
        go(.editor)
    }

    private func closeEditor() {
        persistDocument()
        bookCheckTarget = nil
        editorInitialPageID = nil
        guard var value = document, let frame = value.returnContextStack.pop() else {
            go(editorReturnRoute)
            return
        }
        document = value
        if frame.source == .pageEditorStyle { go(.editor); return }
        checkLatestEditsAndReturn(using: frame)
    }
    private func persistDocument() {
        guard var value = document else { return }
        if var currentBook = memoryBook {
            if let persistedBook = value.memoryBook,
               persistedBook != currentBook,
               persistedBook.documentRevisionID == currentBook.documentRevisionID {
                currentBook.beginNewRevision()
                memoryBook = currentBook
            }
            value.memoryBook = currentBook
        } else {
            value.memoryBook = nil
        }
        value.updatedAt = .now
        document = value
        Task { try? await container.repository.save(document: value) }
    }

    private func pushReturnContext(source: ReturnSourceScreen, pageID: UUID?, issue: BookCheckNavigationTarget?) {
        guard var value = document else { return }
        let formerPageIndex = pageID.flatMap { id in memoryBook?.pages.firstIndex(where: { $0.id == id }) }
        let locator = issue.map {
            BookCheckIssueLocator(ruleID: $0.issue.stableRuleID, pageID: $0.issue.pageID, elementID: $0.issue.elementID, formerIssueIndex: $0.issueIndex)
        }
        value.returnContextStack.push(.init(source: source, logicalPageID: pageID, formerPageIndex: formerPageIndex, paperSize: pageSize, issueLocator: locator))
        document = value
        persistDocument()
    }

    @discardableResult
    private func evaluateAndPersistBookCheck(locator: BookCheckIssueLocator? = nil) -> BookCheckResult? {
        guard let book = memoryBook, var value = document else { return nil }
        let result = BookCheckWorkflow.evaluate(book, assetIsAvailable: PhotoAssetAvailability.isAvailable)
        value.storeBookCheckResult(result)
        value.memoryBook = book
        if let locator {
            let currentIssues = book.checkBook(assetIsAvailable: PhotoAssetAvailability.isAvailable)
            if let index = BookCheckWorkflow.resolvedIssueIndex(for: locator, in: currentIssues) {
                bookCheckFocusKey = currentIssues[index].persistenceKey
            } else {
                bookCheckFocusKey = nil
            }
        }
        document = value
        Task { try? await container.repository.save(document: value) }
        return result
    }

    private func enterBookCheck() {
        guard memoryBook != nil else { return }
        // UI-test fixtures keep the synchronous path so existing deterministic
        // route assertions still observe an immediate Book Check screen.
        if isUITestFixtureSession {
            _ = evaluateAndPersistBookCheck()
            go(.bookCheck)
            return
        }
        // Production: Book Check evaluation walks every page synchronously and can
        // freeze a large book (e.g. 75 pages) for noticeable time. Show the
        // dedicated checking screen immediately, then evaluate off the tap so the
        // preview never appears stuck. Mirrors `checkLatestEditsAndReturn`.
        go(.rechecking)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard route == .rechecking else { return }
            guard memoryBook != nil else { go(.preview); return }
            _ = evaluateAndPersistBookCheck()
            guard route == .rechecking else { return }
            go(.bookCheck)
        }
    }

    /// A revision transition may not flash an older Book Check or Final
    /// Preview. Route through this explicit blocking state, then resolve the
    /// saved locator/page identity against the new revision.
    private func checkLatestEditsAndReturn(using frame: ReturnContextFrame) {
        go(.rechecking)
        Task { @MainActor in
            // The short presentation interval is deliberate: it gives VoiceOver,
            // UI tests, and people a stable, non-bypassable state rather than a
            // one-frame stale result during synchronous local rule evaluation.
            try? await Task.sleep(for: .milliseconds(350))
            guard route == .rechecking else { return }
            let result = evaluateAndPersistBookCheck(locator: frame.issueLocator)
            guard result?.status != .blocked else { go(.bookCheck); return }
            guard let book = memoryBook else { go(.bookCheck); return }
            let resolvedPageID = BookCheckWorkflow.resolvedPageID(for: frame, in: book)
            switch frame.source {
            case .finalPreview:
                finalPreviewLogicalPageID = resolvedPageID
                go(.finalPreview)
            case .bookPreview, .bookCheck:
                previewLogicalPageID = resolvedPageID
                go(.preview)
            case .pageEditorStyle:
                go(.editor)
            }
        }
    }

    private func continueFromBookCheck() {
        guard let book = memoryBook, var value = document else { return }
        let result = value.cachedBookCheckResult(for: book) ?? BookCheckWorkflow.evaluate(book, assetIsAvailable: PhotoAssetAvailability.isAvailable)
        if value.cachedBookCheckResult(for: book) == nil {
            value.storeBookCheckResult(result)
            document = value
            persistDocument()
        }
        guard result.status != .blocked else { return }
        go((purchased || isPurchaseBypassed) ? .finalPreview : .purchase)
    }

    private func ensureMemoryBook() {
        guard let document else { return }
        if let saved = document.memoryBook {
            memoryBook = saved
            style = saved.style
            pageSize = saved.pageSize
        } else if memoryBook == nil {
            guard ProcessInfo.processInfo.arguments.contains("-uiTesting") else {
                operationError = "Choose a book style and paper size before opening the preview."
                if route != .bookStyle { go(.bookStyle) }
                return
            }
            var built = MemoryBookBuilder.build(profile: document.profile, photos: document.photos, chapters: document.chapters, style: style, pageSize: pageSize)
            // UI-only Crop fixtures use the identical editor route with real
            // portrait/landscape and ±15° document geometry. Production data
            // never reads these launch arguments.
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-uiTesting"),
               let stateIndex = arguments.firstIndex(of: "-uiDemoState"),
               arguments.indices.contains(stateIndex + 1) {
                let fixture = arguments[stateIndex + 1]
                let rotation: Double? = fixture == "crop-portrait-plus15" || fixture == "crop-square-plus15" ? 15 : (fixture == "crop-portrait-minus15" ? -15 : (fixture == "crop-landscape" ? 0 : nil))
                if let rotation,
                   let pageIndex = built.pages.firstIndex(where: { $0.kind == .photoSelection }),
                   let imageIndex = built.pages[pageIndex].elements.firstIndex(where: { $0.kind == .image }) {
                    built.pages[pageIndex].elements[imageIndex].rotationDegrees = rotation
                }
                if fixture == "text-missing-caption", let pageIndex = built.pages.firstIndex(where: { $0.kind == .photoSelection }) {
                    built.pages[pageIndex].elements.removeAll { $0.textField == .photoCaption }
                }
                // Simulates an asset that was removed from the user's selected
                // Photo Library scope after the book was composed.  The editor
                // must expose a repair affordance before the exporter blocks.
                if fixture == "missing-photo",
                   let pageIndex = built.pages.firstIndex(where: { $0.elements.contains(where: { $0.kind == .image }) }),
                   let imageIndex = built.pages[pageIndex].elements.firstIndex(where: { $0.kind == .image }) {
                    built.pages[pageIndex].elements[imageIndex].assetID = UUID()
                }
                if (fixture == "text-fit-success" || fixture == "text-fit-failure"), let pageIndex = built.pages.firstIndex(where: { $0.kind == .photoSelection }) {
                    let value = String(repeating: "n", count: 119) + "\n"
                    if let captionIndex = built.pages[pageIndex].elements.firstIndex(where: { $0.textField == .photoCaption }) {
                        built.pages[pageIndex].elements[captionIndex].text = value
                        built.pages[pageIndex].elements[captionIndex].textStyle = fixture == "text-fit-success" ? .large : .small
                        built.pages[pageIndex].elements[captionIndex].normalizedFrame = fixture == "text-fit-success"
                            ? CGRect(x: 0.10, y: 0.52, width: 0.145, height: 0.31)
                            : CGRect(x: 0.10, y: 0.52, width: 0.145, height: 0.035)
                    }
                }
                // A deterministic Book Check fixture: character-limit blocking
                // is independent of typography/line-break differences, making
                // the Go-to-field route testable on every simulator runtime.
                if fixture == "text-book-check-overflow",
                   let pageIndex = built.pages.firstIndex(where: { $0.kind == .photoSelection }),
                   let captionIndex = built.pages[pageIndex].elements.firstIndex(where: { $0.textField == .photoCaption }) {
                    built.pages[pageIndex].elements[captionIndex].text = String(repeating: "n", count: 121)
                    built.pages[pageIndex].elements[captionIndex].textStyle = .standard
                }
                // Empty, generously sized fields used only by the UI paste
                // boundary test. They let the test distinguish a character
                // limit failure from an unrelated visual line-wrap failure.
                if fixture == "text-unicode-photo",
                   let pageIndex = built.pages.firstIndex(where: { $0.kind == .photoSelection }),
                   let captionIndex = built.pages[pageIndex].elements.firstIndex(where: { $0.textField == .photoCaption }) {
                    built.pages[pageIndex].elements[captionIndex].text = ""
                    built.pages[pageIndex].elements[captionIndex].textStyle = .small
                    built.pages[pageIndex].elements[captionIndex].normalizedFrame = CGRect(x: 0.10, y: 0.45, width: 0.80, height: 0.45)
                }
                if fixture == "text-unicode-dedication",
                   let pageIndex = built.pages.firstIndex(where: { $0.kind == .dedication }),
                   let messageIndex = built.pages[pageIndex].elements.firstIndex(where: { $0.textField == .dedicationMessage }) {
                    built.pages[pageIndex].elements[messageIndex].text = ""
                    built.pages[pageIndex].elements[messageIndex].textStyle = .small
                    built.pages[pageIndex].elements[messageIndex].normalizedFrame = CGRect(x: 0.10, y: 0.23, width: 0.80, height: 0.65)
                }
                if fixture == "text-safe-drag",
                   let pageIndex = built.pages.firstIndex(where: { $0.kind == .photoSelection }),
                   let captionIndex = built.pages[pageIndex].elements.firstIndex(where: { $0.textField == .photoCaption }) {
                    built.pages[pageIndex].elements[captionIndex].text = "A safe place to land."
                    built.pages[pageIndex].elements[captionIndex].textStyle = .standard
                    built.pages[pageIndex].elements[captionIndex].normalizedFrame = CGRect(x: 0.12, y: 0.42, width: 0.44, height: 0.12)
                }
                if fixture == "text-low-contrast",
                   let pageIndex = built.pages.firstIndex(where: { $0.kind == .photoSelection }),
                   let titleIndex = built.pages[pageIndex].elements.firstIndex(where: { $0.textField == .photoTitle }) {
                    let paper = MemoryBookRGB(red: 0.97, green: 0.93, blue: 0.84)
                    built.pages[pageIndex].backgroundColor = paper
                    built.pages[pageIndex].elements[titleIndex].textCustomColor = paper
                }
                if fixture == "composition-near-align",
                   let pageIndex = built.pages.firstIndex(where: { $0.kind == .photoSelection }),
                   let titleIndex = built.pages[pageIndex].elements.firstIndex(where: { $0.textField == .photoTitle }) {
                    built.pages[pageIndex].elements[titleIndex].normalizedFrame.origin.x = 0.092
                    built.pages[pageIndex].elements[titleIndex].isLayoutLocked = true
                    built.pages[pageIndex].elements[titleIndex].origin = .user
                }
                // UI-test-only proof for the reversible Book Check suggestion
                // workflow. Marking every image as user-reviewed removes crop
                // blockers, while repeating one photo on a second page creates
                // one deterministic, non-blocking suggestion.
                if fixture == "book-check-ignore" {
                    for pageIndex in built.pages.indices {
                        for elementIndex in built.pages[pageIndex].elements.indices
                            where built.pages[pageIndex].elements[elementIndex].kind == .image {
                            built.pages[pageIndex].elements[elementIndex].origin = .user
                            built.pages[pageIndex].elements[elementIndex].imageContentMode = .fit
                        }
                    }
                    let photoPages = built.pages.indices.filter { built.pages[$0].kind == .photoSelection }
                    if let sourcePage = photoPages.first,
                       let targetPage = photoPages.dropFirst().first,
                       var repeated = built.pages[sourcePage].elements.first(where: { $0.kind == .image }) {
                        repeated.id = UUID()
                        repeated.normalizedFrame = CGRect(x: 0.56, y: 0.54, width: 0.30, height: 0.24)
                        repeated.origin = .user
                        repeated.imageContentMode = .fit
                        repeated.zIndex = (built.pages[targetPage].elements.map(\.zIndex).max() ?? 0) + 1
                        built.pages[targetPage].elements.append(repeated)
                    }
                }
            }
            memoryBook = built
            persistDocument()
        }
    }

    private func startScan() {
        guard !isScanning else { return }
        paused = false
        isScanning = true
        scanTask = Task {
            operationError = nil; scanDisplayState = ""
            var profile = document?.profile ?? PetProfile(id: profileID, name: name, species: species, departureYear: Int(year) ?? 2024, referenceAssetIdentifiers: referenceAssetIdentifiers, albumStyle: style)
            profile.lifecycle = .scanning
            var priorDocument = document ?? ArchiveDocument(profile: profile)
            priorDocument.profile = profile
            let generationTransition = RecognitionGenerationCoordinator.transition(
                for: profile,
                current: priorDocument.activeRecognitionGeneration
            )
            priorDocument = RecognitionGenerationCoordinator.preparing(priorDocument, transition: generationTransition)
            // A completed archive has no active checkpoint. Seed an additive
            // refresh with existing candidates so only genuinely new matches
            // are introduced and prior review decisions remain stable.
            let resumeCheckpoint: ScanCheckpoint? = generationTransition.requiresFullRematch
                ? nil
                : (priorDocument.scanCheckpoint ?? ScanArchiveMergePolicy.checkpointForIncrementalRescan(document: priorDocument))
            // A resume must keep its saved state visible while reference
            // features are prepared. Resetting these values briefly produced
            // the contradictory "0 photos checked / 114 matches" screen.
            scanCompletedAssets = resumeCheckpoint?.progress.completedAssets ?? 0
            scanTotalAssets = resumeCheckpoint?.progress.totalAssets ?? 0
            scanMatchCount = resumeCheckpoint?.candidates.count ?? 0
            scanProgress = Double(scanCompletedAssets) / Double(max(scanTotalAssets, 1))
            var scanningDocument = priorDocument
            scanningDocument.profile = profile
            scanningDocument.scanCheckpoint = resumeCheckpoint
            scanningDocument.archiveCheckpoint = ArchiveCheckpoint(stage: .scan)
            document = scanningDocument
            persistDocument()
            do {
                let photos = try await container.scanner.scan(profile: profile, checkpoint: resumeCheckpoint) { checkpoint in
                    await MainActor.run {
                        guard var current = document, current.id == profile.id else { return }
                        current = RecognitionGenerationCoordinator.merging(
                            scanned: checkpoint.candidates,
                            into: current,
                            generation: generationTransition.generation
                        )
                        current.profile.lifecycle = .scanning
                        var durableCheckpoint = checkpoint
                        let scannedIDs = Set(checkpoint.candidates.map(\.assetLocalIdentifier))
                        durableCheckpoint.candidates = current.photos.filter { scannedIDs.contains($0.assetLocalIdentifier) }
                        current.scanCheckpoint = durableCheckpoint
                        current.scanAuditMetrics = checkpoint.auditMetrics
                        current.updatedAt = .now
                        document = current
                        scanCompletedAssets = checkpoint.progress.completedAssets; scanTotalAssets = checkpoint.progress.totalAssets; scanMatchCount = checkpoint.candidates.count; scanProgress = Double(checkpoint.progress.completedAssets) / Double(max(checkpoint.progress.totalAssets, 1))
                        // The checkpoint now includes the local coverage set.
                        // Persisting that growing payload every 12 photos caused
                        // hundreds of JSON encodes and SwiftData writes during a
                        // large scan. The in-memory UI still advances per photo;
                        // durable recovery is deliberately batched and is also
                        // saved immediately for pause, thermal, and completion.
                        if checkpoint.progress.completedAssets.isMultiple(of: 240) || checkpoint.progress.completedAssets == checkpoint.progress.totalAssets { persistDocument() }
                    }
                }
                guard !Task.isCancelled else { return }
                profile.lifecycle = .ready
                if let current = document {
                    var completed = RecognitionGenerationCoordinator.merging(
                        scanned: photos,
                        into: current,
                        generation: generationTransition.generation
                    )
                    completed.profile = profile
                    completed.scanAuditMetrics = current.scanCheckpoint?.auditMetrics ?? current.scanAuditMetrics
                    if var checkpoint = current.scanCheckpoint {
                        let scannedIDs = Set(photos.map(\.assetLocalIdentifier))
                        checkpoint.candidates = completed.photos.filter { scannedIDs.contains($0.assetLocalIdentifier) }
                        completed.scanCheckpoint = checkpoint
                    }
                    document = completed
                } else {
                    document = RecognitionGenerationCoordinator.merging(
                        scanned: photos,
                        into: ArchiveDocument(profile: profile),
                        generation: generationTransition.generation
                    )
                }
                if var completed = document {
                    completed.archiveCheckpoint = ArchiveCheckpoint(stage: .review)
                    document = completed
                }
                persistDocument(); scanProgress = 1; isScanning = false; scanTask = nil
            } catch {
                isScanning = false; scanTask = nil
                if Task.isCancelled || error as? ScanFailure == .interrupted {
                    paused = true
                    scanDisplayState = "interrupted"
                    persistDocument()
                } else if error as? ScanFailure == .insufficientReferences {
                    paused = true
                    scanDisplayState = "insufficientReferences"
                    operationError = "We need at least 3 available reference photos to recognize your pet."
                    persistDocument()
                } else if error as? ScanFailure == .insufficientAccess {
                    paused = true
                    scanDisplayState = "failed"
                    operationError = "Tailor needs access to the photos you chose before it can scan."
                    persistDocument()
                } else if error as? ScanFailure == .lowPower {
                    paused = true
                    scanDisplayState = "lowBattery"
                    operationError = "Your iPhone is in Low Power Mode. Scan progress has been saved."
                    persistDocument()
                } else if error as? ScanFailure == .thermal {
                    paused = true
                    scanDisplayState = "thermal"
                    operationError = "Your iPhone needs to cool down. Scan progress has been saved."
                    persistDocument()
                } else {
                    scanDisplayState = "failed"
                    operationError = error.localizedDescription
                    scanProgress = 0
                }
            }
        }
    }

    private func pauseScan() {
        guard isScanning else {
            paused = true
            scanDisplayState = "paused"
            persistDocument()
            return
        }
        scanTask?.cancel()
    }

    private var draftSummary: MemoryBookDraftSummary {
        MemoryBookBuilder.analyze(photos: document?.photos ?? [])
    }

    private func beginSmartDraft() {
        guard draftSummary.selectedPhotoCount >= 3 else {
            smartDraftError = "Choose at least 3 confirmed photos before creating a memory book."
            go(.confirm)
            return
        }
        smartDraftError = nil
        guard var value = document else { return }
        value.storyPlanDraft = makeStoryPlanDraft(from: value, simple: false)
        value.archiveCheckpoint = ArchiveCheckpoint(stage: .smartDraft, smartDraftStepCursor: "complete")
        value.updatedAt = .now
        isPreparingSmartDraft = true
        Task { @MainActor in
            do {
                try await container.repository.save(document: value)
                document = value
                go(.smartDraft)
            } catch {
                smartDraftError = error.localizedDescription
                isPreparingSmartDraft = false
                return
            }
            // The current deterministic planner is intentionally local and
            // fast. Keep a short, cancellable presentation interval so the UI
            // communicates what happened without pretending to scan again.
            try? await Task.sleep(for: .milliseconds(450))
            guard route == .smartDraft else { return }
            isPreparingSmartDraft = false
        }
    }

    private func makeStoryPlanDraft(from document: ArchiveDocument, simple: Bool) -> StoryPlanDraft {
        let chosen = document.photos.filter(\.isEligibleForArchive)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: chosen) { photo in
            (photo.localDateRange?.start ?? photo.createdAt).map { calendar.component(.year, from: $0) } ?? document.profile.departureYear
        }
        var chapters = grouped.keys.sorted().enumerated().map { index, year in
            Chapter(id: UUID(), title: "Days together", dateLabel: String(year), photoIDs: grouped[year, default: []].map(\.id), isHidden: false, sortOrder: index)
        }
        if chapters.isEmpty { chapters = [Chapter(id: UUID(), title: "Days together", dateLabel: String(document.profile.departureYear), photoIDs: [], isHidden: false, sortOrder: 0)] }
        var draft = StoryPlanDraft.migrating(profile: document.profile, photos: chosen, chapters: chapters, sourceMatchGenerationID: document.activeRecognitionGeneration?.matchGenerationID)
        draft.state = .generated
        draft.createdAt = .now
        draft.updatedAt = .now
        draft.confirmedAt = nil
        if simple { draft.duplicateGroups = [] }
        return draft
    }

    private func continueToStoryPlan() {
        guard let value = document, value.storyPlanDraft != nil else { return }
        commit(value, checkpoint: .storyPlan, route: .timeline)
    }

    private func useSimpleTimeline() {
        guard var value = document else { return }
        value.storyPlanDraft = makeStoryPlanDraft(from: value, simple: true)
        commit(value, checkpoint: .storyPlan, route: .timeline)
    }

    private func confirmStoryPlan() {
        guard var value = document, var draft = value.storyPlanDraft else { return }
        draft.replaceChapters(draft.chapters, state: .confirmed)
        value.storyPlanDraft = draft
        commit(value, checkpoint: .stylePending, route: .bookStyle)
    }

    private func applySelectedBookStyle(_ mode: MemoryBookTemplateApplicationMode) {
        guard !isCreatingBook, var value = document, let draft = value.storyPlanDraft, draft.state == .confirmed else { return }
        isCreatingBook = true
        operationError = nil
        if var book = value.memoryBook ?? memoryBook {
            book.applyTemplate(style: style, mode: mode)
            if book.pageSize != pageSize { book.pageSize = pageSize }
            book.beginNewRevision()
            value.memoryBook = book
        } else {
            let chapters = draft.chapters
            let book = MemoryBookBuilder.build(profile: value.profile, photos: value.photos, chapters: chapters, style: style, pageSize: pageSize)
            value.chapters = chapters
            value.memoryBook = book
        }
        value.profile.albumStyle = style
        value.archiveCheckpoint = ArchiveCheckpoint(stage: .documentReady)
        value.updatedAt = .now
        Task { @MainActor in
            defer { isCreatingBook = false }
            do {
                try await container.repository.save(document: value)
                document = value
                memoryBook = value.memoryBook
                go(.preview)
            } catch { operationError = error.localizedDescription }
        }
    }

    @MainActor
    private func loadProductPrice() async {
        guard !isLoadingProductPrice else { return }
        isLoadingProductPrice = true
        productPriceLoadFailed = false
        defer { isLoadingProductPrice = false }
        let price = await container.purchase.unlockDisplayPrice()
        productDisplayPrice = price
        productPriceLoadFailed = price == nil
    }

    private func purchase() {
        guard !isPurchasing, productDisplayPrice != nil else { return }
        Task {
            isPurchasing = true
            defer { isPurchasing = false }
            operationError = nil
            purchaseNotice = nil
            do {
                switch try await container.purchase.purchaseUnlock() {
                case .entitled, .restored:
                    purchased = true
                    go(.finalPreview)
                case .pending:
                    purchaseNotice = "Your purchase is pending approval. Your album and edits are still here."
                    go(.bookCheck)
                case .cancelled:
                    purchaseNotice = "Purchase cancelled. Your album and edits are still here."
                    go(.bookCheck)
                case .failed(let message):
                    operationError = message
                    go(.bookCheck)
                case .idle, .purchasing:
                    operationError = "Purchase could not be completed. Please try again."
                    go(.bookCheck)
                }
            } catch { operationError = error.localizedDescription; go(.bookCheck) }
        }
    }
    private func restorePurchase() {
        guard !isPurchasing else { return }
        Task {
            isPurchasing = true
            defer { isPurchasing = false }
            operationError = nil
            purchaseNotice = nil
            do {
                let state = try await container.purchase.restorePurchases()
                if state == .restored || state == .entitled {
                    purchased = true
                    go(.finalPreview)
                } else {
                    operationError = "No previous Tailor purchase was found for this Apple ID."
                    go(.bookCheck)
                }
            } catch { operationError = error.localizedDescription; go(.bookCheck) }
        }
    }
    private func exportPDF() {
        guard hasCurrentBookCheckPass else {
            operationError = "This revision must pass Book Check before export."
            enterBookCheck()
            return
        }
        guard let document else {
            operationError = "The archive could not be found. Return to the timeline and try again."
            return
        }
        let book = memoryBook ?? MemoryBookBuilder.build(profile: document.profile, photos: document.photos, chapters: document.chapters, style: style, pageSize: pageSize)
        let exportFingerprint = book.exportSnapshot(watermarked: false).fingerprint
        memoryBook = book
        exportCompletedPages = 0
        exportTotalPages = book.pages.count
        operationError = nil
        isExporting = true
        let exporter = container.pdfExporter
        exportTask = Task {
            let worker = Task.detached {
                try await exporter.export(document: book) { completed, total in
                    Task { @MainActor in
                        exportCompletedPages = completed
                        exportTotalPages = total
                    }
                }
            }
            defer { isExporting = false; exportTask = nil }
            operationError = nil
            do {
                let output = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                try Task.checkCancellation()
                guard var updated = self.document else { return }
                updated.profile.lifecycle = .exported
                updated.updatedAt = .now
                exportURL = output
                updated.memoryBook = book
                updated.exportRecords.append(
                    MemoryBookExportRecord(
                        fileName: output.lastPathComponent,
                        pageCount: book.pages.count,
                        pageSize: book.pageSize,
                        watermarked: false,
                        snapshotFingerprint: exportFingerprint
                    )
                )
                self.document = updated
                exportCompletedPages = exportTotalPages
                persistDocument()
            } catch is CancellationError {
                operationError = nil
            } catch {
                operationError = error.localizedDescription
            }
        }
    }
    private func cancelExport() { exportTask?.cancel() }
    private func updateAlbumStyle() {
        guard var current = document else { return }
        current.profile.albumStyle = style
        current.updatedAt = .now
        document = current
    }
    private func updateBookPageSize(_ newSize: PDFPageSize) {
        guard var book = memoryBook else { return }
        guard book.pageSize != newSize else { return }
        book.pageSize = newSize
        book.beginNewRevision()
        memoryBook = book
        persistDocument()
        if route == .finalPreview || route == .preview {
            let source: ReturnSourceScreen = route == .finalPreview ? .finalPreview : .bookPreview
            let selected = route == .finalPreview ? finalPreviewLogicalPageID : previewLogicalPageID
            let formerIndex = selected.flatMap { id in memoryBook?.pages.firstIndex(where: { $0.id == id }) }
            checkLatestEditsAndReturn(using: .init(source: source, logicalPageID: selected, formerPageIndex: formerIndex, paperSize: newSize, issueLocator: nil))
        }
    }
    /// A completed archive can be refreshed without replacing its user choices.
    /// `startScan` seeds the scanner with an incremental checkpoint and merge policy.
    private func rescanArchive() {
        guard document != nil else { return }
        go(.scan)
        startScan()
    }

    private func restartArchive() { scanTask?.cancel(); scanTask = nil; isScanning = false; profileID = UUID(); name = ""; species = .dog; arrivalYear = ""; year = String(Calendar.current.component(.year, from: .now)); referenceAssetIdentifiers = []; document = nil; memoryBook = nil; manualImportMode = false; exportURL = nil; scanProgress = 0; route = .welcome; container.router.reset() }
    private func deleteArchive() {
        let id = profileID
        Task {
            try? await container.repository.deleteArchive(id: id)
            await container.scanner.deleteLocalIndex(profileID: id)
            try? ManualAssetStore.deleteCopies(profileID: id)
            let prefix = "\(id.uuidString)-life-archive"
            let urls = (try? FileManager.default.contentsOfDirectory(at: .documentsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            for url in urls where url.lastPathComponent.hasPrefix(prefix) && url.pathExtension.lowercased() == "pdf" {
                try? FileManager.default.removeItem(at: url)
            }
            restartArchive()
        }
    }
}
