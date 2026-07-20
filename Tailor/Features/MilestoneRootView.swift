import SwiftUI
import Photos
import Vision
import ImageIO

struct MilestoneRootView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var route: AppRoute = .welcome; @State private var scope: PhotoAccessScope = .notDetermined; @State private var name = "Milo"; @State private var species: PetSpecies = .dog; @State private var year = "2024"; @State private var referenceAssetIdentifiers: [String] = []; @State private var profileID = UUID(); @State private var restoredDraft = false; @State private var hasSavedArchive = false; @State private var scanProgress = 0.0; @State private var scanCompletedAssets = 0; @State private var scanTotalAssets = 0; @State private var scanMatchCount = 0; @State private var paused = false; @State private var isScanning = false; @State private var scanDisplayState = ""; @State private var scanTask: Task<Void, Never>?; @State private var style: AlbumStyle = .warmPaper; @State private var pageSize: PDFPageSize = .letter; @State private var selectedChapterID: UUID?; @State private var purchased = false; @State private var isPurchasing = false; @State private var document: ArchiveDocument?; @State private var memoryBook: MemoryBookDocument?; @State private var operationError: String?; @State private var purchaseNotice: String?; @State private var exportURL: URL?; @State private var videoURL: URL?; @State private var isExporting = false; @State private var exportCompletedPages = 0; @State private var exportTotalPages = 0; @State private var exportTask: Task<Void, Never>?; @State private var didInitializeRoot = false; @State private var realPhotoQADiagnostic = "not-started"; @StateObject private var photoLibrary = PhotoLibraryAccess()

    var body: some View { Group { switch route {
    case .welcome: WelcomeFeatureView(hasSavedArchive: hasSavedArchive, next: advance, openArchives: { go(.archive) })
    case .privacy: PrivacyFeatureView(scope: $scope, photoLibrary: photoLibrary, next: advance, back: back)
    case .profile: ProfileFeatureView(name: $name, species: $species, departureYear: $year, next: advance, back: back)
    case .references: ReferencesFeatureView(referenceAssetIdentifiers: $referenceAssetIdentifiers, next: advance, back: back)
    case .scan: ScanFeatureView(progress: $scanProgress, completedAssets: scanCompletedAssets, totalAssets: scanTotalAssets, matchCount: scanMatchCount, previewAssetIdentifiers: Array((document?.photos ?? []).prefix(4).map(\.assetLocalIdentifier)), displayState: scanDisplayState, paused: $paused, isScanning: isScanning, errorMessage: operationError, start: startScan, pause: pauseScan, next: advance, back: leaveScan)
    case .confirm: ReviewFeatureView(name: name, photos: photosBinding, next: createTimeline, back: back, showsPendingTimelinePromptOnAppear: isPendingTimelineUITestFixture)
    case .timeline: TimelineFeatureView(name: name, chapters: chaptersBinding, photos: document?.photos ?? [], edit: { chapterID in selectedChapterID = chapterID; go(.chapter) }, next: { go(.editor) }, back: back)
    case .chapter: ChapterEditorFeatureView(chapters: chaptersBinding, photos: document?.photos ?? [], selectedChapterID: selectedChapterID, next: { persistDocument(); go(.timeline) }, back: { go(.timeline) })
    case .editor: AlbumEditorFeatureView(memoryBook: $memoryBook, purchased: purchased || isPurchaseBypassed, back: back, preview: { persistDocument(); go(.preview) }, export: { persistDocument(); go((purchased || isPurchaseBypassed) ? .export : .purchase) }, persist: persistDocument).onAppear { ensureMemoryBook() }
    case .preview: PreviewFeatureView(name: name, style: $style, pageSize: $pageSize, chapters: document?.chapters ?? [], photos: document?.photos ?? [], memoryBook: $memoryBook, purchased: purchased || isPurchaseBypassed, next: { updateAlbumStyle(); persistDocument(); go((purchased || isPurchaseBypassed) ? .export : .purchase) }, back: back).onAppear { ensureMemoryBook() }.onChange(of: style) { _, _ in updateAlbumStyle(); memoryBook?.style = style; memoryBook?.updatedAt = .now; persistDocument() }.onChange(of: pageSize) { _, newSize in updateBookPageSize(newSize) }
    case .purchase: PurchaseFeatureView(purchase: purchase, restore: restorePurchase, errorMessage: operationError, noticeMessage: purchaseNotice, isPurchasing: isPurchasing, next: { purchased = true; go(.export) }, back: back)
    case .export: ExportFeatureView(name: name, exportURL: exportURL, exportRecord: latestExportRecord, memoryBook: memoryBook ?? document?.memoryBook, videoURL: videoURL, errorMessage: operationError, isExporting: isExporting, completedPages: exportCompletedPages, totalPages: exportTotalPages, createPDF: exportPDF, cancelPDF: cancelExport, createVideo: exportVideo, done: { go(.archive) }, back: { go(.timeline) }).onAppear { ensureMemoryBook() }
    case .archive: ArchivesFeatureView(name: name, pdfURL: storedPDFURL, exportRecord: latestExportRecord, openArchive: { ensureMemoryBook(); go(.preview) }, rescan: rescanArchive, restart: restartArchive, delete: deleteArchive)
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
        Task { purchased = await container.purchase.isEntitled() }
    }

    }

    /// Debug/test-only escape hatch for running the complete local flow. The
    /// production StoreKit path is unchanged when the launch argument is absent.
    private var isPurchaseBypassed: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // Never bypass StoreKit merely because this is a Debug build. A local
        // developer can opt in explicitly, while UI automation stays isolated.
        return arguments.contains("-uiBypassPurchase") && !arguments.contains("-uiTesting")
        #else
        return false
        #endif
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
        if route == .profile || route == .references {
            Task {
                await saveDraft()
                go(next)
            }
        } else {
            go(next)
        }
    }
    private func back() { guard let previous = AppRoute(rawValue: route.rawValue - 1) else { return }; go(previous) }
    private func leaveScan() {
        if isScanning { pauseScan() }
        back()
    }
    private func go(_ newRoute: AppRoute) { route = newRoute; container.router.navigate(to: newRoute) }

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
            "preview": .preview, "purchase": .purchase, "export": .export, "archive": .archive
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
        let uncertainPhoto = ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, assetLocalIdentifier: "ui-photo-2", decision: .needsReview, confidence: 0.62, createdAt: .now)
        let excludedPhoto = ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!, assetLocalIdentifier: "ui-photo-3", decision: .excluded, confidence: 0.22, createdAt: .now)
        let chapter = Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, title: "Days together", dateLabel: "2018–2024", photoIDs: [firstPhoto.id], isHidden: false, sortOrder: 0)

        profileID = demoProfile.id
        name = demoProfile.name
        species = demoProfile.species
        year = String(demoProfile.departureYear)
        // The privacy reference state represents first launch. Other direct
        // route fixtures retain limited access so they never request Photos.
        scope = requestedRoute == .privacy ? .notDetermined : .limited
        referenceAssetIdentifiers = demoProfile.referenceAssetIdentifiers
        var demoPhotos = [firstPhoto, uncertainPhoto, excludedPhoto]
        var demoChapters = [chapter]
        if requestedRoute == .confirm && demoState.isEmpty {
            let additionalHigh = ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!, assetLocalIdentifier: "ui-high-2", decision: .selected, confidence: 0.91, createdAt: .now)
            let pending = (0..<110).map { index in
                ArchivePhoto(id: UUID(), assetLocalIdentifier: "ui-review-\(index + 1)", decision: .needsReview, confidence: index == 0 ? 0.62 : 0.58, createdAt: .now)
            }
            demoPhotos = [firstPhoto, additionalHigh] + pending
        }
        if [.timeline, .chapter, .editor, .preview, .purchase, .export, .archive].contains(requestedRoute) {
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
                ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!, assetLocalIdentifier: "ui-photo-4", decision: .needsReview, confidence: 0.69, createdAt: .now),
                ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!, assetLocalIdentifier: "ui-photo-5", decision: .needsReview, confidence: 0.58, createdAt: .now)
            ]
        }
        // A deterministic post-review state for the complete archive-flow
        // regression. Batch approval itself has dedicated tests; this fixture
        // starts at the exact hand-off contract where every chosen photo is
        // confirmed and timeline creation must proceed without another prompt.
        if requestedRoute == .confirm, demoState == "review-ready" {
            demoPhotos = [firstPhoto, uncertainPhoto]
            demoPhotos[1].decision = .selected
            demoPhotos[1].sensitivityState = .normal
        }
        if requestedRoute == .confirm, demoState == "review-sensitive" {
            demoPhotos.append(ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!, assetLocalIdentifier: "ui-photo-6", decision: .needsReview, confidence: 0.51, createdAt: .now, sensitivityState: .needsSensitiveReview))
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
        if demoState == "visual-fixture", [.editor, .preview].contains(requestedRoute) {
            let fixture = MemoryBookVisualQAFixture.make(style: demoStyle, paper: demoPaper)
            // A UI-test-only replacement. Production routes never enter this
            // branch, and both surfaces bind to this exact document instance.
            document = ArchiveDocument(profile: fixture.profile, photos: fixture.photos, chapters: fixture.chapters, memoryBook: fixture)
            memoryBook = fixture
            name = fixture.profile.name
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
        purchased = isPurchaseBypassed || demoState == "visual-fixture" || (requestedRoute == .preview && ["preview-purchased", "preview-odd-purchased"].contains(demoState))
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
            departureYear: Int(year) ?? Calendar.current.component(.year, from: .now),
            lifecycle: .draft,
            referenceAssetIdentifiers: referenceAssetIdentifiers,
            albumStyle: style
        )
        let updated = ArchiveDocument(profile: profile, photos: document?.photos ?? [], chapters: document?.chapters ?? [])
        document = updated
        try? await container.repository.save(document: updated)
    }

    private func restoreLatestDraftIfNeeded() async {
        guard !restoredDraft else { return }
        restoredDraft = true
        scope = photoLibrary.scope
        guard let profile = try? await container.repository.allProfiles().first else { return }
        profileID = profile.id
        name = profile.name
        species = profile.species
        year = String(profile.departureYear)
        referenceAssetIdentifiers = profile.referenceAssetIdentifiers
        style = profile.albumStyle
        document = try? await container.repository.document(id: profile.id)
        memoryBook = document?.memoryBook
        if let memoryBook { pageSize = memoryBook.pageSize }
        if document?.profile.lifecycle == .ready || document?.profile.lifecycle == .exported {
            hasSavedArchive = true
        }
        if document?.profile.lifecycle == .exported, storedPDFURL != nil { exportURL = storedPDFURL }
        if let checkpoint = document?.scanCheckpoint, document?.profile.lifecycle == .scanning {
            scanCompletedAssets = checkpoint.progress.completedAssets; scanTotalAssets = checkpoint.progress.totalAssets; scanMatchCount = checkpoint.candidates.count; scanProgress = Double(checkpoint.progress.completedAssets) / Double(max(checkpoint.progress.totalAssets, 1))
            paused = true
            go(.scan)
        }
    }

    private var photosBinding: Binding<[ArchivePhoto]> { Binding(get: { document?.photos ?? [] }, set: { updatePhotos($0) }) }
    private var chaptersBinding: Binding<[Chapter]> { Binding(get: { document?.chapters ?? [] }, set: { updateChapters($0) }) }
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
        memoryBook = nil
        persistDocument()
    }
    private func updateChapters(_ chapters: [Chapter]) { guard var value = document else { return }; value.chapters = chapters; value.updatedAt = .now; document = value; memoryBook = nil; persistDocument() }
    private func persistDocument() {
        guard var value = document else { return }
        value.memoryBook = memoryBook
        value.updatedAt = .now
        document = value
        Task { try? await container.repository.save(document: value) }
    }

    private func ensureMemoryBook() {
        guard let document else { return }
        if let saved = document.memoryBook {
            memoryBook = saved
            style = saved.style
            pageSize = saved.pageSize
        } else if memoryBook == nil {
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
            let priorDocument = document ?? ArchiveDocument(profile: profile)
            // A completed archive has no active checkpoint. Seed an additive
            // refresh with existing candidates so only genuinely new matches
            // are introduced and prior review decisions remain stable.
            let resumeCheckpoint = priorDocument.scanCheckpoint
                ?? ScanArchiveMergePolicy.checkpointForIncrementalRescan(document: priorDocument)
            // A resume must keep its saved state visible while reference
            // features are prepared. Resetting these values briefly produced
            // the contradictory "0 photos checked / 114 matches" screen.
            scanCompletedAssets = resumeCheckpoint.progress.completedAssets
            scanTotalAssets = resumeCheckpoint.progress.totalAssets
            scanMatchCount = resumeCheckpoint.candidates.count
            scanProgress = Double(scanCompletedAssets) / Double(max(scanTotalAssets, 1))
            document = ArchiveDocument(
                profile: profile,
                photos: priorDocument.photos,
                chapters: priorDocument.chapters,
                scanCheckpoint: resumeCheckpoint,
                memoryBook: priorDocument.memoryBook,
                exportRecords: priorDocument.exportRecords,
                updatedAt: priorDocument.updatedAt
            )
            persistDocument()
            do {
                let photos = try await container.scanner.scan(profile: profile, checkpoint: resumeCheckpoint) { checkpoint in
                    await MainActor.run {
                        guard var current = document, current.id == profile.id else { return }
                        current.profile.lifecycle = .scanning
                        current.photos = checkpoint.candidates
                        current.scanCheckpoint = checkpoint
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
                    document = ScanArchiveMergePolicy.completing(document: current, profile: profile, scanned: photos)
                } else {
                    document = ArchiveDocument(profile: profile, photos: photos)
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

    private func createTimeline() {
        guard var document else { return }
        let chosen = document.photos.filter(\.isEligibleForArchive)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: chosen) { photo in
            (photo.localDateRange?.start ?? photo.createdAt).map { calendar.component(.year, from: $0) } ?? document.profile.departureYear
        }
        document.chapters = grouped.keys.sorted().enumerated().map { index, year in
            Chapter(id: UUID(), title: "Days together", dateLabel: String(year), photoIDs: grouped[year, default: []].map(\.id), isHidden: false, sortOrder: index)
        }
        if document.chapters.isEmpty { document.chapters = [Chapter(id: UUID(), title: "Days together", dateLabel: String(document.profile.departureYear), photoIDs: [], isHidden: false, sortOrder: 0)] }
        self.document = document; memoryBook = nil; persistDocument(); go(.timeline)
    }

    private func purchase() {
        guard !isPurchasing else { return }
        Task {
            isPurchasing = true
            defer { isPurchasing = false }
            operationError = nil
            purchaseNotice = nil
            do {
                switch try await container.purchase.purchaseUnlock() {
                case .entitled, .restored:
                    purchased = true
                    go(.export)
                case .pending:
                    purchaseNotice = "Your purchase is pending approval. Your album and edits are still here."
                case .cancelled:
                    purchaseNotice = "Purchase cancelled. Your album and edits are still here."
                case .failed(let message):
                    operationError = message
                case .idle, .purchasing:
                    operationError = "Purchase could not be completed. Please try again."
                }
            } catch { operationError = error.localizedDescription }
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
                    go(.export)
                } else {
                    operationError = "No previous Tailor purchase was found for this Apple ID."
                }
            } catch { operationError = error.localizedDescription }
        }
    }
    private func exportPDF() {
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
    private func exportVideo() {
        guard let document else { operationError = "The archive could not be found. Return to the timeline and try again."; return }
        Task { @MainActor in
            operationError = nil
            do { videoURL = try await container.videoExporter.export(profile: document.profile, photos: document.photos, chapters: document.chapters, duration: 30) }
            catch { operationError = error.localizedDescription }
        }
    }
    private func updateAlbumStyle() {
        guard var current = document else { return }
        current.profile.albumStyle = style
        current.updatedAt = .now
        document = current
    }
    private func updateBookPageSize(_ newSize: PDFPageSize) {
        guard var book = memoryBook else { return }
        book.pageSize = newSize
        book.updatedAt = .now
        memoryBook = book
        persistDocument()
    }
    /// A completed archive can be refreshed without replacing its user choices.
    /// `startScan` seeds the scanner with an incremental checkpoint and merge policy.
    private func rescanArchive() {
        guard document != nil else { return }
        go(.scan)
        startScan()
    }

    private func restartArchive() { scanTask?.cancel(); scanTask = nil; isScanning = false; profileID = UUID(); name = ""; species = .dog; year = String(Calendar.current.component(.year, from: .now)); referenceAssetIdentifiers = []; document = nil; exportURL = nil; scanProgress = 0; route = .welcome; container.router.reset() }
    private func deleteArchive() {
        let id = profileID
        Task {
            try? await container.repository.deleteArchive(id: id)
            await container.scanner.deleteLocalIndex(profileID: id)
            let prefix = "\(id.uuidString)-life-archive"
            let urls = (try? FileManager.default.contentsOfDirectory(at: .documentsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            for url in urls where url.lastPathComponent.hasPrefix(prefix) && url.pathExtension.lowercased() == "pdf" {
                try? FileManager.default.removeItem(at: url)
            }
            restartArchive()
        }
    }
}
