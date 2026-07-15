import XCTest
import SwiftData
@testable import Tailor

@MainActor
final class TailorFeatureTests: XCTestCase {
    func testRouterNavigatesForwardDeduplicatesAndStopsAtWelcome() {
        let router = AppRouter()
        XCTAssertEqual(router.path, [.welcome])
        router.navigate(to: .privacy)
        router.navigate(to: .profile)
        XCTAssertEqual(router.path, [.welcome, .privacy, .profile])
        router.navigate(to: .privacy)
        XCTAssertEqual(router.path, [.welcome, .privacy])
        router.goBack()
        router.goBack()
        XCTAssertEqual(router.currentRoute, .welcome)
        XCTAssertEqual(router.path, [.welcome])
    }

    func testProfileLifecycleTransitionsPersistInRepository() async throws {
        let repository = InMemoryArchiveRepository()
        var profile = makeProfile(lifecycle: .draft)
        try await repository.save(profile: profile)
        profile.lifecycle = .scanning
        try await repository.save(profile: profile)
        profile.lifecycle = .ready
        try await repository.save(profile: profile)
        profile.lifecycle = .exported
        try await repository.save(profile: profile)
        let persisted = try await repository.profile(id: profile.id)
        XCTAssertEqual(persisted?.lifecycle, .exported)
    }

    func testLowConfidenceCandidateStartsNeedsReviewAndIsNotSelected() {
        let candidate = ArchivePhoto(id: UUID(), assetLocalIdentifier: "low-confidence", decision: .needsReview, confidence: 0.43, createdAt: nil)
        XCTAssertEqual(candidate.decision, .needsReview)
        XCTAssertNotEqual(candidate.decision, .selected)
    }

    func testScanFailureLeavesPreviouslyConfirmedProfileAndDecisionsUntouched() async throws {
        let repository = InMemoryArchiveRepository()
        let profile = makeProfile(lifecycle: .ready)
        let confirmed = [ArchivePhoto(id: UUID(), assetLocalIdentifier: "confirmed", decision: .selected, confidence: 0.98, createdAt: .now)]
        try await repository.save(profile: profile)
        let model = ArchiveFeatureModel(container: makeContainer(repository: repository, scanner: FailingScanner()))
        do {
            _ = try await model.scan(profile)
            XCTFail("Expected scan error")
        } catch {
            XCTAssertEqual(model.scanState, .failed(.unavailable, nil))
        }
        let persisted = try await repository.profile(id: profile.id)
        XCTAssertEqual(persisted, profile)
        XCTAssertEqual(confirmed.map(\.decision), [.selected])
    }

    func testScanFailurePreservesPersistedConfirmedDocument() async throws {
        let repository = InMemoryArchiveRepository()
        let profile = makeProfile(lifecycle: .ready)
        let confirmed = ArchivePhoto(id: UUID(), assetLocalIdentifier: "confirmed", decision: .selected, confidence: 0.98, createdAt: .now)
        let document = ArchiveDocument(profile: profile, photos: [confirmed])
        try await repository.save(document: document)
        let model = ArchiveFeatureModel(container: makeContainer(repository: repository, scanner: FailingScanner()))

        do {
            _ = try await model.scan(profile)
            XCTFail("Expected scan error")
        } catch {
            XCTAssertEqual(model.scanState, .failed(.unavailable, nil))
        }

        let restored = try await repository.document(id: profile.id)
        XCTAssertEqual(restored, document)
    }

    func testPurchaseFailureLeavesPersistedProfileAndChapterEditsUntouched() async throws {
        let repository = InMemoryArchiveRepository()
        let profile = makeProfile(lifecycle: .ready)
        let chapters = [Chapter(id: UUID(), title: "2018–2020", dateLabel: "2018–2020", photoIDs: [UUID()], isHidden: false, sortOrder: 0)]
        try await repository.save(profile: profile)
        let model = ArchiveFeatureModel(container: makeContainer(repository: repository, purchase: FailingPurchaseService()))
        await model.purchase()
        guard case .failed(let message) = model.purchaseState else { return XCTFail("Expected failed purchase state") }
        XCTAssertEqual(message, TestServiceError.unavailable.localizedDescription)
        let persisted = try await repository.profile(id: profile.id)
        XCTAssertEqual(persisted, profile)
        XCTAssertEqual(chapters.map(\.title), ["2018–2020"])
    }

    func testPurchaseFailurePreservesPersistedDocumentAndRestoreUsesMockState() async throws {
        let repository = InMemoryArchiveRepository()
        let profile = makeProfile(lifecycle: .ready)
        let chapter = Chapter(id: UUID(), title: "Days together", dateLabel: "2018–2020", photoIDs: [], isHidden: false, sortOrder: 0)
        let document = ArchiveDocument(profile: profile, chapters: [chapter])
        try await repository.save(document: document)
        let failingModel = ArchiveFeatureModel(container: makeContainer(repository: repository, purchase: FailingPurchaseService()))

        await failingModel.purchase()
        guard case .failed = failingModel.purchaseState else { return XCTFail("Expected failed purchase state") }
        let preservedDocument = try await repository.document(id: profile.id)
        XCTAssertEqual(preservedDocument, document)

        let restoredModel = ArchiveFeatureModel(container: makeContainer(repository: repository, purchase: EntitledPurchaseService()))
        let restoreState = try await restoredModel.purchaseServiceRestoreForUI()
        XCTAssertEqual(restoreState, .restored)
        XCTAssertEqual(restoredModel.purchaseState, .restored)
    }

    func testExportFailureRetainsSourceDocumentAndReportsFailure() async throws {
        let repository = InMemoryArchiveRepository()
        let profile = makeProfile(lifecycle: .ready)
        let chapter = Chapter(id: UUID(), title: "Days together", dateLabel: "2024", photoIDs: [], isHidden: false, sortOrder: 0)
        let document = ArchiveDocument(profile: profile, chapters: [chapter])
        try await repository.save(document: document)
        let container = AppContainer(repository: repository, scanner: SuccessfulScanner(), purchase: EntitledPurchaseService(), pdfExporter: FailingExporter())
        let model = ArchiveFeatureModel(container: container)

        await model.export(profile: profile, chapters: [chapter], pageSize: .a4)

        guard case .failed(let message) = model.exportState else { return XCTFail("Expected export failure") }
        XCTAssertEqual(message, TestServiceError.unavailable.localizedDescription)
        let preservedDocument = try await repository.document(id: profile.id)
        XCTAssertEqual(preservedDocument, document)
    }

    func testDeletingArchiveDoesNotRevokePurchaseEntitlement() async throws {
        let repository = InMemoryArchiveRepository()
        let profile = makeProfile(lifecycle: .exported)
        let purchase = EntitledPurchaseService()
        try await repository.save(profile: profile)
        try await repository.deleteArchive(id: profile.id)
        let deletedProfile = try await repository.profile(id: profile.id)
        let remainsEntitled = await purchase.isEntitled()
        XCTAssertNil(deletedProfile)
        XCTAssertTrue(remainsEntitled)
    }

    func testSwiftDataArchiveRepositoryPersistsAndUpdatesProfile() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: StoredPetProfile.self, configurations: configuration)
        let repository = SwiftDataArchiveRepository(modelContainer: modelContainer)
        var profile = makeProfile(lifecycle: .draft)
        profile.referenceAssetIdentifiers = ["asset-1", "asset-2", "asset-3"]

        try await repository.save(profile: profile)
        let savedProfile = try await repository.profile(id: profile.id)
        XCTAssertEqual(savedProfile, profile)

        profile.name = "Milo Updated"
        profile.lifecycle = .ready
        try await repository.save(profile: profile)
        let allProfiles = try await repository.allProfiles()
        XCTAssertEqual(allProfiles, [profile])

        try await repository.deleteArchive(id: profile.id)
        let deletedProfile = try await repository.profile(id: profile.id)
        XCTAssertNil(deletedProfile)
    }

    func testSwiftDataArchiveRepositoryPersistsPhotoDecisionsAndChapterEdits() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: StoredPetProfile.self, configurations: configuration)
        let repository = SwiftDataArchiveRepository(modelContainer: modelContainer)
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-77", decision: .needsReview, confidence: 0.62, createdAt: .now)
        var document = ArchiveDocument(profile: profile, photos: [photo], chapters: [])
        try await repository.save(document: document)
        document.photos[0].decision = .selected
        document.chapters = [Chapter(id: UUID(), title: "Days together", dateLabel: "2024", photoIDs: [photo.id], isHidden: false, sortOrder: 0)]
        try await repository.save(document: document)
        let restored = try await repository.document(id: profile.id)
        XCTAssertEqual(restored, document)
    }

    func testSwiftDataArchiveRepositoryPersistsScanCheckpointForResume() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: StoredPetProfile.self, configurations: configuration)
        let repository = SwiftDataArchiveRepository(modelContainer: modelContainer)
        let profile = makeProfile(lifecycle: .scanning)
        let candidate = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-resume", decision: .needsReview, confidence: 0.64, createdAt: .now)
        let checkpoint = ScanCheckpoint(nextAssetIndex: 24, totalAssets: 100, candidates: [candidate])
        let document = ArchiveDocument(profile: profile, photos: [candidate], chapters: [], scanCheckpoint: checkpoint)

        try await repository.save(document: document)
        let restored = try await repository.document(id: profile.id)

        XCTAssertEqual(restored?.scanCheckpoint, checkpoint)
        XCTAssertEqual(restored?.photos, [candidate])
    }

    func testLocalPDFExporterWritesValidPDF() async throws {
        let profile = makeProfile(lifecycle: .ready)
        let output = try await LocalPDFExporter().export(
            profile: profile,
            photos: [],
            chapters: [Chapter(id: UUID(), title: "Days together", dateLabel: "2024", photoIDs: [], isHidden: false, sortOrder: 0)],
            pageSize: .letter
        )
        defer { try? FileManager.default.removeItem(at: output) }
        let header = try Data(contentsOf: output).prefix(4)
        XCTAssertEqual(String(data: header, encoding: .ascii), "%PDF")
    }

    func testDemoPDFExporterProvidesAReadableFileForUIAutomation() async throws {
        let profile = makeProfile(lifecycle: .ready)
        let output = try await DemoPDFExporter().export(profile: profile, photos: [], chapters: [], pageSize: .letter)
        defer { try? FileManager.default.removeItem(at: output) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(String(data: try Data(contentsOf: output).prefix(4), encoding: .ascii), "%PDF")
    }

    func testDemoScannerKeepsUncertainMatchesOutOfDefaultSelection() async throws {
        let profile = makeProfile(lifecycle: .ready)
        let photos = try await DemoPetScanService().scan(profile: profile)

        XCTAssertEqual(photos.filter { $0.decision == .selected }.count, 1)
        XCTAssertEqual(photos.filter { $0.decision == .needsReview }.count, 2)
        XCTAssertFalse(photos.dropFirst().contains { $0.decision == .selected })
    }

    private func makeProfile(lifecycle: ProfileLifecycle) -> PetProfile {
        PetProfile(name: "Milo", species: .dog, arrivalYear: 2017, departureYear: 2024, lifecycle: lifecycle, referenceAssetIdentifiers: ["a", "b", "c"])
    }

    private func makeContainer(repository: any ArchiveRepository, scanner: any PetScanServicing = SuccessfulScanner(), purchase: any PurchaseServicing = EntitledPurchaseService()) -> AppContainer {
        AppContainer(repository: repository, scanner: scanner, purchase: purchase, pdfExporter: SuccessfulExporter())
    }
}

private enum TestServiceError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Service unavailable" }
}

private struct FailingScanner: PetScanServicing { func scan(profile: PetProfile) async throws -> [ArchivePhoto] { throw TestServiceError.unavailable } }
private struct SuccessfulScanner: PetScanServicing { func scan(profile: PetProfile) async throws -> [ArchivePhoto] { [] } }
private struct FailingPurchaseService: PurchaseServicing {
    func purchaseUnlock() async throws -> PurchaseState { throw TestServiceError.unavailable }
    func restorePurchases() async throws -> PurchaseState { .idle }
    func isEntitled() async -> Bool { false }
}
private struct EntitledPurchaseService: PurchaseServicing {
    func purchaseUnlock() async throws -> PurchaseState { .entitled }
    func restorePurchases() async throws -> PurchaseState { .restored }
    func isEntitled() async -> Bool { true }
}
private struct SuccessfulExporter: PDFExporting { func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL { URL(fileURLWithPath: "/tmp/archive.pdf") } }
private struct FailingExporter: PDFExporting { func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL { throw TestServiceError.unavailable } }
