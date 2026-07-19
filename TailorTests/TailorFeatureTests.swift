import XCTest
import SwiftData
import UIKit
import CoreText
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

    func testOnlyExplicitlySelectedNormalPhotosAreEligibleForAnArchive() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let normal = ArchivePhoto(id: UUID(), assetLocalIdentifier: "normal", decision: .selected, confidence: 0.96, createdAt: date)
        let review = ArchivePhoto(id: UUID(), assetLocalIdentifier: "review", decision: .needsReview, confidence: 0.96, createdAt: date)
        let sensitive = ArchivePhoto(id: UUID(), assetLocalIdentifier: "sensitive", decision: .selected, confidence: 0.96, createdAt: date, sensitivityState: .needsSensitiveReview)
        let deferred = ArchivePhoto(id: UUID(), assetLocalIdentifier: "deferred", decision: .selected, confidence: 0.96, createdAt: date, sensitivityState: .hiddenUntilUserDecides)
        let neverUse = ArchivePhoto(id: UUID(), assetLocalIdentifier: "never", decision: .selected, confidence: 0.96, createdAt: date, sensitivityState: .neverUse, excludedReason: .neverUse)

        XCTAssertTrue(normal.isEligibleForArchive)
        XCTAssertFalse(review.isEligibleForArchive)
        XCTAssertFalse(sensitive.isEligibleForArchive)
        XCTAssertFalse(deferred.isEligibleForArchive)
        XCTAssertFalse(neverUse.isEligibleForArchive)
    }

    func testLegacyPhotoDataDecodesAsNormalAndGetsLocalDateRange() throws {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let encodedDate = try JSONEncoder().encode(date)
        let dateString = String(data: encodedDate, encoding: .utf8)!
        let json = """
        {"id":"\(id.uuidString)","assetLocalIdentifier":"legacy","decision":"selected","confidence":0.99,"createdAt":\(dateString)}
        """.data(using: .utf8)!

        let photo = try JSONDecoder().decode(ArchivePhoto.self, from: json)

        XCTAssertEqual(photo.sensitivityState, .normal)
        XCTAssertNil(photo.excludedReason)
        XCTAssertNotNil(photo.localDateRange)
        XCTAssertTrue(photo.isEligibleForArchive)
    }

    func testNeverUseDecisionPersistsAndCannotBecomeEligibleAfterRoundTrip() throws {
        let neverUse = ArchivePhoto(
            id: UUID(), assetLocalIdentifier: "private-photo", decision: .selected,
            confidence: 0.91, createdAt: .now, sensitivityState: .neverUse,
            excludedReason: .neverUse
        )

        let restored = try JSONDecoder().decode(ArchivePhoto.self, from: JSONEncoder().encode(neverUse))

        XCTAssertEqual(restored.sensitivityState, .neverUse)
        XCTAssertEqual(restored.excludedReason, .neverUse)
        XCTAssertFalse(restored.isEligibleForArchive)
    }

    func testHiddenChapterRemainsMarkedHiddenAfterPersistenceRoundTrip() throws {
        let hidden = Chapter(id: UUID(), title: "2020", dateLabel: "2020", photoIDs: [UUID()], isHidden: true, sortOrder: 0)
        let restored = try JSONDecoder().decode(Chapter.self, from: JSONEncoder().encode(hidden))

        XCTAssertTrue(restored.isHidden)
        XCTAssertEqual(restored.photoIDs, hidden.photoIDs)
    }

    func testExistingChapterDataWithoutNoteRemainsReadable() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","title":"Days together","dateLabel":"2024","photoIDs":[],"isHidden":false,"sortOrder":0}
        """.data(using: .utf8)!
        let chapter = try JSONDecoder().decode(Chapter.self, from: json)
        XCTAssertEqual(chapter.note, "")
        XCTAssertEqual(chapter.title, "Days together")
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

    func testPurchasePendingAndCancelledDoNotGrantEntitlement() async {
        let repository = InMemoryArchiveRepository()
        let pendingModel = ArchiveFeatureModel(container: makeContainer(repository: repository, purchase: PendingPurchaseService()))
        await pendingModel.purchase()
        XCTAssertEqual(pendingModel.purchaseState, .pending)

        let cancelledModel = ArchiveFeatureModel(container: makeContainer(repository: repository, purchase: CancelledPurchaseService()))
        await cancelledModel.purchase()
        XCTAssertEqual(cancelledModel.purchaseState, .cancelled)
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
        document.recognitionFeedback = .make(from: document.photos)
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

    func testScanResumePolicyRejectsSameCountLibraryWhenIdentifiersChanged() {
        let original = ScanCatalogSnapshot(identifiers: ["a", "b", "c"])
        let changed = ScanCatalogSnapshot(identifiers: ["a", "replacement", "c"])
        let candidate = ArchivePhoto(id: UUID(), assetLocalIdentifier: "a", decision: .selected, confidence: 0.9, createdAt: .now, visualHash: 42)
        let checkpoint = ScanCheckpoint(nextAssetIndex: 2, totalAssets: 3, candidates: [candidate], assetCatalogFingerprint: original.fingerprint)

        XCTAssertEqual(ScanResumePolicy.startIndex(checkpoint: checkpoint, catalog: original), 2)
        XCTAssertEqual(ScanResumePolicy.startIndex(checkpoint: checkpoint, catalog: changed), 0)
        XCTAssertEqual(ScanResumePolicy.retainedCandidates(checkpoint: checkpoint, catalog: changed), [candidate])
    }

    func testScanReferenceAndRuntimePoliciesHaveDeterministicSafetyGates() {
        XCTAssertFalse(ScanReferencePolicy.isValid(requestedIdentifiers: ["a", "b"], resolvedCount: 2, usableFeatureCount: 2))
        XCTAssertFalse(ScanReferencePolicy.isValid(requestedIdentifiers: ["a", "b", "c"], resolvedCount: 3, usableFeatureCount: 2))
        XCTAssertTrue(ScanReferencePolicy.isValid(requestedIdentifiers: ["a", "b", "c"], resolvedCount: 3, usableFeatureCount: 3))
        XCTAssertEqual(ScanRuntimePolicy.pauseFailure(for: .init(isLowPowerModeEnabled: true, thermalLevel: .nominal)), .lowPower)
        XCTAssertEqual(ScanRuntimePolicy.pauseFailure(for: .init(isLowPowerModeEnabled: false, thermalLevel: .serious)), .thermal)
        XCTAssertNil(ScanRuntimePolicy.pauseFailure(for: .init(isLowPowerModeEnabled: false, thermalLevel: .fair)))
        XCTAssertFalse(ScanWorkloadPolicy.shouldGenerateEmbedding(animalConfidence: 0))
        XCTAssertTrue(ScanWorkloadPolicy.shouldGenerateEmbedding(animalConfidence: 0.01))
    }

    func testProductionUnavailableFallbackNeverReturnsDemoDataOrEntitlement() async {
        let repository = UnavailableArchiveRepository()
        do {
            _ = try await repository.allProfiles()
            XCTFail("Unavailable production storage must not return demo archives")
        } catch {
            XCTAssertEqual(error.localizedDescription, ProductionStorageUnavailableError.unavailable.localizedDescription)
        }
        let purchase = UnavailableProductionPurchase()
        let entitled = await purchase.isEntitled()
        XCTAssertFalse(entitled)
        do {
            _ = try await purchase.purchaseUnlock()
            XCTFail("Unavailable production storage must not create demo entitlement")
        } catch {
            XCTAssertEqual(error.localizedDescription, ProductionStorageUnavailableError.unavailable.localizedDescription)
        }
    }

    func testScanAuditCountsOneTerminalOutcomePerProcessedAsset() {
        var metrics = ScanAuditMetrics()
        ScanAuditPolicy.recording(.imageUnavailable, into: &metrics)
        ScanAuditPolicy.recording(.animalVisionFailure, into: &metrics)
        ScanAuditPolicy.recording(.speciesRejected, into: &metrics)
        ScanAuditPolicy.recording(.identityRejected, into: &metrics)
        ScanAuditPolicy.recording(.candidate, into: &metrics)
        XCTAssertEqual(metrics.processed, 5)
        XCTAssertEqual(metrics.imageUnavailable, 1)
        XCTAssertEqual(metrics.animalVisionFailures, 1)
        XCTAssertEqual(metrics.speciesRejected, 1)
        XCTAssertEqual(metrics.identityRejected, 1)
        XCTAssertEqual(metrics.candidates, 1)
    }

    func testDeletingLocalFeatureIndexRemovesPersistedProfileData() async throws {
        let directory = URL.temporaryDirectory.appending(path: "TailorFeatureIndex-\(UUID().uuidString)")
        let profileID = UUID()
        let index = PetFeaturePrintIndex(profileID: profileID, baseDirectory: directory)
        await index.storeSerializedFeatureData(Data([1, 2, 3]), for: "asset-a")
        await index.flush()
        let fileURL = PetFeaturePrintIndex.fileURL(profileID: profileID, baseDirectory: directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let reloaded = PetFeaturePrintIndex(profileID: profileID, baseDirectory: directory)
        await reloaded.load()
        let reloadedData = await reloaded.serializedFeatureData(for: "asset-a")
        XCTAssertEqual(reloadedData, Data([1, 2, 3]))

        await PetFeaturePrintIndex.delete(profileID: profileID, baseDirectory: directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let afterDelete = PetFeaturePrintIndex(profileID: profileID, baseDirectory: directory)
        await afterDelete.load()
        let deletedData = await afterDelete.serializedFeatureData(for: "asset-a")
        XCTAssertNil(deletedData)
        try? FileManager.default.removeItem(at: directory)
    }

    func testRecognitionPolicyRequiresMultiReferenceAgreementForHighAutoSelection() {
        let policy = PetRecognitionPolicy.standard
        let high = policy.assess(animalConfidence: 0.96, referenceSimilarities: [0.90, 0.82, 0.21])
        XCTAssertEqual(high.disposition, .autoSelected)
        XCTAssertEqual(high.agreeingReferenceCount, 2)

        let weakSingleReference = policy.assess(animalConfidence: 0.96, referenceSimilarities: [0.90, 0.20, 0.18])
        XCTAssertEqual(weakSingleReference.disposition, .needsReview)

        let wrongSpecies = policy.assess(animalConfidence: 0.25, referenceSimilarities: [0.95, 0.90, 0.87])
        XCTAssertEqual(wrongSpecies.disposition, .rejectedSpecies)
        let weakIdentity = policy.assess(animalConfidence: 0.95, referenceSimilarities: [0.40, 0.31, 0.20])
        XCTAssertEqual(weakIdentity.disposition, .rejectedIdentity)
    }

    func testRecognitionEvaluationReportsPrecisionRecallAndHighConfidenceFalsePositives() {
        let samples = [
            PetRecognitionLabeledSample(animalConfidence: 0.96, referenceSimilarities: [0.90, 0.82, 0.2], isTargetPet: true),
            PetRecognitionLabeledSample(animalConfidence: 0.88, referenceSimilarities: [0.46, 0.22, 0.18], isTargetPet: true),
            PetRecognitionLabeledSample(animalConfidence: 0.94, referenceSimilarities: [0.89, 0.81, 0.3], isTargetPet: false),
            PetRecognitionLabeledSample(animalConfidence: 0.20, referenceSimilarities: [0.95, 0.92, 0.88], isTargetPet: false)
        ]
        let report = PetRecognitionEvaluationReport.evaluate(samples, policy: .standard)
        XCTAssertEqual(report.evaluatedCount, 4)
        XCTAssertEqual(report.candidatePrecision, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(report.candidateRecall, 1, accuracy: 0.0001)
        XCTAssertEqual(report.highConfidenceCount, 2)
        XCTAssertEqual(report.highConfidenceFalsePositiveRate, 0.5, accuracy: 0.0001)
    }

    func testVisualDuplicatePolicyGroupsUndecidedFramesAndPreservesHistoricalDecisions() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let undecided = ArchivePhoto(id: UUID(), assetLocalIdentifier: "burst-1", decision: .needsReview, confidence: 0.7, createdAt: date, visualHash: 0b1010)
        XCTAssertEqual(
            VisualDuplicatePolicy.classify(hash: 0b1011, createdAt: date.addingTimeInterval(2), against: [undecided]),
            .grouped(anchorIdentifier: "burst-1", kind: .burst)
        )
        XCTAssertEqual(
            VisualDuplicatePolicy.classify(hash: 0b1011, createdAt: date.addingTimeInterval(20), against: [undecided]),
            .grouped(anchorIdentifier: "burst-1", kind: .reimport)
        )
        var decided = undecided
        decided.decision = .excluded
        decided.excludedReason = .userMarkedNotPet
        XCTAssertEqual(
            VisualDuplicatePolicy.classify(hash: 0b1011, createdAt: date, against: [decided]),
            .suppressedByHistoricalDecision(anchorIdentifier: "burst-1")
        )
    }

    func testRecognitionFeedbackIsLocalPersistentAggregate() throws {
        let highEvidence = PetRecognitionEvidence(policyVersion: 1, animalConfidence: 0.95, maximumReferenceSimilarity: 0.9, agreeingReferenceCount: 2, referenceCount: 3, wasHighAutoSelected: true)
        let selected = ArchivePhoto(id: UUID(), assetLocalIdentifier: "selected", decision: .selected, confidence: 0.94, createdAt: .now, recognitionEvidence: highEvidence)
        let falsePositive = ArchivePhoto(id: UUID(), assetLocalIdentifier: "false-positive", decision: .excluded, confidence: 0.91, createdAt: .now, excludedReason: .userMarkedNotPet, recognitionEvidence: highEvidence)
        let document = ArchiveDocument(profile: makeProfile(lifecycle: .ready), photos: [selected, falsePositive])
        XCTAssertEqual(document.recognitionFeedback.confirmedPetCount, 1)
        XCTAssertEqual(document.recognitionFeedback.confirmedNotPetCount, 1)
        XCTAssertEqual(document.recognitionFeedback.highAutoSelectedCount, 2)
        XCTAssertEqual(document.recognitionFeedback.highAutoFalsePositiveCount, 1)
        let restored = try JSONDecoder().decode(ArchiveDocument.self, from: JSONEncoder().encode(document))
        XCTAssertEqual(restored.recognitionFeedback, document.recognitionFeedback)
    }

    func testScanArchiveMergePreservesUserDecisionsChaptersBookAndExports() throws {
        let profile = makeProfile(lifecycle: .ready)
        let original = ArchivePhoto(id: UUID(), assetLocalIdentifier: "existing", decision: .excluded, confidence: 0.55, createdAt: .now, excludedReason: .userMarkedNotPet, visualHash: 11)
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: [original.id], isHidden: false, sortOrder: 0)
        let book = MemoryBookBuilder.build(profile: profile, photos: [original], chapters: [chapter], style: .warmPaper, pageSize: .letter)
        let record = MemoryBookExportRecord(fileName: "archive.pdf", pageCount: 2, pageSize: .letter, watermarked: false)
        let document = ArchiveDocument(profile: profile, photos: [original], chapters: [chapter], memoryBook: book, exportRecords: [record])
        let rescanned = ArchivePhoto(id: UUID(), assetLocalIdentifier: "existing", decision: .selected, confidence: 0.99, createdAt: .now, visualHash: 12)
        let fresh = ArchivePhoto(id: UUID(), assetLocalIdentifier: "new", decision: .needsReview, confidence: 0.65, createdAt: .now)

        let completed = ScanArchiveMergePolicy.completing(document: document, profile: profile, scanned: [rescanned, fresh])
        let retained = try XCTUnwrap(completed.photos.first(where: { $0.assetLocalIdentifier == "existing" }))
        XCTAssertEqual(retained.id, original.id)
        XCTAssertEqual(retained.decision, .excluded)
        XCTAssertEqual(retained.excludedReason, .userMarkedNotPet)
        XCTAssertEqual(retained.visualHash, 12)
        XCTAssertEqual(completed.chapters, [chapter])
        XCTAssertEqual(completed.memoryBook, book)
        XCTAssertEqual(completed.exportRecords, [record])
        XCTAssertNil(completed.scanCheckpoint)
    }

    func testIncrementalRescanCheckpointSeedsExistingCandidatesWithoutAssumingCatalogCount() {
        let profile = makeProfile(lifecycle: .ready)
        let kept = ArchivePhoto(id: UUID(), assetLocalIdentifier: "kept", decision: .selected, confidence: 0.92, createdAt: .now)
        let document = ArchiveDocument(profile: profile, photos: [kept])

        let checkpoint = ScanArchiveMergePolicy.checkpointForIncrementalRescan(document: document)

        XCTAssertEqual(checkpoint.nextAssetIndex, 0)
        XCTAssertEqual(checkpoint.totalAssets, 0)
        XCTAssertEqual(checkpoint.candidates, [kept])
        XCTAssertNil(checkpoint.assetCatalogFingerprint)
    }

    func testLocalPDFExporterRejectsArchiveWithoutAnySelectedPhoto() async throws {
        let profile = makeProfile(lifecycle: .ready)
        for chapters in [
            [Chapter(id: UUID(), title: "Days together", dateLabel: "2024", photoIDs: [], isHidden: false, sortOrder: 0)],
            []
        ] {
            do {
                _ = try await LocalPDFExporter().export(profile: profile, photos: [], chapters: chapters, pageSize: .letter)
                XCTFail("A keepsake without a selected photo must not be exported.")
            } catch let error as TailorServiceError {
                XCTAssertEqual(error, .bookHasBlockingIssues)
            }
        }
    }

    func testMemoryBookBuilderUsesEligiblePhotosAndCreatesChapterPages() {
        let profile = makeProfile(lifecycle: .ready)
        let selected = ArchivePhoto(id: UUID(), assetLocalIdentifier: "selected", decision: .selected, confidence: 0.95, createdAt: .now)
        let pending = ArchivePhoto(id: UUID(), assetLocalIdentifier: "pending", decision: .needsReview, confidence: 0.62, createdAt: .now)
        let chapter = Chapter(id: UUID(), title: "Days together", dateLabel: "2020–2024", photoIDs: [selected.id, pending.id], isHidden: false, sortOrder: 0)

        let book = MemoryBookBuilder.build(profile: profile, photos: [selected, pending], chapters: [chapter], style: .warmPaper, pageSize: .a4)

        XCTAssertEqual(book.pages.map(\.kind), [.cover, .dedication, .contents, .chapterOpener, .photoSelection, .closing])
        XCTAssertEqual(book.pages[4].photoIDs, [selected.id])
        XCTAssertEqual(book.eligiblePhotos, [selected])
    }

    func testMemoryBookBuilderKeepsChronologicalUserTitlesAndTemplateIndependentPageContent() {
        let profile = makeProfile(lifecycle: .ready)
        let early = ArchivePhoto(id: UUID(), assetLocalIdentifier: "early", decision: .selected, confidence: 0.94, createdAt: Date(timeIntervalSince1970: 1_514_764_800))
        let late = ArchivePhoto(id: UUID(), assetLocalIdentifier: "late", decision: .selected, confidence: 0.95, createdAt: Date(timeIntervalSince1970: 1_672_531_200))
        let laterChapter = Chapter(id: UUID(), title: "Lake days", dateLabel: "2023", note: "A user-written note.", photoIDs: [late.id], isHidden: false, sortOrder: 1)
        let earlierChapter = Chapter(id: UUID(), title: "Growing together", dateLabel: "2018", note: "", photoIDs: [early.id], isHidden: false, sortOrder: 0)

        let warm = MemoryBookBuilder.build(profile: profile, photos: [late, early], chapters: [laterChapter, earlierChapter], style: .warmPaper, pageSize: .letter)
        let night = MemoryBookBuilder.build(profile: profile, photos: [late, early], chapters: [laterChapter, earlierChapter], style: .quietNight, pageSize: .a4)

        XCTAssertEqual(warm.chapters.map(\.id), [earlierChapter.id, laterChapter.id])
        XCTAssertEqual(warm.pages.map(\.pageNumber), Array(1...8))
        XCTAssertEqual(warm.pages.map(\.kind), night.pages.map(\.kind))
        XCTAssertEqual(warm.pages.map(\.title), night.pages.map(\.title))
        XCTAssertEqual(warm.pages.filter { $0.kind == .chapterOpener }.map(\.title), ["Growing together", "Lake days"])
        XCTAssertFalse(warm.pages.map(\.title).joined(separator: " ").localizedCaseInsensitiveContains("first"))
        XCTAssertEqual(warm.style, .warmPaper)
        XCTAssertEqual(night.style, .quietNight)
        XCTAssertEqual(night.pageSize, .a4)
    }

    func testMemoryBookBuilderExcludesHiddenAndNeverUsePhotosFromEveryPageModel() {
        let profile = makeProfile(lifecycle: .ready)
        let allowed = ArchivePhoto(id: UUID(), assetLocalIdentifier: "allowed", decision: .selected, confidence: 0.95, createdAt: .now)
        let neverUse = ArchivePhoto(id: UUID(), assetLocalIdentifier: "never-use", decision: .selected, confidence: 0.95, createdAt: .now, sensitivityState: .neverUse)
        let hidden = Chapter(id: UUID(), title: "Hidden period", dateLabel: "2021", photoIDs: [allowed.id], isHidden: true, sortOrder: 0)
        let visible = Chapter(id: UUID(), title: "Visible period", dateLabel: "2022", photoIDs: [allowed.id, neverUse.id], isHidden: false, sortOrder: 1)

        let book = MemoryBookBuilder.build(profile: profile, photos: [allowed, neverUse], chapters: [hidden, visible], style: .fieldNotes, pageSize: .letter)

        XCTAssertEqual(book.chapters.map(\.id), [visible.id])
        XCTAssertFalse(book.pages.flatMap(\.photoIDs).contains(neverUse.id))
        XCTAssertFalse(book.pages.contains { $0.chapterID == hidden.id })
    }

    func testMemoryBookEditsRoundTripInsideArchiveDocument() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset", decision: .selected, confidence: 0.95, createdAt: .now)
        let chapter = Chapter(id: UUID(), title: "Days together", dateLabel: "2024", photoIDs: [photo.id], isHidden: false, sortOrder: 0)
        var book = MemoryBookBuilder.build(profile: profile, photos: [photo], chapters: [chapter], style: .warmPaper, pageSize: .letter)
        let editable = try XCTUnwrap(book.pages.first(where: { !$0.isLocked }))
        let index = try XCTUnwrap(book.pages.firstIndex(where: { $0.id == editable.id }))
        let imageIndex = try XCTUnwrap(book.pages[index].elements.firstIndex(where: { $0.kind == .image }))
        book.pages[index].elements[imageIndex].normalizedFrame.origin.x = 0.21
        book.pages[index].elements[imageIndex].cropScale = 1.35
        book.pages[index].elements[imageIndex].origin = .user
        book.pages[index].styleOverride = .cinema

        let archive = ArchiveDocument(profile: profile, photos: [photo], chapters: [chapter], memoryBook: book)
        let restored = try JSONDecoder().decode(ArchiveDocument.self, from: JSONEncoder().encode(archive))

        XCTAssertEqual(restored.memoryBook, book)
    }

    func testLegacyMemoryBookTextDefaultsToStandardStyle() throws {
        let element = MemoryBookElement(kind: .text, text: "A few words", normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.6, height: 0.08), textStyle: .large)
        let encoded = try JSONEncoder().encode(element)
        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "textStyle")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let restored = try JSONDecoder().decode(MemoryBookElement.self, from: legacyData)

        XCTAssertEqual(restored.textStyle, .standard)
    }

    func testAutoArrangePreservesUserTextAndLockedPhoto() throws {
        let profile = makeProfile(lifecycle: .ready)
        let first = ArchivePhoto(id: UUID(), assetLocalIdentifier: "first", decision: .selected, confidence: 0.95, createdAt: .now)
        let second = ArchivePhoto(id: UUID(), assetLocalIdentifier: "second", decision: .selected, confidence: 0.95, createdAt: .now)
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: [first.id, second.id], isHidden: false, sortOrder: 0)
        var book = MemoryBookBuilder.build(profile: profile, photos: [first, second], chapters: [chapter], style: .warmPaper, pageSize: .letter)
        let pageIndex = try XCTUnwrap(book.pages.firstIndex(where: { !$0.isLocked && $0.photoIDs.count == 2 }))
        let text = MemoryBookElement(kind: .text, text: "My own words", normalizedFrame: CGRect(x: 0.2, y: 0.8, width: 0.5, height: 0.06), zIndex: 20, isLayoutLocked: true, origin: .user)
        book.pages[pageIndex].elements.append(text)
        let lockedImageIndex = try XCTUnwrap(book.pages[pageIndex].elements.firstIndex(where: { $0.kind == .image }))
        book.pages[pageIndex].elements[lockedImageIndex].isLayoutLocked = true
        let lockedID = book.pages[pageIndex].elements[lockedImageIndex].id

        book.autoArrange(pageIDs: [book.pages[pageIndex].id])

        XCTAssertTrue(book.pages[pageIndex].elements.contains(where: { $0.id == text.id && $0.text == "My own words" }))
        XCTAssertTrue(book.pages[pageIndex].elements.contains(where: { $0.id == lockedID }))
    }

    func testDuplicateEditablePageCreatesFreshElementIdentifiersAndRenumbers() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset", decision: .selected, confidence: 0.95, createdAt: .now)
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: [photo.id], isHidden: false, sortOrder: 0)
        var book = MemoryBookBuilder.build(profile: profile, photos: [photo], chapters: [chapter], style: .warmPaper, pageSize: .letter)
        let page = try XCTUnwrap(book.pages.first(where: { !$0.isLocked }))
        let duplicateID = try XCTUnwrap(book.duplicatePage(id: page.id))
        let duplicate = try XCTUnwrap(book.pages.first(where: { $0.id == duplicateID }))

        XCTAssertEqual(book.pages.map(\.pageNumber), Array(1...book.pages.count))
        XCTAssertEqual(Set(page.elements.map(\.id)).intersection(Set(duplicate.elements.map(\.id))).count, 0)
    }

    func testBookCheckWarnsAboutDuplicatePhotoWithoutBlockingExport() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset", decision: .selected, confidence: 0.95, createdAt: .now)
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: [photo.id], isHidden: false, sortOrder: 0)
        var book = MemoryBookBuilder.build(profile: profile, photos: [photo], chapters: [chapter], style: .warmPaper, pageSize: .letter)
        let editableIndex = try XCTUnwrap(book.pages.firstIndex(where: { !$0.isLocked }))
        let duplicatePage = MemoryBookPage(kind: .photoSelection, title: "Again", chapterID: chapter.id, photoIDs: [photo.id], layout: .single, pageNumber: book.pages.count + 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: "Again", subtitle: "", photos: [photo.id], layout: .single))
        book.pages.insert(duplicatePage, at: editableIndex + 1)
        book.renumberPages()

        let issues = book.checkBook()

        XCTAssertTrue(issues.contains(where: { $0.severity == .suggestion && $0.message.contains("appears more than once") }))
        XCTAssertFalse(issues.contains(where: { $0.severity == .blocking && $0.message.contains("appears more than once") }))
    }

    func testSharedPageRenderPlanKeepsPaperGeometryAndTemplateRulesPlatformIndependent() {
        let letter = MemoryBookPageRenderPlan(pageSize: .letter, style: .warmPaper)
        XCTAssertEqual(letter.pageRect, CGRect(x: 0, y: 0, width: 612, height: 792))
        XCTAssertEqual(letter.paperRect, CGRect(x: 18, y: 18, width: 576, height: 756))
        let mapped = letter.rect(for: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.25))
        XCTAssertEqual(mapped.origin.x, 75.6, accuracy: 0.001)
        XCTAssertEqual(mapped.origin.y, 169.2, accuracy: 0.001)
        XCTAssertEqual(mapped.width, 288, accuracy: 0.001)
        XCTAssertEqual(mapped.height, 189, accuracy: 0.001)

        let a4 = MemoryBookPageRenderPlan(pageSize: .a4, style: .filmAlbum)
        XCTAssertEqual(a4.pageRect, CGRect(x: 0, y: 0, width: 595, height: 842))
        XCTAssertEqual(a4.paperRect.origin.x, 17.5, accuracy: 0.001)
        XCTAssertEqual(a4.paperRect.width, 560, accuracy: 0.001)
        XCTAssertTrue(a4.style.drawsFilmFrame)
        XCTAssertEqual(MemoryBookPageStyle.resolve(.cinema).imageTreatment, .mono)
        XCTAssertEqual(MemoryBookPageStyle.resolve(.warmPaper).imageTreatment, .original)

        let heading = MemoryBookElement(kind: .text, text: "Milo", normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 0.1), zIndex: 10)
        XCTAssertEqual(letter.fontToken(for: heading), .display)
        XCTAssertGreaterThan(letter.fontSize(for: heading, in: letter.rect(for: heading.normalizedFrame)), 11)

        let body = MemoryBookElement(kind: .text, text: "A note", normalizedFrame: CGRect(x: 0, y: 0.2, width: 1, height: 0.08), zIndex: 1)
        let page = MemoryBookPage(kind: .photoSelection, title: "Milo", pageNumber: 1, elements: [heading, body])
        let document = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let pagePlan = MemoryBookPageRenderPlan(page: page, document: document, pageSize: letter.pageSize)
        XCTAssertEqual(pagePlan.pageID, page.id)
        XCTAssertEqual(pagePlan.orderedElements.map(\.id), [body.id, heading.id])
    }

    func testSharedPageRenderPlanResolvesEveryTemplateForBothPaperSizes() {
        for style in AlbumStyle.allCases {
            for paper in PDFPageSize.allCases {
                let plan = MemoryBookPageRenderPlan(pageSize: paper, style: style)
                XCTAssertEqual(plan.paperRect.insetBy(dx: -plan.pageSize.width * MemoryBookPageRenderPlan.paperInsetRatio, dy: -plan.pageSize.width * MemoryBookPageRenderPlan.paperInsetRatio), plan.pageRect, "\\(style) / \\(paper) must use the one shared paper inset")
                XCTAssertGreaterThan(plan.paperRect.width, 0)
                XCTAssertGreaterThan(plan.paperRect.height, 0)
                XCTAssertNotEqual(plan.style.paper, plan.style.backdrop, "\\(style) needs an explicit paper/backdrop contract")

                if style == .cinema {
                    XCTAssertEqual(plan.style.imageTreatment, .mono)
                    XCTAssertNil(plan.filmFrameRect())
                } else if style == .filmAlbum {
                    XCTAssertEqual(plan.style.imageTreatment, .original)
                    XCTAssertNotNil(plan.filmFrameRect())
                    XCTAssertNotNil(plan.filmFrameLineWidth())
                    XCTAssertNotNil(plan.filmFrameDash())
                    XCTAssertNotNil(plan.filmImageBorderRect(in: plan.paperRect))
                } else {
                    XCTAssertEqual(plan.style.imageTreatment, .original)
                    XCTAssertNil(plan.filmFrameRect())
                    XCTAssertNil(plan.filmImageBorderRect(in: plan.paperRect))
                }
            }
        }

        XCTAssertEqual(MemoryBookTypography.displayPostScriptName, "IowanOldStyle-Roman")
    }

    func testRenderPlanFixtureKeepsEditorReaderAndPDFContractsEqualAcross70Pages() throws {
        for style in AlbumStyle.allCases {
            for paper in PDFPageSize.allCases {
                let book = renderPlanFixtureBook(style: style, paper: paper)
                let editorManifest = book.renderManifest(watermarked: true)
                let readerManifest = book.renderManifest(watermarked: true)
                // The PDF adapter receives this same immutable manifest before
                // it starts requesting higher-resolution PhotoKit images.
                let pdfManifest = book.renderManifest(watermarked: true)

                XCTAssertEqual(editorManifest, readerManifest, "Editor/Reader plan drift")
                XCTAssertEqual(readerManifest, pdfManifest, "Reader/PDF plan drift")
                XCTAssertEqual(try JSONDecoder().decode(MemoryBookRenderManifest.self, from: JSONEncoder().encode(editorManifest)), editorManifest)
                XCTAssertEqual(editorManifest.plans.count, 7)
                XCTAssertTrue(editorManifest.plans.allSatisfy { $0.watermark == .preview })
                XCTAssertTrue(editorManifest.plans.allSatisfy { $0.watermarkCenters().count == 2 })
                XCTAssertTrue(editorManifest.plans.allSatisfy { ($0.watermarkLetterSpacing() ?? 0) > 0 })

                let paidManifest = book.renderManifest(watermarked: false)
                XCTAssertEqual(paidManifest.plans.map(\.pageID), editorManifest.plans.map(\.pageID))
                XCTAssertEqual(paidManifest.plans.map(\.orderedElements), editorManifest.plans.map(\.orderedElements))
                XCTAssertTrue(paidManifest.plans.allSatisfy { $0.watermark == nil })

                for plan in editorManifest.plans {
                    XCTAssertEqual(plan.orderedElements, plan.orderedElements.sorted { $0.zIndex == $1.zIndex ? $0.id.uuidString < $1.id.uuidString : $0.zIndex < $1.zIndex })
                    XCTAssertTrue(plan.orderedElements.allSatisfy { element in
                        let rect = plan.rect(for: element.normalizedFrame)
                        return plan.paperRect.contains(rect)
                    })
                }
            }
        }
    }

    func testExplicitLayoutChangeMovesOverflowIntoNewChapterPagesWithoutLosingPhotos() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photos = (0..<6).map { index in
            ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-\(index)", decision: .selected, confidence: 1, createdAt: .now)
        }
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: photos.map(\.id), isHidden: false, sortOrder: 0)
        let page = MemoryBookPage(kind: .photoSelection, title: chapter.title, chapterID: chapter.id, photoIDs: photos.map(\.id), layout: .grid3x2, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: chapter.title, subtitle: "", photos: photos.map(\.id), layout: .grid3x2))
        var book = MemoryBookDocument(profile: profile, photos: photos, chapters: [chapter], pages: [page], style: .warmPaper, pageSize: .letter)

        let summary = try XCTUnwrap(book.layoutChangeSummary(pageID: page.id, layout: .grid2x2))
        XCTAssertEqual(summary.retainedPhotoCount, 4)
        XCTAssertEqual(summary.movedPhotoCount, 2)
        XCTAssertEqual(summary.newPageCount, 1)
        XCTAssertNotNil(book.applyLayoutChange(pageID: page.id, layout: .grid2x2))

        XCTAssertEqual(book.pages.count, 2)
        XCTAssertEqual(book.pages.map(\.pageNumber), [1, 2])
        XCTAssertEqual(book.pages[0].layout, .grid2x2)
        XCTAssertEqual(book.pages.flatMap(\.photoIDs), photos.map(\.id))
        XCTAssertEqual(Set(book.pages.flatMap(\.photoIDs)).count, photos.count)
    }

    func testLayoutShrinkPreservesLockedImageGeometryCropRotationAndLayer() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photos = (0..<6).map { index in
            ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-\(index)", decision: .selected, confidence: 1, createdAt: .now)
        }
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: photos.map(\.id), isHidden: false, sortOrder: 0)
        let page = MemoryBookPage(kind: .photoSelection, title: chapter.title, chapterID: chapter.id, photoIDs: photos.map(\.id), layout: .grid3x2, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: chapter.title, subtitle: "", photos: photos.map(\.id), layout: .grid3x2))
        var book = MemoryBookDocument(profile: profile, photos: photos, chapters: [chapter], pages: [page], style: .warmPaper, pageSize: .letter)
        let lockedIndex = try XCTUnwrap(book.pages[0].elements.firstIndex(where: { $0.assetID == photos[5].id }))
        book.pages[0].elements[lockedIndex].normalizedFrame = CGRect(x: 0.13, y: 0.27, width: 0.31, height: 0.29)
        book.pages[0].elements[lockedIndex].cropScale = 2.1
        book.pages[0].elements[lockedIndex].cropOffset = CGSize(width: 0.22, height: -0.17)
        book.pages[0].elements[lockedIndex].rotationDegrees = 15
        book.pages[0].elements[lockedIndex].zIndex = 42
        book.pages[0].elements[lockedIndex].isLayoutLocked = true
        let lockedBefore = book.pages[0].elements[lockedIndex]

        let summary = try XCTUnwrap(book.applyLayoutChange(pageID: page.id, layout: .grid2x2))

        XCTAssertEqual(summary.retainedPhotoCount, 4)
        XCTAssertEqual(summary.movedPhotoCount, 2)
        let lockedAfter = try XCTUnwrap(book.pages[0].elements.first(where: { $0.id == lockedBefore.id }))
        XCTAssertEqual(lockedAfter, lockedBefore)
        XCTAssertFalse(book.pages.dropFirst().flatMap(\.elements).contains(where: { $0.id == lockedBefore.id }))
        XCTAssertEqual(Set(book.pages.flatMap(\.photoIDs)), Set(photos.map(\.id)))
    }

    func testLayoutIsUnavailableForNoteAndStructuralPages() throws {
        let profile = makeProfile(lifecycle: .ready)
        let note = MemoryBookPage(kind: .photoSelection, title: "A note", layout: .note, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: "A note", subtitle: "Words", photos: [], layout: .note))
        var book = MemoryBookDocument(profile: profile, photos: [], chapters: [], pages: [note], style: .warmPaper, pageSize: .letter)

        XCTAssertNil(book.layoutChangeSummary(pageID: note.id, layout: .single))
        XCTAssertNil(book.applyLayoutChange(pageID: note.id, layout: .single))
        XCTAssertEqual(book.pages[0].layout, .note)
    }

    func testSixPhotosConvertToNoteAndMigrateInOriginalOrderWithinChapter() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photos = (0..<6).map { index in
            ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-\(index)", decision: .selected, confidence: 1, createdAt: .now)
        }
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: photos.map(\.id), isHidden: false, sortOrder: 0)
        let page = MemoryBookPage(kind: .photoSelection, title: chapter.title, chapterID: chapter.id, photoIDs: photos.map(\.id), layout: .grid3x2, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: chapter.title, subtitle: "", photos: photos.map(\.id), layout: .grid3x2))
        var book = MemoryBookDocument(profile: profile, photos: photos, chapters: [chapter], pages: [page], style: .warmPaper, pageSize: .letter)

        let summary = try XCTUnwrap(book.layoutChangeSummary(pageID: page.id, layout: .note))
        XCTAssertEqual(summary.retainedPhotoCount, 0)
        XCTAssertEqual(summary.movedPhotoCount, 6)
        XCTAssertEqual(summary.newPageCount, 1)
        XCTAssertEqual(summary.lockedPhotoCount, 0)
        XCTAssertNotNil(book.applyLayoutChange(pageID: page.id, layout: .note))

        XCTAssertEqual(book.pages.count, 2)
        XCTAssertEqual(book.pages[0].layout, .note)
        XCTAssertTrue(book.pages[0].photoIDs.isEmpty)
        XCTAssertFalse(book.pages[0].elements.contains(where: { $0.kind == .image }))
        XCTAssertEqual(book.pages[1].chapterID, chapter.id)
        XCTAssertEqual(book.pages[1].layout, .grid3x2)
        XCTAssertEqual(book.pages[1].photoIDs, photos.map(\.id))
        XCTAssertEqual(book.pages[1].elements.filter { $0.kind == .image }.compactMap(\.assetID), photos.map(\.id))
    }

    func testLayoutPreviewCancelLeavesCompleteCodableDocumentUntouched() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photos = (0..<6).map { index in ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-\(index)", decision: .selected, confidence: 1, createdAt: .now) }
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: photos.map(\.id), isHidden: false, sortOrder: 0)
        let page = MemoryBookPage(kind: .photoSelection, title: chapter.title, chapterID: chapter.id, photoIDs: photos.map(\.id), layout: .grid3x2, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: chapter.title, subtitle: "", photos: photos.map(\.id), layout: .grid3x2))
        let book = MemoryBookDocument(profile: profile, photos: photos, chapters: [chapter], pages: [page], style: .warmPaper, pageSize: .a4)
        let before = try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book))

        // The confirmation preview does not mutate. UI Cancel simply drops
        // this summary, so the persisted Codable document remains identical.
        _ = book.layoutChangeSummary(pageID: page.id, layout: .note)

        let after = try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(after, before)
    }

    func testLockedPhotosOverTargetCapacityAreCalledOutAndRemainOnSourcePage() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photos = (0..<3).map { index in ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-\(index)", decision: .selected, confidence: 1, createdAt: .now) }
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: photos.map(\.id), isHidden: false, sortOrder: 0)
        let page = MemoryBookPage(kind: .photoSelection, title: chapter.title, chapterID: chapter.id, photoIDs: photos.map(\.id), layout: .grid3x2, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: chapter.title, subtitle: "", photos: photos.map(\.id), layout: .grid3x2))
        var book = MemoryBookDocument(profile: profile, photos: photos, chapters: [chapter], pages: [page], style: .warmPaper, pageSize: .letter)
        for index in book.pages[0].elements.indices where book.pages[0].elements[index].kind == .image {
            book.pages[0].elements[index].isLayoutLocked = true
        }

        let summary = try XCTUnwrap(book.layoutChangeSummary(pageID: page.id, layout: .single))
        XCTAssertEqual(summary.lockedPhotoCount, 3)
        XCTAssertTrue(summary.hasLockedCapacityImpact)
        XCTAssertTrue(summary.message.contains("3 locked photos"))
        XCTAssertTrue(summary.message.contains("stay exactly where placed"))
        XCTAssertTrue(summary.message.contains("exceed"))
        XCTAssertNotNil(book.applyLayoutChange(pageID: page.id, layout: .single))
        XCTAssertEqual(book.pages.count, 1)
        XCTAssertEqual(book.pages[0].elements.filter { $0.kind == .image }.count, 3)
        XCTAssertEqual(book.pages[0].photoIDs, photos.map(\.id))
    }

    func testOverflowMigrationPreservesUserImageElementInsteadOfRegeneratingIt() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photos = (0..<6).map { index in ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-\(index)", decision: .selected, confidence: 1, createdAt: .now) }
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: photos.map(\.id), isHidden: false, sortOrder: 0)
        let page = MemoryBookPage(kind: .photoSelection, title: chapter.title, chapterID: chapter.id, photoIDs: photos.map(\.id), layout: .grid3x2, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: chapter.title, subtitle: "", photos: photos.map(\.id), layout: .grid3x2))
        var book = MemoryBookDocument(profile: profile, photos: photos, chapters: [chapter], pages: [page], style: .warmPaper, pageSize: .letter)
        let userIndex = try XCTUnwrap(book.pages[0].elements.firstIndex(where: { $0.assetID == photos[5].id }))
        book.pages[0].elements[userIndex].origin = .user
        book.pages[0].elements[userIndex].normalizedFrame = CGRect(x: 0.19, y: 0.44, width: 0.25, height: 0.21)
        book.pages[0].elements[userIndex].cropScale = 1.7
        book.pages[0].elements[userIndex].rotationDegrees = -12
        let userBefore = book.pages[0].elements[userIndex]

        XCTAssertNotNil(book.applyLayoutChange(pageID: page.id, layout: .grid2x2))
        let migrated = try XCTUnwrap(book.pages.dropFirst().flatMap(\.elements).first(where: { $0.id == userBefore.id }))
        XCTAssertEqual(migrated, userBefore)
    }

    func testTextOverflowIsBlockingAndFitTextOnlyChangesTypography() throws {
        let profile = makeProfile(lifecycle: .ready)
        let text = MemoryBookElement(kind: .text, text: "A remembered day", normalizedFrame: CGRect(x: 0.08, y: 0.08, width: 0.26, height: 0.08), zIndex: 10, textStyle: .large)
        let page = MemoryBookPage(kind: .dedication, title: "For Milo", pageNumber: 1, elements: [text])
        var book = MemoryBookDocument(profile: profile, photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)

        XCTAssertTrue(try XCTUnwrap(book.textMeasurement(for: text, on: page)).overflows)
        XCTAssertTrue(book.checkBook().contains(where: { $0.severity == .blocking && $0.message.contains("Text overflows") }))
        XCTAssertTrue(book.fitText(pageID: page.id, elementID: text.id))
        let fitted = try XCTUnwrap(book.pages[0].elements.first)
        XCTAssertEqual(fitted.normalizedFrame, text.normalizedFrame)
        XCTAssertEqual(fitted.textStyle, .small)
        XCTAssertFalse(try XCTUnwrap(book.textMeasurement(for: fitted, on: book.pages[0])).overflows)
        XCTAssertFalse(book.checkBook().contains(where: { $0.severity == .blocking && $0.message.contains("Text overflows") }))
    }

    func testBookCheckBlocksAnExistingPhotoWhenSharedAvailabilityRejectsIt() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "removed-photo", decision: .selected, confidence: 1, createdAt: .now)
        let page = MemoryBookPage(
            kind: .photoSelection,
            title: "Days together",
            pageNumber: 1,
            elements: [MemoryBookElement(kind: .image, assetID: photo.id, normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.6), zIndex: 1)]
        )
        let book = MemoryBookDocument(profile: profile, photos: [photo], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)

        let issue = try XCTUnwrap(book.checkBook(assetIsAvailable: { _ in false }).first(where: { $0.severity == .blocking }))
        XCTAssertEqual(issue.pageID, page.id)
        XCTAssertEqual(issue.elementID, page.elements[0].id)
        XCTAssertEqual(issue.message, "A photo is no longer available. Replace it before export.")
    }

    func testBookCheckTextIssueTargetsItsFieldAndExporterCreatesNoPDFWhenBlocked() async throws {
        let profile = makeProfile(lifecycle: .ready)
        let text = MemoryBookElement(
            kind: .text,
            text: String(repeating: "W", count: 121),
            normalizedFrame: CGRect(x: 0.08, y: 0.08, width: 0.20, height: 0.04),
            zIndex: 10,
            textStyle: .large,
            textField: .dedicationMessage
        )
        let page = MemoryBookPage(kind: .dedication, title: "For Milo", pageNumber: 1, elements: [text])
        let book = MemoryBookDocument(profile: profile, photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let issue = try XCTUnwrap(book.checkBook().first(where: { $0.message.contains("Text") }))
        XCTAssertEqual(issue.pageID, page.id)
        XCTAssertEqual(issue.elementID, text.id)
        XCTAssertEqual(issue.field, .dedicationMessage)

        let directory = FileManager.default.temporaryDirectory.appending(path: "tailor-blocked-export-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let before = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        do {
            _ = try await LocalPDFExporter(outputDirectory: directory).export(document: book)
            XCTFail("A blocking Book Check issue must reject export.")
        } catch let error as TailorServiceError {
            guard case .bookHasBlockingIssues = error else {
                return XCTFail("Unexpected export error: \(error)")
            }
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil), before)
    }

    func testPhotoCaptionLimitBlocksTheSameBuilderDocumentUsedByEditorFixtures() throws {
        var book = p02TextFixtureBook(style: .warmPaper, paper: .letter)
        let pageIndex = try XCTUnwrap(book.pages.firstIndex(where: { $0.kind == .photoSelection }))
        let captionIndex = try XCTUnwrap(book.pages[pageIndex].elements.firstIndex(where: { $0.textField == .photoCaption }))
        let captionID = book.pages[pageIndex].elements[captionIndex].id
        book.pages[pageIndex].elements[captionIndex].text = String(repeating: "n", count: 121)

        let issue = try XCTUnwrap(book.checkBook().first(where: { $0.elementID == captionID && $0.message.contains("longer than") }))
        XCTAssertEqual(issue.pageID, book.pages[pageIndex].id)
        XCTAssertEqual(issue.field, .photoCaption)
    }

    func testBuiltPhotoPageCaptionLimitBlocksBeforeAnyEditorInteraction() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "fixture-photo", decision: .selected, confidence: 1, createdAt: .now)
        let chapter = Chapter(id: UUID(), title: "Days together", dateLabel: "2018–2019", photoIDs: [photo.id], isHidden: false, sortOrder: 0)
        var book = MemoryBookBuilder.build(profile: profile, photos: [photo], chapters: [chapter], style: .warmPaper, pageSize: .letter)
        let pageIndex = try XCTUnwrap(book.pages.firstIndex(where: { $0.kind == .photoSelection }))
        let captionIndex = try XCTUnwrap(book.pages[pageIndex].elements.firstIndex(where: { $0.textField == .photoCaption }))
        let captionID = book.pages[pageIndex].elements[captionIndex].id
        book.pages[pageIndex].elements[captionIndex].text = String(repeating: "n", count: 121)

        let issue = try XCTUnwrap(book.checkBook().first(where: { $0.elementID == captionID && $0.message.contains("longer than") }))
        XCTAssertEqual(issue.field, .photoCaption)
    }

    func testArchiveExportRecordsRoundTripWithoutPersistingSandboxPaths() throws {
        let profile = makeProfile(lifecycle: .exported)
        let record = MemoryBookExportRecord(
            fileName: "\(profile.id.uuidString)-life-archive-20260717.pdf",
            exportedAt: Date(timeIntervalSince1970: 1_784_256_000),
            pageCount: 12,
            pageSize: .a4,
            watermarked: false
        )
        let archive = ArchiveDocument(profile: profile, exportRecords: [record])
        let decoded = try JSONDecoder().decode(ArchiveDocument.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(decoded.exportRecords, [record])
        XCTAssertEqual(decoded.exportRecords.first?.fileURL.lastPathComponent, record.fileName)
    }

    func testExportSnapshotFreezesRenderManifestUntilTheNextExport() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset", decision: .selected, confidence: 1, createdAt: .now)
        let page = MemoryBookPage(kind: .photoSelection, title: "Days", photoIDs: [photo.id], layout: .single, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: "Days", subtitle: "", photos: [photo.id], layout: .single))
        var book = MemoryBookDocument(profile: profile, photos: [photo], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let first = book.exportSnapshot()
        book.pages[0].elements.append(MemoryBookElement(kind: .text, text: "A later edit", normalizedFrame: CGRect(x: 0.1, y: 0.8, width: 0.4, height: 0.1), zIndex: 12, textField: .photoCaption, origin: .user))
        let second = book.exportSnapshot()

        XCTAssertNotEqual(first.fingerprint, second.fingerprint)
        XCTAssertFalse(first.manifest.plans.flatMap(\.orderedElements).contains { $0.text == "A later edit" })
        XCTAssertTrue(second.manifest.plans.flatMap(\.orderedElements).contains { $0.text == "A later edit" })
    }

    func testTextLimitAndDraftMeasurementUseCurrentTextStyleAndPageKind() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset", decision: .selected, confidence: 1, createdAt: .now)
        let page = MemoryBookPage(kind: .photoSelection, title: "Days", photoIDs: [photo.id], layout: .single, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: "Days", subtitle: "", photos: [photo.id], layout: .single))
        var book = MemoryBookDocument(profile: profile, photos: [photo], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let frame = CGRect(x: 0.1, y: 0.8, width: 0.18, height: 0.05)
        let measurement = book.textMeasurement(text: String(repeating: "x", count: 90), style: .large, normalizedFrame: frame, on: page)

        XCTAssertEqual(book.textCharacterLimit(on: page), 120)
        XCTAssertTrue(measurement.overflows)
        book.pages[0].elements.append(MemoryBookElement(kind: .text, text: String(repeating: "x", count: 121), normalizedFrame: frame, zIndex: 20))
        XCTAssertTrue(book.checkBook().contains(where: { $0.severity == .blocking && $0.message.contains("longer than this page allows") }))
        let note = MemoryBookPage(kind: .dedication, title: "For Milo", pageNumber: 2)
        XCTAssertEqual(book.textCharacterLimit(on: note), 240)
    }

    func testCropCommitClampsNoBlankEdgesAndPersistsWhileDraftDoesNot() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset", decision: .selected, confidence: 1, createdAt: .now)
        let page = MemoryBookPage(kind: .photoSelection, title: "Days", photoIDs: [photo.id], layout: .single, pageNumber: 1, elements: MemoryBookBuilder.elements(kind: .photoSelection, title: "Days", subtitle: "", photos: [photo.id], layout: .single))
        var book = MemoryBookDocument(profile: profile, photos: [photo], chapters: [], pages: [page], style: .warmPaper, pageSize: .a4)
        let element = try XCTUnwrap(book.pages[0].elements.first(where: { $0.kind == .image }))
        let before = element

        // A crop draft is local until Done calls applyCrop.
        XCTAssertEqual(book.pages[0].elements.first(where: { $0.id == element.id }), before)
        XCTAssertTrue(book.applyCrop(pageID: page.id, elementID: element.id, scale: 0.2, offset: CGSize(width: 9, height: -9)))
        let committed = try XCTUnwrap(book.pages[0].elements.first(where: { $0.id == element.id }))
        XCTAssertEqual(committed.cropScale, 1)
        XCTAssertEqual(committed.cropOffset, .zero)
        XCTAssertTrue(book.applyCrop(pageID: page.id, elementID: element.id, scale: 2, offset: CGSize(width: 9, height: -9)))
        let clamped = try XCTUnwrap(book.pages[0].elements.first(where: { $0.id == element.id }))
        XCTAssertEqual(clamped.cropScale, 2)
        XCTAssertEqual(clamped.cropOffset.width, 0.5, accuracy: 0.0001)
        XCTAssertEqual(clamped.cropOffset.height, -0.5, accuracy: 0.0001)
        let restored = try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(restored.pages[0].elements.first(where: { $0.id == element.id })?.cropOffset, clamped.cropOffset)
    }

    func testEditorAppearancePersistsAndFitNeverDistortsThePhoto() throws {
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "appearance", decision: .selected, confidence: 1, createdAt: .now, pixelSize: CGSize(width: 1_600, height: 900))
        let element = MemoryBookElement(
            kind: .image,
            assetID: photo.id,
            normalizedFrame: CGRect(x: 0.12, y: 0.2, width: 0.5, height: 0.48),
            rotationDegrees: 14,
            zIndex: 6,
            imageContentMode: .fit
        )
        let geometry = MemoryBookImageTransformGeometry(container: CGRect(x: 0, y: 0, width: 300, height: 300), sourceAspect: photo.aspectRatio, element: element)
        let rect = geometry.sourceRect(sourcePixelSize: CGSize(width: 1_600, height: 900))
        XCTAssertEqual(rect.width / rect.height, photo.aspectRatio, accuracy: 0.0001)
        XCTAssertEqual(rect.midX, 150, accuracy: 0.0001)
        XCTAssertEqual(rect.midY, 150, accuracy: 0.0001)

        let text = MemoryBookElement(kind: .text, text: "A hand written note", normalizedFrame: CGRect(x: 0.1, y: 0.7, width: 0.6, height: 0.1), rotationDegrees: -8, zIndex: 12, textStyle: .large, textFont: .handwritten, textColor: .clay, textField: .legacyUserNote, origin: .user)
        let encoded = try JSONEncoder().encode([element, text])
        let restored = try JSONDecoder().decode([MemoryBookElement].self, from: encoded)
        XCTAssertEqual(restored[0].imageContentMode, MemoryBookImageContentMode.fit)
        XCTAssertEqual(restored[1].textFont, MemoryBookTextFont.handwritten)
        XCTAssertEqual(restored[1].textColor, MemoryBookTextColor.clay)
        XCTAssertEqual(restored[1].rotationDegrees, -8)
    }

    func testLegacyEditorElementDecodesWithExistingFillTreatment() throws {
        let raw = """
        {"id":"00000000-0000-0000-0000-000000000001","kind":"image","normalizedFrame":{"origin":{"x":0,"y":0},"size":{"width":0.5,"height":0.5}},"cropScale":1,"cropOffset":{"width":0,"height":0},"rotationDegrees":0,"zIndex":0,"textStyle":"standard","isLayoutLocked":false,"origin":"automatic","updatedAt":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MemoryBookElement.self, from: raw)
        XCTAssertEqual(decoded.imageContentMode, MemoryBookImageContentMode.fill)
        XCTAssertEqual(decoded.textFont, MemoryBookTextFont.editorial)
        XCTAssertEqual(decoded.textColor, MemoryBookTextColor.ink)
    }

    /// F-P02-CROP: deterministic source dimensions stand in for six local
    /// images. Geometry code only needs dimensions; production renderers keep
    /// the corresponding PhotoKit identifier and never copy image bytes.
    func testP02CropFixtureKeepsEveryAspectAndRotationInsideItsFrame() {
        let fixture: [(name: String, sourceAspect: CGFloat, containerAspect: CGFloat, rotation: Double)] = [
            ("landscape", 4 / 3, 3 / 4, 0),
            ("portrait", 3 / 4, 4 / 3, 15),
            ("square-marker", 1, 16 / 9, -15),
            ("ultra-wide", 21 / 9, 3 / 4, 0),
            ("ultra-tall", 9 / 21, 4 / 3, 15),
            ("center-marker-replacement", 16 / 10, 1, -15)
        ]

        for item in fixture {
            let constraint = FillCropConstraint(
                sourceAspect: item.sourceAspect,
                containerAspect: item.containerAspect,
                rotationDegrees: item.rotation
            )
            let minimum = constraint.normalized(scale: 0.01, offset: .zero)
            XCTAssertGreaterThanOrEqual(minimum.scale, constraint.minimumScale, item.name)
            XCTAssertFalse(constraint.containsBlankEdge(scale: minimum.scale, offset: minimum.offset), item.name)

            // A deliberately illegal drag must be projected to a stable legal
            // point; a legal crop must stay untouched rather than jump.
            let extreme = constraint.normalized(scale: max(minimum.scale + 0.4, 1.5), offset: CGSize(width: 8, height: -8))
            XCTAssertFalse(constraint.containsBlankEdge(scale: extreme.scale, offset: extreme.offset), item.name)
            let valid = constraint.normalized(scale: extreme.scale, offset: extreme.offset)
            XCTAssertEqual(valid.scale, extreme.scale, accuracy: 0.0001, item.name)
            XCTAssertEqual(valid.offset.width, extreme.offset.width, accuracy: 0.0001, item.name)
            XCTAssertEqual(valid.offset.height, extreme.offset.height, accuracy: 0.0001, item.name)
        }
    }

    func testCropSessionCancelResetAndDoneAreSeparateTransactions() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "F-P02-CROP-portrait", decision: .selected, confidence: 1, createdAt: .now, pixelSize: CGSize(width: 900, height: 1_600))
        let element = MemoryBookElement(kind: .image, assetID: photo.id, normalizedFrame: CGRect(x: 0.12, y: 0.18, width: 0.72, height: 0.36), cropScale: 1, cropOffset: .zero, rotationDegrees: 15, zIndex: 3)
        let page = MemoryBookPage(kind: .photoSelection, title: "Days", photoIDs: [photo.id], layout: .single, pageNumber: 1, elements: [element])
        var book = MemoryBookDocument(profile: profile, photos: [photo], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let entrySnapshot = book

        var session = MemoryBookCropSession(pageID: page.id, element: element, sourceAspect: photo.aspectRatio)
        session.update(scale: 2.2, offset: CGSize(width: 3, height: -3))
        XCTAssertTrue(session.hasUncommittedChanges)
        XCTAssertFalse(session.constraint.containsBlankEdge(scale: session.draftTransform.scale, offset: session.draftTransform.offset))
        // Cancel/Discard merely drops this local value. The encoded document
        // and thus its undo baseline are byte-for-byte unchanged.
        XCTAssertEqual(try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book)), entrySnapshot)

        session.reset()
        XCTAssertFalse(session.hasUncommittedChanges)
        XCTAssertEqual(try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book)), entrySnapshot)

        session.update(scale: 2.1, offset: CGSize(width: -2, height: 2))
        let baseline = book // what the editor pushes exactly once on Done
        XCTAssertTrue(book.applyCrop(pageID: page.id, elementID: element.id, scale: session.draftTransform.scale, offset: session.draftTransform.offset, sourceAspect: photo.aspectRatio))
        XCTAssertNotEqual(book, baseline)
        XCTAssertEqual(baseline.pages[0].elements[0], session.historyBaseline)
        // Undo is restoration of the one entry recorded before Done.
        book = baseline
        XCTAssertEqual(try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book)), entrySnapshot)
    }

    func testReplacingPhotoPreservesUserGeometryAndNormalizesNewAssetCrop() throws {
        let profile = makeProfile(lifecycle: .ready)
        let old = ArchivePhoto(id: UUID(), assetLocalIdentifier: "F-P02-CROP-wide", decision: .selected, confidence: 1, createdAt: .now, pixelSize: CGSize(width: 2_100, height: 900))
        let replacement = ArchivePhoto(id: UUID(), assetLocalIdentifier: "F-P02-CROP-tall", decision: .selected, confidence: 1, createdAt: .now, pixelSize: CGSize(width: 800, height: 1_800))
        let element = MemoryBookElement(kind: .image, assetID: old.id, normalizedFrame: CGRect(x: 0.21, y: 0.17, width: 0.48, height: 0.66), cropScale: 1.8, cropOffset: CGSize(width: 0.14, height: -0.08), rotationDegrees: -15, zIndex: 9, isLayoutLocked: true, origin: .user)
        let frame = element.normalizedFrame, rotation = element.rotationDegrees, layer = element.zIndex
        let page = MemoryBookPage(kind: .photoSelection, title: "Days", photoIDs: [old.id], layout: .single, pageNumber: 1, elements: [element])
        var book = MemoryBookDocument(profile: profile, photos: [old, replacement], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        XCTAssertTrue(book.replacePhoto(pageID: page.id, elementID: element.id, with: replacement.id))
        let replaced = try XCTUnwrap(book.pages[0].elements.first)
        let constraint = FillCropConstraint(sourceAspect: replacement.aspectRatio, containerAspect: frame.width / frame.height, rotationDegrees: rotation)

        XCTAssertEqual(replaced.assetID, replacement.id)
        XCTAssertEqual(replaced.normalizedFrame, frame)
        XCTAssertEqual(replaced.rotationDegrees, rotation)
        XCTAssertEqual(replaced.zIndex, layer)
        XCTAssertTrue(replaced.isLayoutLocked)
        XCTAssertEqual(replaced.origin, .user)
        XCTAssertFalse(constraint.containsBlankEdge(scale: replaced.cropScale, offset: replaced.cropOffset))

        // Production replacement then feeds the exact same transformed
        // element into reader (screen plan) and both PDF paper plans.  Assert
        // the geometry at each concrete destination rather than merely the
        // stored crop fields, so a replacement cannot reveal a white edge.
        for size in [CGSize(width: 390, height: 520), MemoryBookPageRenderPlan.points(for: .letter), MemoryBookPageRenderPlan.points(for: .a4)] {
            let plan = MemoryBookPageRenderPlan(page: book.pages[0], document: book, pageSize: size)
            let rendered = try XCTUnwrap(plan.orderedElements.first(where: { $0.id == replaced.id }))
            let geometry = MemoryBookImageTransformGeometry(container: plan.rect(for: rendered.normalizedFrame), sourceAspect: replacement.aspectRatio, element: rendered)
            let concrete = FillCropConstraint(sourceAspect: replacement.aspectRatio, containerAspect: geometry.container.width / geometry.container.height, rotationDegrees: geometry.rotationDegrees)
            XCTAssertFalse(concrete.containsBlankEdge(scale: geometry.transform.scale, offset: geometry.transform.offset), "replacement must fill reader/PDF destination \(size)")
        }
    }

    func testSharedImageTransformGeometryKeepsRotatedCropLegalAcrossPreviewAndPDFSizes() {
        let element = MemoryBookElement(kind: .image, assetID: UUID(), normalizedFrame: CGRect(x: 0.1, y: 0.22, width: 0.72, height: 0.41), cropScale: 2.1, cropOffset: CGSize(width: 0.19, height: -0.17), rotationDegrees: 15)
        let source = CGSize(width: 900, height: 1_600)
        for container in [CGRect(x: 38, y: 120, width: 320, height: 182), CGRect(x: 61, y: 180, width: 510, height: 290)] {
            let geometry = MemoryBookImageTransformGeometry(container: container, sourceAspect: source.width / source.height, element: element)
            let constraint = FillCropConstraint(sourceAspect: source.width / source.height, containerAspect: container.width / container.height, rotationDegrees: 15)
            XCTAssertEqual(geometry.rotationDegrees, 15)
            XCTAssertFalse(constraint.containsBlankEdge(scale: geometry.transform.scale, offset: geometry.transform.offset))
            XCTAssertGreaterThan(geometry.sourceRect(sourcePixelSize: source).width, 0)
            XCTAssertGreaterThan(geometry.sourceRect(sourcePixelSize: source).height, 0)
        }
    }

    func testCropExitPolicyAndResetDoneUndoBaseline() throws {
        XCTAssertEqual(MemoryBookCropExitPolicy.policy(hasDraft: false), .dismissImmediately)
        XCTAssertEqual(MemoryBookCropExitPolicy.policy(hasDraft: true), .requireDecision)
        for source in MemoryBookCropExitSource.allCases {
            var state: MemoryBookCropExitState = .editing
            state.requestExit(source, hasDraft: true)
            XCTAssertEqual(state, .awaitingDecision(source), "Dirty \(source) must request an explicit decision")
            state.keepEditing()
            XCTAssertEqual(state, .editing)
            state.requestExit(source, hasDraft: false)
            XCTAssertEqual(state, .dismissed, "Clean \(source) may dismiss")
        }
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "crop-reset", decision: .selected, confidence: 1, createdAt: .now, pixelSize: CGSize(width: 1_600, height: 900))
        let element = MemoryBookElement(kind: .image, assetID: photo.id, normalizedFrame: CGRect(x: 0.12, y: 0.22, width: 0.72, height: 0.36), cropScale: 2.1, cropOffset: CGSize(width: 0.11, height: -0.07), rotationDegrees: -15, zIndex: 8)
        let page = MemoryBookPage(kind: .photoSelection, title: "Days", photoIDs: [photo.id], layout: .single, pageNumber: 1, elements: [element])
        var book = MemoryBookDocument(profile: profile, photos: [photo], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let baseline = book // editor Undo stack entry immediately before Done
        var session = MemoryBookCropSession(pageID: page.id, element: element, sourceAspect: photo.aspectRatio)
        session.reset() // confirmation belongs to UI; this is its post-confirm action
        XCTAssertTrue(book.applyCrop(pageID: page.id, elementID: element.id, scale: session.draftTransform.scale, offset: session.draftTransform.offset, sourceAspect: photo.aspectRatio))
        XCTAssertNotEqual(book.pages[0].elements[0].cropScale, baseline.pages[0].elements[0].cropScale)
        book = baseline // Undo restores crop, rotation, frame and z-index atomically.
        XCTAssertEqual(book.pages[0].elements[0], element)
    }

    func testCommittedCropIsIdenticalInPreviewAndBothPaperRenderPlans() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "F-P02-CROP-marker", decision: .selected, confidence: 1, createdAt: .now, pixelSize: CGSize(width: 1_600, height: 900))
        let element = MemoryBookElement(kind: .image, assetID: photo.id, normalizedFrame: CGRect(x: 0.1, y: 0.22, width: 0.75, height: 0.48), rotationDegrees: 15, zIndex: 5)
        let page = MemoryBookPage(kind: .photoSelection, title: "Days", photoIDs: [photo.id], layout: .single, pageNumber: 1, elements: [element])
        var letter = MemoryBookDocument(profile: profile, photos: [photo], chapters: [], pages: [page], style: .quietNight, pageSize: .letter)
        XCTAssertTrue(letter.applyCrop(pageID: page.id, elementID: element.id, scale: 2.15, offset: CGSize(width: 3, height: -3), sourceAspect: photo.aspectRatio))
        var a4 = letter
        a4.pageSize = .a4

        let previewElement = try XCTUnwrap(letter.renderPlans().first?.orderedElements.first(where: { $0.id == element.id }))
        let letterElement = try XCTUnwrap(letter.renderManifest().plans.first?.orderedElements.first(where: { $0.id == element.id }))
        let a4Element = try XCTUnwrap(a4.renderManifest().plans.first?.orderedElements.first(where: { $0.id == element.id }))
        XCTAssertEqual(previewElement.assetID, letterElement.assetID)
        XCTAssertEqual(previewElement.assetID, a4Element.assetID)
        XCTAssertEqual(previewElement.normalizedFrame, letterElement.normalizedFrame)
        XCTAssertEqual(previewElement.normalizedFrame, a4Element.normalizedFrame)
        XCTAssertEqual(previewElement.cropScale, letterElement.cropScale)
        XCTAssertEqual(previewElement.cropScale, a4Element.cropScale)
        XCTAssertEqual(previewElement.cropOffset, letterElement.cropOffset)
        XCTAssertEqual(previewElement.cropOffset, a4Element.cropOffset)
        XCTAssertEqual(previewElement.rotationDegrees, a4Element.rotationDegrees)
        XCTAssertEqual(previewElement.zIndex, a4Element.zIndex)
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

    // MARK: - F-P02-TEXT / B1

    func testTextFieldWhitelistMatchesEveryPageSemanticAndRejectsContents() throws {
        let book = p02TextFixtureBook(style: .warmPaper, paper: .letter)
        let expected: [MemoryBookPageKind: Set<MemoryBookTextField>] = [
            .cover: [.coverPetName, .coverSubtitle, .coverYearRange],
            .dedication: [.dedicationMessage],
            .contents: [],
            .chapterOpener: [.chapterTitle, .chapterDateRange, .chapterNote],
            .photoSelection: [.photoTitle, .photoCaption],
            .milestone: [.milestoneDate, .milestoneNote],
            .closing: [.closingMessage]
        ]
        for page in book.pages {
            XCTAssertEqual(Set(book.editableTextFields(on: page)), expected[page.kind])
            for element in page.elements where element.kind == .text {
                if let field = element.textField {
                    XCTAssertTrue(field.isAllowed(on: page.kind), "\(field) cannot appear on \(page.kind)")
                }
            }
        }
        XCTAssertTrue(MemoryBookTextField.allowed(on: .contents).isEmpty)
        XCTAssertFalse(MemoryBookTextField.photoCaption.isAllowed(on: .cover))
    }

    func testLegacyTextFieldMigrationPreservesUnicodeAndOnlyAdoptsUserNotes() throws {
        let legacyUser = MemoryBookElement(kind: .text, text: "مرحبا 点点 👨‍👩‍👧‍👦\ne\u{301}", normalizedFrame: CGRect(x: 0.1, y: 0.58, width: 0.7, height: 0.12), zIndex: 20, origin: .user)
        let legacySystem = MemoryBookElement(kind: .text, text: "System subtitle", normalizedFrame: CGRect(x: 0.1, y: 0.22, width: 0.7, height: 0.06), zIndex: 9)
        let legacyTitle = MemoryBookElement(kind: .text, text: "Days together", normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.7, height: 0.1), zIndex: 10)
        let page = MemoryBookPage(kind: .photoSelection, title: "Days together", subtitle: "System subtitle", layout: .single, pageNumber: 1, elements: [legacyTitle, legacySystem, legacyUser])
        let original = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let migrated = original.migratedLegacyTextFields()
        let elements = migrated.pages[0].elements

        // UI may inspect this temporary view on opening Text, but opening it
        // must not persist roles before the user explicitly saves an edit.
        XCTAssertNil(original.pages[0].elements[0].textField)
        XCTAssertNil(original.pages[0].elements[1].textField)
        XCTAssertNil(original.pages[0].elements[2].textField)
        XCTAssertEqual(elements[0].textField, .photoTitle)
        XCTAssertEqual(elements[1].textField, .photoCaption)
        XCTAssertEqual(elements[2].textField, .legacyUserNote)
        XCTAssertEqual(elements[2].text, legacyUser.text)
        XCTAssertEqual(try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(migrated)), migrated)
    }

    func testTextGraphemeLimitsAndUnicodeRoundTripDoNotSplitVisibleCharacters() throws {
        let book = p02TextFixtureBook(style: .quietNight, paper: .a4)
        let photoPage = try XCTUnwrap(book.pages.first(where: { $0.kind == .photoSelection }))
        let dedicationPage = try XCTUnwrap(book.pages.first(where: { $0.kind == .dedication }))
        let photoCaption = try XCTUnwrap(photoPage.elements.first(where: { $0.textField == .photoCaption }))
        let dedication = try XCTUnwrap(dedicationPage.elements.first(where: { $0.textField == .dedicationMessage }))
        let family = "👨‍👩‍👧‍👦"
        let combining = "e\u{301}"
        let caption120 = String(repeating: family, count: 120)
        let dedication240 = String(repeating: combining, count: 240)

        XCTAssertEqual(family.count, 1)
        XCTAssertEqual(combining.count, 1)
        XCTAssertEqual(caption120.count, 120)
        XCTAssertEqual(dedication240.count, 240)
        XCTAssertEqual(book.textCharacterLimit(for: photoCaption, on: photoPage), 120)
        XCTAssertEqual(book.textCharacterLimit(for: dedication, on: dedicationPage), 240)
        XCTAssertEqual((caption120 + family).count, 121)
        XCTAssertEqual((dedication240 + combining).count, 241)

        let arabic = "مرحبا بكم في أيام نقطة\n点点的日子 (family) (combining)"
        let roundTrip = try JSONDecoder().decode(String.self, from: JSONEncoder().encode(arabic))
        XCTAssertEqual(roundTrip, arabic)
    }

    func testTextLayoutUsesDistinctSizeTokensAndActualLineBoxes() throws {
        let book = p02TextFixtureBook(style: .filmAlbum, paper: .letter)
        let page = try XCTUnwrap(book.pages.first(where: { $0.kind == .photoSelection }))
        let frame = CGRect(x: 0.10, y: 0.64, width: 0.24, height: 0.11)
        let value = "WWWW WWWW WWWW\nمرحبا 点点 👨‍👩‍👧‍👦"
        let small = book.textLayout(text: value, style: .small, normalizedFrame: frame, on: page, zIndex: 20, field: .photoCaption)
        let standard = book.textLayout(text: value, style: .standard, normalizedFrame: frame, on: page, zIndex: 20, field: .photoCaption)
        let large = book.textLayout(text: value, style: .large, normalizedFrame: frame, on: page, zIndex: 20, field: .photoCaption)

        XCTAssertLessThan(small.spec.fontSize, standard.spec.fontSize)
        XCTAssertLessThan(standard.spec.fontSize, large.spec.fontSize)
        XCTAssertGreaterThan(large.measurement.requiredLines, 0)
        XCTAssertEqual(large.measurement.requiredLines, large.measurement.lineBoxes.count)
        XCTAssertGreaterThan(large.measurement.occupiedRect.height, 0)
        XCTAssertGreaterThan(large.spec.lineHeight, large.spec.fontSize)
        XCTAssertFalse(large.spec.protectedRects.isEmpty)

        let short = book.textMeasurement(text: "WW", style: .large, normalizedFrame: frame, on: page, zIndex: 20, field: .photoCaption)
        let long = book.textMeasurement(text: String(repeating: "WW", count: 24), style: .large, normalizedFrame: frame, on: page, zIndex: 20, field: .photoCaption)
        XCTAssertGreaterThan(long.requiredLines, short.requiredLines, "line wrapping must come from Core Text, not a fixed character estimate")
    }

    func testDraftOneAdditionalGraphemeChangesActualOverflowNotCharacterHeuristic() throws {
        let book = p02TextFixtureBook(style: .warmPaper, paper: .letter)
        let photoPage = try XCTUnwrap(book.pages.first(where: { $0.kind == .photoSelection }))
        let dedicationPage = try XCTUnwrap(book.pages.first(where: { $0.kind == .dedication }))
        let grapheme = "n" // one complete visible Swift Character, never a UTF-16 fragment
        let caption120 = String(repeating: grapheme, count: 119) + "\n"
        let dedication240 = String(repeating: grapheme, count: 239) + "\n"
        // Fixed paper-normalized frames and the current TextLayoutSpec body
        // token. The final newline is a real Core Text line boundary: at this
        // width 120/240 visible Characters consume exactly 12/24 line boxes;
        // appending one whole grapheme requires the 13th/25th box.
        let captionFrame = CGRect(x: 0.10, y: 0.52, width: 0.145, height: 0.310)
        let dedicationFrame = CGRect(x: 0.10, y: 0.24, width: 0.145, height: 0.600)

        let captionFit = book.textLayout(text: caption120, style: .standard, normalizedFrame: captionFrame, on: photoPage, zIndex: 9, field: .photoCaption)
        let captionPlusOne = book.textLayout(text: caption120 + grapheme, style: .standard, normalizedFrame: captionFrame, on: photoPage, zIndex: 9, field: .photoCaption)
        let dedicationFit = book.textLayout(text: dedication240, style: .standard, normalizedFrame: dedicationFrame, on: dedicationPage, zIndex: 9, field: .dedicationMessage)
        let dedicationPlusOne = book.textLayout(text: dedication240 + grapheme, style: .standard, normalizedFrame: dedicationFrame, on: dedicationPage, zIndex: 9, field: .dedicationMessage)

        XCTAssertEqual(caption120.count, 120)
        XCTAssertEqual((caption120 + grapheme).count, 121)
        XCTAssertEqual(dedication240.count, 240)
        XCTAssertEqual((dedication240 + grapheme).count, 241)
        XCTAssertTrue(captionFit.spec.editableRect.contains(captionFit.spec.textRect))
        XCTAssertTrue(dedicationFit.spec.editableRect.contains(dedicationFit.spec.textRect))
        XCTAssertEqual(captionFit.measurement.availableLines, captionFit.measurement.requiredLines)
        XCTAssertEqual(dedicationFit.measurement.availableLines, dedicationFit.measurement.requiredLines)
        XCTAssertFalse(captionFit.measurement.overflows)
        XCTAssertTrue(captionPlusOne.measurement.overflows)
        XCTAssertFalse(dedicationFit.measurement.overflows)
        XCTAssertTrue(dedicationPlusOne.measurement.overflows)
        XCTAssertEqual(captionPlusOne.measurement.requiredLines, captionFit.measurement.requiredLines + 1, "caption fit=\(captionFit.measurement.requiredLines), plusOne=\(captionPlusOne.measurement.requiredLines)")
        XCTAssertEqual(dedicationPlusOne.measurement.requiredLines, dedicationFit.measurement.requiredLines + 1, "dedication fit=\(dedicationFit.measurement.requiredLines), plusOne=\(dedicationPlusOne.measurement.requiredLines)")
    }

    func testTextRenderContractUsesExplicitUIKitAndCoreTextResolvableFonts() throws {
        for style in AlbumStyle.allCases {
            for paper in PDFPageSize.allCases {
                let book = p02TextFixtureBook(style: style, paper: paper)
                for snapshot in book.renderPlans().flatMap(\.textLayouts) {
                    let spec = snapshot.spec
                    let resolved = try XCTUnwrap(UIFont(name: spec.fontPostScriptName, size: spec.fontSize))
                    XCTAssertEqual(resolved.fontName, spec.fontPostScriptName)
                    XCTAssertNotNil(UIFont(name: spec.fallbackPostScriptName, size: spec.fontSize))

                    let coreText = CTFontCreateWithName(spec.fontPostScriptName as CFString, spec.fontSize, nil)
                    XCTAssertEqual(CTFontCopyPostScriptName(coreText) as String, spec.fontPostScriptName)

                    let preview = MemoryBookPreviewTextAdapter.attributedString(for: snapshot, color: .black)
                    let pdf = MemoryBookPDFTextAdapter.attributedString(for: snapshot, color: .black)
                    XCTAssertTrue(preview.isEqual(to: pdf))
                    let attributedFont = try XCTUnwrap(preview.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                    XCTAssertEqual(attributedFont.fontName, spec.fontPostScriptName)
                }
            }
        }
    }

    func testTextEditableRectClampsAwayFromProtectedFooter() throws {
        let book = p02TextFixtureBook(style: .warmPaper, paper: .letter)
        let page = try XCTUnwrap(book.pages.first(where: { $0.kind == .photoSelection }))
        let element = try XCTUnwrap(page.elements.first(where: { $0.textField == .photoCaption }))
        let plan = try XCTUnwrap(book.renderPlans().first(where: { $0.pageID == page.id }))
        let clamped = plan.clampedTextFrame(CGRect(x: -0.4, y: 0.94, width: 1.2, height: 0.4), for: element)
        let concrete = plan.rect(for: clamped)
        let layout = try XCTUnwrap(plan.textLayout(for: element))

        XCTAssertTrue(layout.spec.editableRect.contains(concrete))
        XCTAssertFalse(concrete.intersects(layout.spec.protectedRects[0]))
    }

    func testTextSafeAnchorAvoidsEveryProtectedRectIncludingWatermarks() throws {
        let book = p02TextFixtureBook(style: .warmPaper, paper: .letter)
        let page = try XCTUnwrap(book.pages.first(where: { $0.kind == .photoSelection }))
        let element = try XCTUnwrap(page.elements.first(where: { $0.textField == .photoCaption }))
        let plan = try XCTUnwrap(book.renderPlans(watermarked: true).first(where: { $0.pageID == page.id }))
        let layout = try XCTUnwrap(plan.textLayout(for: element))
        let protected = try XCTUnwrap(layout.spec.protectedRects.dropFirst().first)
        let attempted = CGRect(
            x: (protected.minX - plan.paperRect.minX) / plan.paperRect.width,
            y: (protected.minY - plan.paperRect.minY) / plan.paperRect.height,
            width: element.normalizedFrame.width,
            height: element.normalizedFrame.height
        )
        let clamped = plan.clampedTextFrame(attempted, for: element)
        let concrete = plan.rect(for: clamped)
        XCTAssertTrue(layout.spec.editableRect.contains(concrete))
        XCTAssertFalse(layout.spec.protectedRects.contains(where: { concrete.intersects($0) }))
    }

    func testFP02TextManifestContainsLineBoxesForEveryTemplateAndPaper() throws {
        var manifests = [MemoryBookRenderManifest]()
        for style in AlbumStyle.allCases {
            for paper in PDFPageSize.allCases {
                let book = p02TextFixtureBook(style: style, paper: paper)
                let preview = book.renderManifest(watermarked: true)
                let pdfAdapter = book.renderManifest(watermarked: true)
                XCTAssertEqual(preview, pdfAdapter, "\(style) / \(paper) preview/PDF adapter drift")
                XCTAssertEqual(preview.plans.count, 7)
                XCTAssertTrue(preview.plans.allSatisfy { !$0.textLayouts.isEmpty })
                XCTAssertTrue(preview.plans.flatMap(\.textLayouts).allSatisfy { !$0.measurement.lineBoxes.isEmpty })
                XCTAssertTrue(preview.plans.flatMap(\.textLayouts).allSatisfy { $0.spec.fontSize > 0 && $0.spec.lineHeight >= $0.spec.fontSize })
                let chapterNote = try XCTUnwrap(preview.plans.flatMap(\.textLayouts).first(where: { $0.field == .chapterNote }))
                XCTAssertTrue(chapterNote.value.contains("مرحبا"), "\(style) / \(paper) must include Arabic in the actual manifest")
                XCTAssertTrue(chapterNote.value.contains("点点"), "\(style) / \(paper) must include CJK in the actual manifest")
                XCTAssertTrue(chapterNote.value.contains("👨‍👩‍👧‍👦"), "\(style) / \(paper) must include a ZWJ emoji in the actual manifest")
                XCTAssertTrue(chapterNote.value.contains("e\u{301}"), "\(style) / \(paper) must include a combining grapheme in the actual manifest")
                XCTAssertTrue(chapterNote.value.contains("\n"), "\(style) / \(paper) must include an explicit line break in the actual manifest")
                XCTAssertEqual(chapterNote.spec.writingDirection, .rightToLeft, "RTL direction must be inferred from real Arabic content")
                XCTAssertGreaterThanOrEqual(chapterNote.measurement.requiredLines, 2)
                manifests.append(preview)
            }
        }
        let evidenceDirectory = URL(fileURLWithPath: "/tmp/tailor-p02-text-b1-evidence", isDirectory: true)
        try FileManager.default.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
        let evidenceURL = evidenceDirectory.appending(path: "F-P02-TEXT-line-box-manifest.json")
        try JSONEncoder().encode(manifests).write(to: evidenceURL, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: evidenceURL.path))
        XCTAssertEqual(try JSONDecoder().decode([MemoryBookRenderManifest].self, from: Data(contentsOf: evidenceURL)), manifests)
    }

    func testPreviewAndPDFAdaptersConsumeTheSameAttributedParagraphContract() throws {
        let book = p02TextFixtureBook(style: .quietNight, paper: .a4)
        let manifest = book.renderManifest(watermarked: true)
        for snapshot in manifest.plans.flatMap(\.textLayouts) {
            let preview = MemoryBookPreviewTextAdapter.contract(for: snapshot)
            let pdf = MemoryBookPDFTextAdapter.contract(for: snapshot)
            XCTAssertEqual(preview, pdf)
            XCTAssertEqual(preview.spec.fontPostScriptName, snapshot.spec.fontPostScriptName)
            XCTAssertEqual(preview.spec.fallbackPostScriptName, snapshot.spec.fallbackPostScriptName)
            XCTAssertEqual(preview.spec.kern, snapshot.spec.kern)
            XCTAssertEqual(preview.spec.alignment, snapshot.spec.alignment)
            XCTAssertEqual(preview.spec.writingDirection, snapshot.spec.writingDirection)
            XCTAssertEqual(preview.spec.lineHeight, snapshot.spec.lineHeight)
            XCTAssertEqual(preview.spec.textRect, snapshot.spec.textRect)
            XCTAssertEqual(preview.measurement.lineBoxes, snapshot.measurement.lineBoxes)
        }
        let rtl = try XCTUnwrap(manifest.plans.flatMap(\.textLayouts).first(where: { $0.field == .chapterNote }))
        XCTAssertEqual(MemoryBookPreviewTextAdapter.contract(for: rtl).spec.writingDirection, .rightToLeft)
        XCTAssertEqual(MemoryBookPDFTextAdapter.contract(for: rtl).spec.writingDirection, .rightToLeft)
    }

    /// Produces a reproducible PDF evidence set without touching the developer's
    /// Photos library. This is deliberately a renderer baseline, not a design
    /// pixel-signoff: SwiftUI-vs-PDF heatmaps still require approved references.
    func testDeterministicPDFEvidenceCoversEveryTemplatePaperAndPageKind() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appending(path: "tailor-pdf-visual-evidence-v1", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        var totalPages = 0
        for style in AlbumStyle.allCases {
            for paper in PDFPageSize.allCases {
                let book = renderPlanFixtureBook(style: style, paper: paper)
                let fixtureImages = Dictionary(uniqueKeysWithValues: (1...7).compactMap { index in
                    MemoryBookVisualQAAsset.image(identifier: "fixture-photo-\(index)").map { ("fixture-photo-\(index)", $0) }
                })
                let provider = DeterministicMemoryBookAssetProvider(images: fixtureImages)
                let folder = root
                    .appending(path: style.rawValue, directoryHint: .isDirectory)
                    .appending(path: paper.rawValue, directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

                let exporter = LocalPDFExporter(
                    outputDirectory: folder,
                    imageProvider: provider,
                    imageTargetSize: CGSize(width: 1_600, height: 1_600)
                )
                let fixtureIssues = book.checkBook(assetIsAvailable: { provider.isAvailable(identifier: $0.assetLocalIdentifier) })
                XCTAssertFalse(
                    fixtureIssues.contains(where: { $0.severity == .blocking }),
                    "F-RP-01 must remain exportable: \(fixtureIssues.map { "page=\($0.pageID?.uuidString ?? "none") element=\($0.elementID?.uuidString ?? "none") \($0.message)" }.joined(separator: " | "))"
                )
                let exported = try await exporter.export(document: book, watermarked: false, progress: { _, _ in })
                let pdf = try XCTUnwrap(CGPDFDocument(exported as CFURL))
                let manifest = book.exportSnapshot(watermarked: false).manifest

                XCTAssertEqual(pdf.numberOfPages, manifest.plans.count, "\(style)/\(paper) page count")
                XCTAssertEqual(book.renderManifest(watermarked: false), manifest, "\(style)/\(paper) must export the shared render manifest")
                XCTAssertEqual(manifest.plans.map(\.pageID), book.pages.map(\.id), "\(style)/\(paper) manifest identity")
                XCTAssertEqual(Set(book.pages.map(\.kind)), Set([.cover, .dedication, .contents, .chapterOpener, .photoSelection, .milestone, .closing]))
                XCTAssertGreaterThan((try Data(contentsOf: exported)).count, 2_048, "PDF must contain rendered content")

                let expectedSize = MemoryBookPageRenderPlan.points(for: paper)
                var pageMetrics = [PDFVisualEvidencePageMetric]()
                for index in 1...pdf.numberOfPages {
                    let pdfPage = try XCTUnwrap(pdf.page(at: index))
                    let mediaBox = pdfPage.getBoxRect(.mediaBox)
                    XCTAssertEqual(mediaBox.width, expectedSize.width, accuracy: 0.5, "\(style)/\(paper) width")
                    XCTAssertEqual(mediaBox.height, expectedSize.height, accuracy: 0.5, "\(style)/\(paper) height")

                    let raster = rasterize(pdfPage: pdfPage, longestSide: 720)
                    let png = try XCTUnwrap(raster.pngData())
                    let rasterURL = folder.appending(path: String(format: "pdf-raster-%02d.png", index))
                    try png.write(to: rasterURL, options: .atomic)
                    let sampledColors = sampledColorCount(in: raster)
                    XCTAssertGreaterThan(sampledColors, 4, "\(style)/\(paper) page \(index) must not be blank")
                    XCTAssertGreaterThan(png.count, 1_024, "\(style)/\(paper) page \(index) raster must be nonempty")
                    pageMetrics.append(.init(
                        pageNumber: index,
                        pageKind: book.pages[index - 1].kind.rawValue,
                        widthPoints: mediaBox.width,
                        heightPoints: mediaBox.height,
                        pngBytes: png.count,
                        sampledColorCount: sampledColors
                    ))
                }

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(manifest).write(to: folder.appending(path: "manifest.json"), options: .atomic)
                let metrics = PDFVisualEvidenceMetrics(
                    style: style.rawValue,
                    paper: paper.rawValue,
                    pageCount: pdf.numberOfPages,
                    pdfBytes: (try Data(contentsOf: exported)).count,
                    pages: pageMetrics,
                    evidenceScope: "Deterministic PDF raster and manifest evidence only; not an approved-reference pixel comparison."
                )
                try encoder.encode(metrics).write(to: folder.appending(path: "metrics.json"), options: .atomic)
                let result = """
                Tailor PDF visual evidence\n
                style: \(style.rawValue)\n
                paper: \(paper.rawValue)\n
                pages: \(pdf.numberOfPages)\n
                scope: deterministic PDF/manifest/raster evidence only; no approved-design pixel sign-off.\n
                """
                try result.write(to: folder.appending(path: "result.md"), atomically: true, encoding: .utf8)
                totalPages += pdf.numberOfPages
            }
        }

        XCTAssertEqual(totalPages, AlbumStyle.allCases.count * PDFPageSize.allCases.count * 7)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "warmPaper/letter/manifest.json").path))
    }

    private func deterministicFixtureImage(style: AlbumStyle) -> UIImage {
        let size = CGSize(width: 1_200, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let base: UIColor = switch style {
            case .warmPaper: UIColor(red: 0.91, green: 0.77, blue: 0.57, alpha: 1)
            case .quietNight: UIColor(red: 0.10, green: 0.25, blue: 0.23, alpha: 1)
            case .fieldNotes: UIColor(red: 0.48, green: 0.63, blue: 0.44, alpha: 1)
            case .cinema: UIColor(red: 0.43, green: 0.43, blue: 0.43, alpha: 1)
            case .filmAlbum: UIColor(red: 0.36, green: 0.24, blue: 0.16, alpha: 1)
            }
            base.setFill(); cg.fill(CGRect(origin: .zero, size: size))
            UIColor.white.withAlphaComponent(0.90).setFill()
            cg.fillEllipse(in: CGRect(x: 310, y: 220, width: 480, height: 360))
            UIColor(red: 0.12, green: 0.29, blue: 0.24, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 485, y: 340, width: 130, height: 115))
            UIColor(red: 0.72, green: 0.34, blue: 0.22, alpha: 1).setFill()
            cg.fill(CGRect(x: 60, y: 660, width: 1_080, height: 100))
            "TAILOR FIXTURE".draw(
                at: CGPoint(x: 80, y: 690),
                withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 42, weight: .bold), .foregroundColor: UIColor.white]
            )
        }
    }

    private func rasterize(pdfPage: CGPDFPage, longestSide: CGFloat) -> UIImage {
        let box = pdfPage.getBoxRect(.mediaBox)
        let scale = longestSide / max(box.width, box.height)
        let size = CGSize(width: max(1, floor(box.width * scale)), height: max(1, floor(box.height * scale)))
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            context.cgContext.drawPDFPage(pdfPage)
            context.cgContext.restoreGState()
        }
    }

    private func sampledColorCount(in image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let width = min(cgImage.width, 180)
        let height = min(cgImage.height, 180)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var colors = Set<UInt32>()
        for index in stride(from: 0, to: pixels.count, by: 4 * 7) {
            colors.insert(UInt32(pixels[index]) << 24 | UInt32(pixels[index + 1]) << 16 | UInt32(pixels[index + 2]) << 8 | UInt32(pixels[index + 3]))
        }
        return colors.count
    }

    private func makeProfile(lifecycle: ProfileLifecycle) -> PetProfile {
        PetProfile(name: "Milo", species: .dog, arrivalYear: 2017, departureYear: 2024, lifecycle: lifecycle, referenceAssetIdentifiers: ["a", "b", "c"])
    }

    private func makeContainer(repository: any ArchiveRepository, scanner: any PetScanServicing = SuccessfulScanner(), purchase: any PurchaseServicing = EntitledPurchaseService()) -> AppContainer {
        AppContainer(repository: repository, scanner: scanner, purchase: purchase, pdfExporter: SuccessfulExporter())
    }

    /// F-P02-TEXT: deterministic local text-only fixture. It includes each
    /// supported page role plus the Unicode/line-break data used by B1 and does
    /// not request a personal Photos asset.
    private func p02TextFixtureBook(style: AlbumStyle, paper: PDFPageSize) -> MemoryBookDocument {
        let profile = PetProfile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!, name: "点点", species: .dog, arrivalYear: 2017, departureYear: 2024, lifecycle: .ready, albumStyle: style)
        let rtlMixedLineBreak = "مرحبا، هذه أيام 点点 👨‍👩‍👧‍👦\ne\u{301} محفوظة كما كتبتها"
        func text(_ value: String, _ field: MemoryBookTextField?, _ frame: CGRect, _ z: Int = 10, _ style: MemoryBookTextStyle = .standard) -> MemoryBookElement {
            MemoryBookElement(kind: .text, text: value, normalizedFrame: frame, zIndex: z, textStyle: style, textField: field)
        }
        let pages: [MemoryBookPage] = [
            .init(kind: .cover, title: "点点", subtitle: "A life in moments", layout: .single, pageNumber: 1, elements: [text("点点", .coverPetName, CGRect(x: 0.08, y: 0.08, width: 0.76, height: 0.10), 10, .large), text("A life in moments", .coverSubtitle, CGRect(x: 0.08, y: 0.19, width: 0.76, height: 0.06), 9), text("2017–2024", .coverYearRange, CGRect(x: 0.08, y: 0.26, width: 0.40, height: 0.05), 9)]),
            .init(kind: .dedication, title: "For 点点", layout: .note, pageNumber: 2, elements: [text(String(repeating: "e\u{301}", count: 240), .dedicationMessage, CGRect(x: 0.10, y: 0.25, width: 0.72, height: 0.32), 20)]),
            .init(kind: .contents, title: "Contents", subtitle: "2017 · 2024", layout: .note, pageNumber: 3, elements: [text("Contents", nil, CGRect(x: 0.08, y: 0.08, width: 0.76, height: 0.10), 10), text("2017 · 2024", nil, CGRect(x: 0.08, y: 0.19, width: 0.76, height: 0.06), 9)]),
            .init(kind: .chapterOpener, title: "Days together", subtitle: "2019–2021", layout: .single, pageNumber: 4, elements: [text("Days together", .chapterTitle, CGRect(x: 0.08, y: 0.08, width: 0.76, height: 0.10), 10, .large), text("2019–2021", .chapterDateRange, CGRect(x: 0.08, y: 0.19, width: 0.76, height: 0.05), 9), text(rtlMixedLineBreak, .chapterNote, CGRect(x: 0.08, y: 0.67, width: 0.76, height: 0.12), 20)]),
            .init(kind: .photoSelection, title: "Summer days", subtitle: "", layout: .single, pageNumber: 5, elements: [text("Summer days", .photoTitle, CGRect(x: 0.08, y: 0.08, width: 0.76, height: 0.10), 10, .large), text(String(repeating: "👨‍👩‍👧‍👦", count: 120), .photoCaption, CGRect(x: 0.10, y: 0.67, width: 0.72, height: 0.18), 20, .standard)]),
            .init(kind: .milestone, title: "2017", subtitle: "A quiet marker", layout: .single, pageNumber: 6, elements: [text("2017", .milestoneDate, CGRect(x: 0.08, y: 0.08, width: 0.76, height: 0.10), 10), text("A quiet marker", .milestoneNote, CGRect(x: 0.08, y: 0.19, width: 0.76, height: 0.08), 9)]),
            .init(kind: .closing, title: "Kept with care.", layout: .note, pageNumber: 7, elements: [text("Kept with care.", .closingMessage, CGRect(x: 0.10, y: 0.37, width: 0.72, height: 0.13), 20, .large)])
        ]
        return MemoryBookDocument(profile: profile, photos: [], chapters: [], pages: pages, style: style, pageSize: paper)
    }

    /// F-RP-01: deterministic, PhotoKit-free source for visual QA.  It is a
    /// real seven-page visual document rather than seven copies of one generic
    /// image page: each page kind exercises the typography, empty space and
    /// image geometry promised by the editor PRD.  The same document feeds
    /// editor/reader/PDF; no production selection or layout code is changed.
    private func renderPlanFixtureBook(style: AlbumStyle, paper: PDFPageSize) -> MemoryBookDocument {
        return MemoryBookVisualQAFixture.make(style: style, paper: paper)
        let profile = PetProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            name: "Milo",
            species: .dog,
            arrivalYear: 2017,
            departureYear: 2024,
            lifecycle: .ready,
            albumStyle: style
        )
        let photos = (1...4).map { index in
            ArchivePhoto(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 200 + index))!,
                assetLocalIdentifier: "fixture-photo-\(index)",
                decision: .selected,
                confidence: 1,
                createdAt: Date(timeIntervalSince1970: 1_704_067_200 + TimeInterval(index * 86_400)),
                pixelSize: index.isMultiple(of: 2) ? CGSize(width: 900, height: 1_500) : CGSize(width: 1_600, height: 1_000)
            )
        }
        func text(_ id: Int, _ value: String, _ frame: CGRect, _ z: Int = 10, _ textStyle: MemoryBookTextStyle = .standard, _ field: MemoryBookTextField? = nil) -> MemoryBookElement {
            MemoryBookElement(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 300 + id))!, kind: .text, text: value, normalizedFrame: frame, zIndex: z, textStyle: textStyle, textField: field)
        }
        func image(_ id: Int, _ photo: ArchivePhoto, _ frame: CGRect, scale: CGFloat = 1, offset: CGSize = .zero, rotation: Double = 0, z: Int = 2) -> MemoryBookElement {
            MemoryBookElement(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 400 + id))!, kind: .image, assetID: photo.id, normalizedFrame: frame, cropScale: scale, cropOffset: offset, rotationDegrees: rotation, zIndex: z)
        }

        let pages: [MemoryBookPage] = [
            .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!, kind: .cover, title: "Milo", subtitle: "A life in moments", photoIDs: [photos[0].id], layout: .single, pageNumber: 1, elements: [
                image(1, photos[0], CGRect(x: 0.08, y: 0.31, width: 0.84, height: 0.55), scale: 1.12, offset: CGSize(width: -0.04, height: 0.02)),
                text(1, "Milo", CGRect(x: 0.08, y: 0.09, width: 0.72, height: 0.10), 12, .large, .coverPetName),
                text(2, "A life in moments", CGRect(x: 0.08, y: 0.20, width: 0.76, height: 0.06), 11, .standard, .coverSubtitle),
                text(3, "2017–2024", CGRect(x: 0.08, y: 0.87, width: 0.32, height: 0.05), 11, .standard, .coverYearRange)
            ]),
            .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!, kind: .dedication, title: "For Milo", layout: .note, pageNumber: 2, elements: [
                text(4, "For Milo", CGRect(x: 0.12, y: 0.20, width: 0.68, height: 0.10), 12, .large, .dedicationMessage),
                text(5, "For every ordinary morning,\nevery walk, and every place\nthat still feels like home.", CGRect(x: 0.12, y: 0.37, width: 0.68, height: 0.22), 11)
            ]),
            .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000503")!, kind: .contents, title: "Contents", layout: .note, pageNumber: 3, elements: [
                text(6, "Contents", CGRect(x: 0.10, y: 0.10, width: 0.70, height: 0.09), 12, .large),
                text(7, "Early days                                      4\nDays together                                5\nKept close                                      7", CGRect(x: 0.12, y: 0.30, width: 0.70, height: 0.34), 11)
            ]),
            .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000504")!, kind: .chapterOpener, title: "Days together", subtitle: "2019–2021", photoIDs: [photos[1].id], layout: .single, pageNumber: 4, elements: [
                image(4, photos[1], CGRect(x: 0.56, y: 0.16, width: 0.28, height: 0.58), scale: 1.18, offset: CGSize(width: 0.05, height: -0.04)),
                text(8, "Days together", CGRect(x: 0.09, y: 0.18, width: 0.42, height: 0.15), 12, .large, .chapterTitle),
                text(9, "2019–2021", CGRect(x: 0.09, y: 0.35, width: 0.35, height: 0.05), 11, .standard, .chapterDateRange),
                text(10, "The photos you chose,\nkept in their own order.", CGRect(x: 0.09, y: 0.58, width: 0.40, height: 0.20), 11, .standard, .chapterNote)
            ]),
            .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000505")!, kind: .photoSelection, title: "Small adventures", photoIDs: photos.map(\.id), layout: .grid2x2, pageNumber: 5, elements: [
                text(11, "Small adventures", CGRect(x: 0.09, y: 0.08, width: 0.70, height: 0.10), 12, .large, .photoTitle),
                image(5, photos[0], CGRect(x: 0.10, y: 0.24, width: 0.37, height: 0.28), scale: 1.08, offset: CGSize(width: -0.04, height: 0.02), rotation: -3, z: 2),
                image(6, photos[1], CGRect(x: 0.49, y: 0.23, width: 0.31, height: 0.34), scale: 1.20, offset: CGSize(width: 0.06, height: -0.03), rotation: 2, z: 3),
                image(7, photos[2], CGRect(x: 0.16, y: 0.56, width: 0.32, height: 0.25), scale: 1.15, offset: CGSize(width: 0.02, height: 0.04), rotation: 4, z: 4),
                image(8, photos[3], CGRect(x: 0.49, y: 0.58, width: 0.34, height: 0.23), scale: 1.05, offset: CGSize(width: -0.03, height: 0), rotation: -2, z: 5),
                text(12, "A few of the days we kept.", CGRect(x: 0.11, y: 0.87, width: 0.70, height: 0.05), 11, .standard, .photoCaption)
            ]),
            .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000506")!, kind: .milestone, title: "2017", photoIDs: [photos[2].id], layout: .single, pageNumber: 6, elements: [
                image(9, photos[2], CGRect(x: 0.13, y: 0.27, width: 0.66, height: 0.40), scale: 1.10, offset: CGSize(width: 0, height: -0.03)),
                text(13, "2017", CGRect(x: 0.13, y: 0.10, width: 0.40, height: 0.10), 12, .large, .milestoneDate),
                text(14, "The first year we saved together.", CGRect(x: 0.13, y: 0.75, width: 0.68, height: 0.14), 11, .standard, .milestoneNote)
            ]),
            .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000507")!, kind: .closing, title: "Kept with care.", layout: .note, pageNumber: 7, elements: [
                text(15, "Kept with care.", CGRect(x: 0.14, y: 0.36, width: 0.64, height: 0.12), 12, .large, .closingMessage),
                text(16, "Tailor never changes your original photos.", CGRect(x: 0.14, y: 0.52, width: 0.70, height: 0.14), 11)
            ])
        ]
        return MemoryBookDocument(profile: profile, photos: photos, chapters: [], pages: pages, style: style, pageSize: paper)
    }
}

private final class DeterministicMemoryBookAssetProvider: MemoryBookAssetImageProviding, @unchecked Sendable {
    private let images: [String: UIImage]

    init(images: [String: UIImage]) {
        self.images = images
    }

    func isAvailable(identifier: String) -> Bool {
        images[identifier] != nil
    }

    func image(identifier: String, targetSize: CGSize) -> UIImage? {
        images[identifier]
    }
}

private struct PDFVisualEvidenceMetrics: Codable {
    let style: String
    let paper: String
    let pageCount: Int
    let pdfBytes: Int
    let pages: [PDFVisualEvidencePageMetric]
    let evidenceScope: String
}

private struct PDFVisualEvidencePageMetric: Codable {
    let pageNumber: Int
    let pageKind: String
    let widthPoints: CGFloat
    let heightPoints: CGFloat
    let pngBytes: Int
    let sampledColorCount: Int
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

private struct PendingPurchaseService: PurchaseServicing {
    func purchaseUnlock() async throws -> PurchaseState { .pending }
    func restorePurchases() async throws -> PurchaseState { .idle }
    func isEntitled() async -> Bool { false }
}

private struct CancelledPurchaseService: PurchaseServicing {
    func purchaseUnlock() async throws -> PurchaseState { .cancelled }
    func restorePurchases() async throws -> PurchaseState { .idle }
    func isEntitled() async -> Bool { false }
}
private struct SuccessfulExporter: PDFExporting { func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL { URL(fileURLWithPath: "/tmp/archive.pdf") } }
private struct FailingExporter: PDFExporting { func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL { throw TestServiceError.unavailable } }
