import SwiftUI

struct MilestoneRootView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var route: AppRoute = .welcome; @State private var scope: PhotoAccessScope = .notDetermined; @State private var name = "Milo"; @State private var species: PetSpecies = .dog; @State private var year = "2024"; @State private var referenceAssetIdentifiers: [String] = []; @State private var profileID = UUID(); @State private var restoredDraft = false; @State private var scanProgress = 0.0; @State private var scanCompletedAssets = 0; @State private var scanTotalAssets = 0; @State private var scanMatchCount = 0; @State private var paused = false; @State private var isScanning = false; @State private var scanTask: Task<Void, Never>?; @State private var style: AlbumStyle = .warmPaper; @State private var purchased = false; @State private var document: ArchiveDocument?; @State private var operationError: String?; @State private var exportURL: URL?; @StateObject private var photoLibrary = PhotoLibraryAccess()

    var body: some View { Group { switch route {
    case .welcome: WelcomeFeatureView(next: advance)
    case .privacy: PrivacyFeatureView(scope: $scope, photoLibrary: photoLibrary, next: advance, back: back)
    case .profile: ProfileFeatureView(name: $name, species: $species, departureYear: $year, next: advance, back: back)
    case .references: ReferencesFeatureView(referenceAssetIdentifiers: $referenceAssetIdentifiers, next: advance, back: back)
    case .scan: ScanFeatureView(progress: $scanProgress, completedAssets: scanCompletedAssets, totalAssets: scanTotalAssets, matchCount: scanMatchCount, paused: $paused, isScanning: isScanning, errorMessage: operationError, start: startScan, pause: pauseScan, next: advance, back: back)
    case .confirm: ReviewFeatureView(name: name, photos: photosBinding, next: createTimeline, back: back)
    case .timeline: TimelineFeatureView(name: name, chapters: chaptersBinding, edit: { go(.chapter) }, next: { go(.preview) }, back: back)
    case .chapter: ChapterEditorFeatureView(chapters: chaptersBinding, next: { persistDocument(); go(.preview) }, back: { go(.timeline) })
    case .preview: PreviewFeatureView(name: name, style: $style, purchased: purchased, next: { persistDocument(); go(purchased ? .export : .purchase) }, back: back)
    case .purchase: PurchaseFeatureView(purchase: purchase, restore: restorePurchase, errorMessage: operationError, next: { purchased = true; go(.export) }, back: back)
    case .export: ExportFeatureView(name: name, exportURL: exportURL, errorMessage: operationError, createPDF: exportPDF, done: { go(.archive) }, back: { go(.timeline) })
    case .archive: ArchivesFeatureView(name: name, restart: restartArchive, delete: deleteArchive)
    } }
    .animation(.easeInOut(duration: 0.2), value: route)
    .task {
        guard !configureUITestDemoIfRequested() else { return }
        await restoreLatestDraftIfNeeded()
        purchased = await container.purchase.isEntitled()
    }
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
    private func go(_ newRoute: AppRoute) { route = newRoute; container.router.navigate(to: newRoute) }

    /// UI automation only: `-uiTesting -uiDemoRoute <route>` supplies local, deterministic
    /// content so every product screen can be rendered without Photos, Vision, or StoreKit.
    /// Production launches never enter this branch.
    private func configureUITestDemoIfRequested() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        let routes: [String: AppRoute] = [
            "welcome": .welcome, "privacy": .privacy, "profile": .profile, "references": .references,
            "scan": .scan, "confirm": .confirm, "timeline": .timeline, "chapter": .chapter,
            "preview": .preview, "purchase": .purchase, "export": .export, "archive": .archive
        ]
        guard arguments.contains("-uiTesting"),
              let routeIndex = arguments.firstIndex(of: "-uiDemoRoute"),
              arguments.indices.contains(routeIndex + 1),
              let requestedRoute = routes[arguments[routeIndex + 1]] else { return false }

        let demoProfile = PetProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Milo",
            species: .dog,
            arrivalYear: 2017,
            departureYear: 2024,
            lifecycle: requestedRoute == .archive ? .exported : .ready,
            referenceAssetIdentifiers: ["ui-reference-1", "ui-reference-2", "ui-reference-3"],
            albumStyle: .warmPaper
        )
        let firstPhoto = ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, assetLocalIdentifier: "ui-photo-1", decision: .selected, confidence: 0.96, createdAt: .now)
        let uncertainPhoto = ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, assetLocalIdentifier: "ui-photo-2", decision: .needsReview, confidence: 0.62, createdAt: .now)
        let excludedPhoto = ArchivePhoto(id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!, assetLocalIdentifier: "ui-photo-3", decision: .excluded, confidence: 0.22, createdAt: .now)
        let chapter = Chapter(id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, title: "Days together", dateLabel: "2018–2024", photoIDs: [firstPhoto.id], isHidden: false, sortOrder: 0)

        profileID = demoProfile.id
        name = demoProfile.name
        species = demoProfile.species
        year = String(demoProfile.departureYear)
        scope = .limited
        referenceAssetIdentifiers = demoProfile.referenceAssetIdentifiers
        document = ArchiveDocument(profile: demoProfile, photos: [firstPhoto, uncertainPhoto, excludedPhoto], chapters: [chapter])
        scanProgress = requestedRoute == .scan ? 0.42 : 1; scanCompletedAssets = requestedRoute == .scan ? 42 : 100; scanTotalAssets = 100; scanMatchCount = 2
        paused = requestedRoute == .scan
        isScanning = false
        style = .warmPaper
        purchased = false
        operationError = nil
        exportURL = nil
        route = requestedRoute
        container.router.reset()
        if requestedRoute != .welcome { container.router.navigate(to: requestedRoute) }
        return true
    }

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
        if let checkpoint = document?.scanCheckpoint {
            scanCompletedAssets = checkpoint.progress.completedAssets; scanTotalAssets = checkpoint.progress.totalAssets; scanMatchCount = checkpoint.candidates.count; scanProgress = Double(checkpoint.progress.completedAssets) / Double(max(checkpoint.progress.totalAssets, 1))
            paused = true
            go(.scan)
        }
    }

    private var photosBinding: Binding<[ArchivePhoto]> { Binding(get: { document?.photos ?? [] }, set: { updatePhotos($0) }) }
    private var chaptersBinding: Binding<[Chapter]> { Binding(get: { document?.chapters ?? [] }, set: { updateChapters($0) }) }
    private func updatePhotos(_ photos: [ArchivePhoto]) { guard var value = document else { return }; value.photos = photos; value.updatedAt = .now; document = value; persistDocument() }
    private func updateChapters(_ chapters: [Chapter]) { guard var value = document else { return }; value.chapters = chapters; value.updatedAt = .now; document = value; persistDocument() }
    private func persistDocument() { guard let document else { return }; Task { try? await container.repository.save(document: document) } }

    private func startScan() {
        guard !isScanning else { return }
        paused = false
        isScanning = true
        scanTask = Task {
            operationError = nil; scanProgress = 0; scanCompletedAssets = 0; scanTotalAssets = 0; scanMatchCount = 0
            var profile = document?.profile ?? PetProfile(id: profileID, name: name, species: species, departureYear: Int(year) ?? 2024, referenceAssetIdentifiers: referenceAssetIdentifiers, albumStyle: style)
            profile.lifecycle = .scanning
            let resumeCheckpoint = document?.scanCheckpoint
            document = ArchiveDocument(profile: profile, photos: document?.photos ?? [], chapters: document?.chapters ?? [], scanCheckpoint: resumeCheckpoint)
            persistDocument()
            do {
                let photos = try await container.scanner.scan(profile: profile, checkpoint: resumeCheckpoint) { checkpoint in
                    await MainActor.run {
                        guard var current = document, current.id == profile.id else { return }
                        current.profile.lifecycle = .scanning
                        current.photos = checkpoint.candidates
                        current.scanCheckpoint = checkpoint
                        current.updatedAt = .now
                        document = current
                        scanCompletedAssets = checkpoint.progress.completedAssets; scanTotalAssets = checkpoint.progress.totalAssets; scanMatchCount = checkpoint.candidates.count; scanProgress = Double(checkpoint.progress.completedAssets) / Double(max(checkpoint.progress.totalAssets, 1))
                        if checkpoint.progress.completedAssets.isMultiple(of: 12) || checkpoint.progress.completedAssets == checkpoint.progress.totalAssets { persistDocument() }
                    }
                }
                guard !Task.isCancelled else { return }
                profile.lifecycle = .ready
                document = ArchiveDocument(profile: profile, photos: photos, chapters: document?.chapters ?? [], scanCheckpoint: nil)
                persistDocument(); scanProgress = 1; isScanning = false; scanTask = nil
            } catch {
                isScanning = false; scanTask = nil
                if Task.isCancelled || error as? ScanFailure == .interrupted {
                    paused = true
                    persistDocument()
                } else {
                    operationError = error.localizedDescription
                    scanProgress = 0
                }
            }
        }
    }

    private func pauseScan() {
        guard isScanning else { return }
        scanTask?.cancel()
    }

    private func createTimeline() {
        guard var document else { return }
        let chosen = document.photos.filter { $0.decision == .selected }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: chosen) { photo in
            photo.createdAt.map { calendar.component(.year, from: $0) } ?? document.profile.departureYear
        }
        document.chapters = grouped.keys.sorted().enumerated().map { index, year in
            Chapter(id: UUID(), title: "Days together", dateLabel: String(year), photoIDs: grouped[year, default: []].map(\.id), isHidden: false, sortOrder: index)
        }
        if document.chapters.isEmpty { document.chapters = [Chapter(id: UUID(), title: "Days together", dateLabel: String(document.profile.departureYear), photoIDs: [], isHidden: false, sortOrder: 0)] }
        self.document = document; persistDocument(); go(.timeline)
    }

    private func purchase() {
        Task { operationError = nil; do { let state = try await container.purchase.purchaseUnlock(); if state == .entitled || state == .restored { purchased = true; go(.export) } else if case .failed(let message) = state { operationError = message } } catch { operationError = error.localizedDescription } }
    }
    private func restorePurchase() { Task { operationError = nil; do { let state = try await container.purchase.restorePurchases(); if state == .restored { purchased = true; go(.export) } else { operationError = "No previous Tailor purchase was found for this Apple ID." } } catch { operationError = error.localizedDescription } } }
    private func exportPDF() {
        guard let document else {
            operationError = "The archive could not be found. Return to the timeline and try again."
            return
        }
        Task { @MainActor in
            operationError = nil
            do {
                let output = try await container.pdfExporter.export(profile: document.profile, photos: document.photos, chapters: document.chapters, pageSize: .letter)
                guard var updated = self.document else { return }
                updated.profile.lifecycle = .exported
                updated.updatedAt = .now
                exportURL = output
                self.document = updated
                persistDocument()
            } catch {
                operationError = error.localizedDescription
            }
        }
    }
    private func restartArchive() { scanTask?.cancel(); scanTask = nil; isScanning = false; profileID = UUID(); name = ""; species = .dog; year = String(Calendar.current.component(.year, from: .now)); referenceAssetIdentifiers = []; document = nil; exportURL = nil; scanProgress = 0; route = .welcome; container.router.reset() }
    private func deleteArchive() { let id = profileID; Task { try? await container.repository.deleteArchive(id: id); try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: "\(id.uuidString)-life-archive.pdf")); restartArchive() } }
}
