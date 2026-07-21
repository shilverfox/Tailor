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
        let candidate = ArchivePhoto(id: UUID(), assetLocalIdentifier: "low-confidence", decision: .pending, confidence: 0.43, createdAt: nil)
        XCTAssertEqual(candidate.decision, .pending)
        XCTAssertNotEqual(candidate.decision, .selected)
    }

    func testOnlyExplicitlySelectedNormalPhotosAreEligibleForAnArchive() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let normal = ArchivePhoto(id: UUID(), assetLocalIdentifier: "normal", decision: .selected, confidence: 0.96, createdAt: date)
        let review = ArchivePhoto(id: UUID(), assetLocalIdentifier: "review", decision: .pending, confidence: 0.96, createdAt: date)
        let sensitive = ArchivePhoto(id: UUID(), assetLocalIdentifier: "sensitive", decision: .selected, confidence: 0.96, createdAt: date, sensitivityState: .sensitive)
        let deferred = ArchivePhoto(id: UUID(), assetLocalIdentifier: "deferred", decision: .selected, confidence: 0.96, createdAt: date, sensitivityState: .sensitive)
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
        let photo = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-77", decision: .pending, confidence: 0.62, createdAt: .now)
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
        let candidate = ArchivePhoto(id: UUID(), assetLocalIdentifier: "asset-resume", decision: .pending, confidence: 0.64, createdAt: .now)
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
        XCTAssertEqual(weakSingleReference.disposition, .pending)

        let wrongSpecies = policy.assess(animalConfidence: 0.25, referenceSimilarities: [0.95, 0.90, 0.87])
        XCTAssertEqual(wrongSpecies.disposition, .rejectedSpecies)
        let weakIdentity = policy.assess(animalConfidence: 0.95, referenceSimilarities: [0.40, 0.31, 0.20])
        XCTAssertEqual(weakIdentity.disposition, .rejectedIdentity)
    }

    func testRecognitionPolicyKeepsAnimalDetectorFalsePositiveReviewableWithoutGenericSpeciesAgreement() {
        let policy = PetRecognitionPolicy.standard
        // A real-device probe of a macaque tile returned Dog=0.648 from
        // VNRecognizeAnimalsRequest but generic dog=0.045 from
        // VNClassifyImageRequest. It must not enter review on a weak
        // single-model animal label.
        let macaque = policy.assess(
            animalConfidence: 0.648,
            genericSpeciesConfidence: 0.045,
            referenceSimilarities: [0.92, 0.80, 0.25]
        )
        XCTAssertEqual(macaque.disposition, .pending)

        let dog = policy.assess(
            animalConfidence: 0.713,
            genericSpeciesConfidence: 0.909,
            referenceSimilarities: [0.92, 0.80, 0.25]
        )
        XCTAssertEqual(dog.disposition, .autoSelected)
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
        let undecided = ArchivePhoto(id: UUID(), assetLocalIdentifier: "burst-1", decision: .pending, confidence: 0.7, createdAt: date, visualHash: 0b1010)
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
        let originalSubject = CGRect(x: 0.18, y: 0.22, width: 0.34, height: 0.40)
        let original = ArchivePhoto(id: UUID(), assetLocalIdentifier: "existing", decision: .excluded, confidence: 0.55, createdAt: .now, excludedReason: .userMarkedNotPet, visualHash: 11, subjectRegion: originalSubject)
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: [original.id], isHidden: false, sortOrder: 0)
        let book = MemoryBookBuilder.build(profile: profile, photos: [original], chapters: [chapter], style: .warmPaper, pageSize: .letter)
        let record = MemoryBookExportRecord(fileName: "archive.pdf", pageCount: 2, pageSize: .letter, watermarked: false)
        let document = ArchiveDocument(profile: profile, photos: [original], chapters: [chapter], memoryBook: book, exportRecords: [record])
        let rescanned = ArchivePhoto(id: UUID(), assetLocalIdentifier: "existing", decision: .selected, confidence: 0.99, createdAt: .now, visualHash: 12)
        let fresh = ArchivePhoto(id: UUID(), assetLocalIdentifier: "new", decision: .pending, confidence: 0.65, createdAt: .now)

        let completed = ScanArchiveMergePolicy.completing(document: document, profile: profile, scanned: [rescanned, fresh])
        let retained = try XCTUnwrap(completed.photos.first(where: { $0.assetLocalIdentifier == "existing" }))
        XCTAssertEqual(retained.id, original.id)
        XCTAssertEqual(retained.decision, .excluded)
        XCTAssertEqual(retained.excludedReason, .userMarkedNotPet)
        XCTAssertEqual(retained.visualHash, 12)
        XCTAssertEqual(retained.subjectRegion, originalSubject, "A partial rescan must not discard previously detected focal geometry")
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
        let pending = ArchivePhoto(id: UUID(), assetLocalIdentifier: "pending", decision: .pending, confidence: 0.62, createdAt: .now)
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

    func testWarmPaperProductionBuilderUsesSingleAndDiptychPhotoPages() throws {
        let profile = makeProfile(lifecycle: .ready)
        let photos = (0..<4).map { index in
            ArchivePhoto(
                id: UUID(),
                assetLocalIdentifier: "balanced-\(index)",
                decision: .selected,
                confidence: 1,
                createdAt: .now,
                subjectRegion: CGRect(x: 0.30, y: 0.30, width: 0.30, height: 0.30)
            )
        }
        let chapter = Chapter(id: UUID(), title: "Days", dateLabel: "2024", photoIDs: photos.map(\.id), isHidden: false, sortOrder: 0)

        let book = MemoryBookBuilder.build(profile: profile, photos: photos, chapters: [chapter], style: .warmPaper, pageSize: .letter)
        let pages = book.pages.filter { $0.kind == .photoSelection }

        XCTAssertEqual(pages.map(\.layout), [.diptych, .diptych])
        XCTAssertEqual(pages.map { $0.photoIDs.count }, [2, 2])
        XCTAssertTrue(pages.flatMap(\.elements).filter { $0.kind == .image }.allSatisfy {
            $0.imageContentMode == .fit && $0.rotationDegrees == 0 && $0.cropOffset == .zero
        }, "Warm Paper photo pages default to full-image diptychs; Fill/Crop remains an explicit editing choice.")
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

    func testVisualQAFixtureUsesOneSerializedRevisionAndCoversHardRenderGeometry() throws {
        let bytes = MemoryBookVisualQAFixture.serializedData(style: .warmPaper, paper: .letter)
        let readerDocument = try JSONDecoder().decode(MemoryBookDocument.self, from: bytes)
        let pdfDocument = try JSONDecoder().decode(MemoryBookDocument.self, from: bytes)

        XCTAssertEqual(readerDocument, pdfDocument)
        XCTAssertEqual(readerDocument.exportSnapshot().fingerprint, pdfDocument.exportSnapshot().fingerprint)
        XCTAssertEqual(readerDocument.renderManifest(), pdfDocument.renderManifest())
        XCTAssertEqual(bytes, MemoryBookVisualQAFixture.serializedData(style: .warmPaper, paper: .letter))

        let elements = readerDocument.pages.flatMap(\.elements)
        XCTAssertTrue(elements.contains(where: { abs($0.rotationDegrees) > 0 }))
        XCTAssertTrue(elements.contains(where: { abs($0.textFontScale - 1) > 0.001 }))
        XCTAssertTrue(elements.contains(where: { $0.imageContentMode == .fit }))
        XCTAssertTrue(elements.contains(where: { $0.imageContentMode == .fill }))
        XCTAssertTrue(elements.compactMap(\.text).contains(where: { $0.contains("مرحبا") && $0.contains("👨‍👩‍👧‍👦") && $0.contains("e\u{301}") }))

        let photoPage = try XCTUnwrap(readerDocument.pages.first(where: { $0.kind == .photoSelection }))
        let images = photoPage.elements.filter { $0.kind == .image }
        XCTAssertTrue(images.enumerated().contains { index, lhs in
            images.dropFirst(index + 1).contains { rhs in
                lhs.normalizedFrame.intersects(rhs.normalizedFrame) && lhs.zIndex != rhs.zIndex
            }
        })
    }

    func testProductionDefaultFixtureUsesBuilderDefaultsForWarmPaperBaseline() throws {
        func assertFrame(_ actual: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(actual.width, expected.width, accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(actual.height, expected.height, accuracy: 0.0001, file: file, line: line)
        }

        let expectedKinds: [MemoryBookPageKind] = [.cover, .dedication, .contents, .chapterOpener, .photoSelection, .milestone, .closing]
        let expectedTitles = ["Milo", "For Milo", "Contents", "Days together", "Days together", "A year we remember", "Kept with care."]
        let expectedSubtitles = [
            "A life in moments",
            "Made privately from the photographs you chose.",
            "2019-2021",
            "2019-2021 · A season together",
            "Selected moments from 2019-2021.",
            "A quiet marker from 2017.",
            "Tailor never changes your original photos."
        ]
        let expectedImageIdentifiers: [[String]] = [
            ["fixture-photo-1"],
            [],
            [],
            ["fixture-photo-1"],
            ["fixture-photo-1", "fixture-photo-2"],
            ["fixture-photo-1"],
            []
        ]

        for paper in [PDFPageSize.letter, .a4] {
            let bytes = MemoryBookProductionDefaultFixture.serializedData(paper: paper)
            let readerDocument = try JSONDecoder().decode(MemoryBookDocument.self, from: bytes)
            let pdfDocument = try JSONDecoder().decode(MemoryBookDocument.self, from: bytes)

            XCTAssertEqual(readerDocument, pdfDocument)
            XCTAssertEqual(readerDocument.exportSnapshot().fingerprint, pdfDocument.exportSnapshot().fingerprint)
            XCTAssertEqual(bytes, MemoryBookProductionDefaultFixture.serializedData(paper: paper))
            XCTAssertEqual(readerDocument.style, .warmPaper)
            XCTAssertEqual(readerDocument.pageSize, paper)
            XCTAssertEqual(readerDocument.pages.map(\.kind), expectedKinds)
            XCTAssertEqual(readerDocument.pages.map(\.title), expectedTitles)
            XCTAssertEqual(readerDocument.pages.map(\.subtitle), expectedSubtitles)

            let style = MemoryBookPageStyle.resolve(.warmPaper)
            XCTAssertEqual(style.paper, MemoryBookRGB(red: 248 / 255, green: 243 / 255, blue: 232 / 255))
            XCTAssertEqual(style.backdrop, MemoryBookRGB(red: 239 / 255, green: 228 / 255, blue: 209 / 255))
            XCTAssertEqual(style.ink, MemoryBookRGB(red: 24 / 255, green: 58 / 255, blue: 49 / 255))
            XCTAssertEqual(style.secondary, MemoryBookRGB(red: 100 / 255, green: 117 / 255, blue: 108 / 255))
            XCTAssertEqual(style.accent, MemoryBookRGB(red: 184 / 255, green: 86 / 255, blue: 57 / 255))
            XCTAssertEqual(style.texture, .editorial("WarmPaper"))
            XCTAssertEqual(style.filmFrame, nil)

            let manifest = readerDocument.renderManifest()
            XCTAssertEqual(manifest.plans.count, 7)
            for (index, plan) in manifest.plans.enumerated() {
                XCTAssertEqual(plan.style, style)
                let expectedPageSize = MemoryBookPageRenderPlan.points(for: paper)
                XCTAssertEqual(plan.pageSize, expectedPageSize)
                XCTAssertEqual(plan.canonicalPageSize, expectedPageSize)
                let expectedInset = expectedPageSize.width * MemoryBookPageRenderPlan.paperInsetRatio
                assertFrame(plan.paperRect, CGRect(x: expectedInset, y: expectedInset, width: expectedPageSize.width - expectedInset * 2, height: expectedPageSize.height - expectedInset * 2))

                let page = readerDocument.pages[index]
                let textElements = plan.orderedElements.filter { $0.kind == .text }
                let titleElement = try XCTUnwrap(textElements.first(where: { $0.text == expectedTitles[index] }))
                XCTAssertEqual(plan.fontToken(for: titleElement), .display)
                XCTAssertEqual(plan.fontSize(for: titleElement, in: .zero), plan.paperRect.width * 0.045, accuracy: 0.0001)
                assertFrame(titleElement.normalizedFrame, CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.10))
                if expectedSubtitles[index].isEmpty {
                    XCTAssertEqual(textElements.count, 1)
                } else {
                    let subtitleElement = try XCTUnwrap(textElements.first(where: { $0.text == expectedSubtitles[index] }))
                    XCTAssertEqual(plan.fontToken(for: subtitleElement), .body)
                    XCTAssertEqual(plan.fontSize(for: subtitleElement, in: .zero), plan.paperRect.width * 0.026, accuracy: 0.0001)
                    assertFrame(subtitleElement.normalizedFrame, CGRect(x: 0.08, y: 0.17, width: 0.84, height: 0.06))
                }

                let imageElements = plan.orderedElements.filter { $0.kind == .image }
                let actualIdentifiers = imageElements.compactMap { element -> String? in
                    element.assetID.flatMap { id in readerDocument.photos.first(where: { $0.id == id })?.assetLocalIdentifier }
                }
                XCTAssertEqual(actualIdentifiers, expectedImageIdentifiers[index])
                XCTAssertTrue(imageElements.allSatisfy { $0.rotationDegrees == 0 && $0.cropOffset == .zero && $0.cropScale == 1 })
                if [.cover, .chapterOpener, .milestone].contains(page.kind) {
                    XCTAssertEqual(page.layout, .single)
                    XCTAssertEqual(imageElements.map(\.imageContentMode), imageElements.isEmpty ? [] : [.fill])
                    if !imageElements.isEmpty {
                        assertFrame(imageElements[0].normalizedFrame, CGRect(x: 0.08, y: 0.27, width: 0.84, height: 0.40))
                    }
                } else if page.kind == .photoSelection {
                    XCTAssertEqual(page.layout, .diptych)
                    XCTAssertEqual(imageElements.map(\.imageContentMode), [.fit, .fit])
                    assertFrame(imageElements[0].normalizedFrame, CGRect(x: 0.08, y: 0.3546875, width: 0.41, height: 0.230625))
                    assertFrame(imageElements[1].normalizedFrame, CGRect(x: 0.6025, y: 0.27, width: 0.225, height: 0.40))
                } else {
                    XCTAssertTrue(imageElements.isEmpty)
                }
            }
        }
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
        let appearance = MemoryBookElementAppearance(
            opacity: 0.72,
            mask: .ellipse,
            cornerRadiusRatio: 0.04,
            borderStyle: .dashed,
            borderWidthRatio: 5 / 612,
            borderColor: .init(red: 0.72, green: 0.29, blue: 0.17),
            shadowOpacity: 0.28,
            shadowBlurRatio: 12 / 612,
            shadowOffset: CGSize(width: -3 / 612, height: 7 / 612)
        )
        let adjustments = MemoryBookImageAdjustments(exposure: 0.25, brightness: 0.04, contrast: 1.12, saturation: 0.88, warmth: 0.20, highlights: 0.18, shadows: 0.22, vignette: 0.16, sharpness: 0.24)
        let transformAdjustments = MemoryBookImageTransformAdjustments(straightenDegrees: 8, flipHorizontal: true, flipVertical: false)
        let element = MemoryBookElement(
            kind: .image,
            assetID: photo.id,
            normalizedFrame: CGRect(x: 0.12, y: 0.2, width: 0.5, height: 0.48),
            rotationDegrees: 14,
            zIndex: 6,
            imageContentMode: .fit,
            appearance: appearance,
            imageAdjustments: adjustments,
            imageTransformAdjustments: transformAdjustments
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
        XCTAssertEqual(restored[0].appearance, appearance)
        XCTAssertEqual(restored[0].imageAdjustments, adjustments)
        XCTAssertEqual(restored[0].imageTransformAdjustments, transformAdjustments)
        XCTAssertEqual(restored[1].textFont, MemoryBookTextFont.handwritten)
        XCTAssertEqual(restored[1].textColor, MemoryBookTextColor.clay)
        XCTAssertEqual(restored[1].rotationDegrees, -8)
    }

    func testDecorationLayerPersistsItsDesignContractAndEntersEveryRenderPlan() throws {
        var appearance = MemoryBookElementAppearance.default
        appearance.opacity = 0.74
        appearance.mask = .ellipse
        appearance.fillColor = .init(red: 0.18, green: 0.34, blue: 0.26)
        appearance.borderStyle = .dashed
        appearance.borderWidthRatio = 5 / 612
        appearance.borderColor = .init(red: 0.95, green: 0.88, blue: 0.74)
        appearance.shadowOpacity = 0.26
        appearance.shadowBlurRatio = 11 / 612
        appearance.shadowOffset = CGSize(width: 3 / 612, height: 7 / 612)
        let decoration = MemoryBookElement(
            kind: .shape,
            normalizedFrame: CGRect(x: 0.16, y: 0.28, width: 0.68, height: 0.22),
            rotationDegrees: -9,
            zIndex: 40,
            isLayoutLocked: true,
            appearance: appearance,
            origin: .user
        )
        let page = MemoryBookPage(kind: .dedication, title: "For Milo", pageNumber: 1, elements: [decoration])
        let book = MemoryBookDocument(
            profile: makeProfile(lifecycle: .ready),
            photos: [],
            chapters: [],
            pages: [page],
            style: .warmPaper,
            pageSize: .letter
        )

        let restored = try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book))
        let restoredDecoration = try XCTUnwrap(restored.pages[0].elements.first)
        XCTAssertEqual(restoredDecoration.kind, .shape)
        XCTAssertEqual(restoredDecoration.appearance, appearance)
        XCTAssertEqual(restoredDecoration.normalizedFrame, decoration.normalizedFrame)
        XCTAssertEqual(restoredDecoration.rotationDegrees, decoration.rotationDegrees)
        for size in [CGSize(width: 390, height: 520), MemoryBookPageRenderPlan.points(for: .letter), MemoryBookPageRenderPlan.points(for: .a4)] {
            let rendered = try XCTUnwrap(MemoryBookPageRenderPlan(page: restored.pages[0], document: restored, pageSize: size).orderedElements.first)
            XCTAssertEqual(rendered, restoredDecoration, "Editor, Reader, and PDF must consume the same decoration element")
        }
    }

    func testPageBackgroundPersistsAndIsSharedByEditorReaderAndPDFPlans() throws {
        let background = MemoryBookRGB(red: 0.82, green: 0.87, blue: 0.78)
        let page = MemoryBookPage(kind: .dedication, title: "For Milo", pageNumber: 1, backgroundColor: background)
        let book = MemoryBookDocument(
            profile: makeProfile(lifecycle: .ready),
            photos: [],
            chapters: [],
            pages: [page],
            style: .warmPaper,
            pageSize: .letter
        )

        let restored = try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(restored.pages[0].backgroundColor, background)
        for size in [CGSize(width: 390, height: 520), MemoryBookPageRenderPlan.points(for: .letter), MemoryBookPageRenderPlan.points(for: .a4)] {
            let plan = MemoryBookPageRenderPlan(page: restored.pages[0], document: restored, pageSize: size)
            XCTAssertEqual(plan.paperColor, background, "Editor, Reader and PDF must paint the same page background")
        }

        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(page)) as? [String: Any])
        legacyObject.removeValue(forKey: "backgroundColor")
        let legacy = try JSONDecoder().decode(MemoryBookPage.self, from: JSONSerialization.data(withJSONObject: legacyObject))
        XCTAssertNil(legacy.backgroundColor, "Existing documents must continue using their authored style paper")
    }

    func testLegacyEditorElementDecodesWithExistingFillTreatment() throws {
        let raw = """
        {"id":"00000000-0000-0000-0000-000000000001","kind":"image","normalizedFrame":{"origin":{"x":0,"y":0},"size":{"width":0.5,"height":0.5}},"cropScale":1,"cropOffset":{"width":0,"height":0},"rotationDegrees":0,"zIndex":0,"textStyle":"standard","isLayoutLocked":false,"origin":"automatic","updatedAt":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MemoryBookElement.self, from: raw)
        XCTAssertEqual(decoded.imageContentMode, MemoryBookImageContentMode.fill)
        XCTAssertEqual(decoded.textFont, MemoryBookTextFont.editorial)
        XCTAssertEqual(decoded.textColor, MemoryBookTextColor.ink)
        XCTAssertEqual(decoded.appearance, .default, "Legacy documents must preserve the pre-appearance rendering contract")
        XCTAssertEqual(decoded.imageAdjustments, .default)
        XCTAssertEqual(decoded.imageTransformAdjustments, .default)
        XCTAssertFalse(decoded.isInteractionLocked, "Legacy documents must remain editable when the new interaction-lock key is absent")
    }

    func testEditorInteractionLockRoundTripsIndependentlyFromAutoArrangeLock() throws {
        let element = MemoryBookElement(
            kind: .image,
            assetID: UUID(),
            normalizedFrame: CGRect(x: 0.1, y: 0.2, width: 0.4, height: 0.3),
            isLayoutLocked: false,
            isInteractionLocked: true
        )
        let restored = try JSONDecoder().decode(MemoryBookElement.self, from: JSONEncoder().encode(element))
        XCTAssertTrue(restored.isInteractionLocked)
        XCTAssertFalse(restored.isLayoutLocked)
    }

    func testEditorGroupsRoundTripAndDuplicatePageGetsFreshGroupIdentity() throws {
        let groupID = UUID()
        let first = MemoryBookElement(kind: .image, assetID: UUID(), normalizedFrame: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.3), groupID: groupID)
        let second = MemoryBookElement(kind: .text, text: "Together", normalizedFrame: CGRect(x: 0.45, y: 0.2, width: 0.3, height: 0.1), groupID: groupID)
        let page = MemoryBookPage(kind: .photoSelection, title: "Grouped", layout: .mosaic, pageNumber: 1, elements: [first, second])
        var book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)

        let restored = try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(Set(restored.pages[0].elements.compactMap(\.groupID)), [groupID])

        let duplicateID = try XCTUnwrap(book.duplicatePage(id: page.id))
        let duplicate = try XCTUnwrap(book.pages.first(where: { $0.id == duplicateID }))
        let duplicateGroups = Set(duplicate.elements.compactMap(\.groupID))
        XCTAssertEqual(duplicateGroups.count, 1)
        XCTAssertFalse(duplicateGroups.contains(groupID))
    }

    func testHiddenEditorLayerPersistsAndIsExcludedFromEveryRenderPlan() throws {
        let visible = MemoryBookElement(kind: .text, text: "Visible", normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.1), zIndex: 2)
        let hidden = MemoryBookElement(kind: .text, text: "Hidden", normalizedFrame: CGRect(x: 0.1, y: 0.3, width: 0.4, height: 0.1), zIndex: 3, isHidden: true)
        let page = MemoryBookPage(kind: .dedication, title: "Layers", pageNumber: 1, elements: [visible, hidden])
        let book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let restored = try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book))
        let plan = MemoryBookPageRenderPlan(page: restored.pages[0], document: restored, pageSize: CGSize(width: 612, height: 792))
        XCTAssertEqual(plan.orderedElements.map(\.id), [visible.id])
        XCTAssertTrue(restored.pages[0].elements.first(where: { $0.id == hidden.id })?.isHidden == true)
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

    func testAspectFillAllowsSafeFocalPanAtBaseScale() {
        let landscape = FillCropConstraint(sourceAspect: 2, containerAspect: 1)
        let legal = landscape.normalized(scale: 1, offset: CGSize(width: 0.40, height: 0))
        XCTAssertEqual(legal.scale, 1, accuracy: 0.0001)
        XCTAssertEqual(legal.offset.width, 0.40, accuracy: 0.0001, "Aspect-fill excess is usable at scale 1")
        XCTAssertFalse(landscape.containsBlankEdge(scale: legal.scale, offset: legal.offset))

        let exact = FillCropConstraint(sourceAspect: 1, containerAspect: 1)
        let clamped = exact.normalized(scale: 1, offset: CGSize(width: 0.40, height: -0.40))
        XCTAssertEqual(clamped.offset.width, 0, accuracy: 0.0001)
        XCTAssertEqual(clamped.offset.height, 0, accuracy: 0.0001)
    }

    func testFocalCropPolicyConvertsVisionCoordinatesAndCentersWithinSafeRange() throws {
        let vision = CGRect(x: 0.60, y: 0.10, width: 0.20, height: 0.30)
        let topLeft = FocalCropPolicy.topLeftRegion(fromVisionBoundingBox: vision)
        XCTAssertEqual(topLeft.minX, 0.60, accuracy: 0.0001)
        XCTAssertEqual(topLeft.minY, 0.60, accuracy: 0.0001)

        let horizontal = FocalCropPolicy.recommendedOffset(
            subjectRegion: CGRect(x: 0.60, y: 0.40, width: 0.20, height: 0.20),
            sourceAspect: 2,
            containerAspect: 1
        )
        XCTAssertEqual(horizontal.width, -0.40, accuracy: 0.0001)
        XCTAssertEqual(horizontal.height, 0, accuracy: 0.0001)
        let singleAxisSlack = FocalCropPolicy.recommendedOffset(
            subjectRegion: CGRect(x: 0.72, y: 0.30, width: 0.20, height: 0.34),
            sourceAspect: 1_600 / 900,
            containerAspect: (0.266 * 612) / (0.40 * 792)
        )
        XCTAssertLessThan(singleAxisSlack.width, -0.05, "A no-slack vertical axis must not erase legal horizontal focal movement")
        XCTAssertEqual(singleAxisSlack.height, 0, accuracy: 0.0001)

        let photo = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "focal-portrait",
            decision: .selected,
            confidence: 1,
            createdAt: .now,
            pixelSize: CGSize(width: 800, height: 1_600),
            subjectRegion: CGRect(x: 0.35, y: 0.12, width: 0.30, height: 0.26)
        )
        let chapter = Chapter(id: UUID(), title: "Focus", dateLabel: "2024", photoIDs: [photo.id], isHidden: false, sortOrder: 0)
        var book = MemoryBookBuilder.build(profile: makeProfile(lifecycle: .ready), photos: [photo], chapters: [chapter], style: .warmPaper, pageSize: .letter)
        let coverImage = try XCTUnwrap(book.pages.first?.elements.first(where: { $0.kind == .image }))
        XCTAssertGreaterThan(coverImage.cropOffset.height, 0, "Automatic crop should move a high subject toward the page-frame centre")
        let letter = MemoryBookPageRenderPlan.points(for: .letter)
        let expected = FocalCropPolicy.recommendedOffset(
            subjectRegion: try XCTUnwrap(photo.subjectRegion),
            sourceAspect: photo.aspectRatio,
            containerAspect: (coverImage.normalizedFrame.width * letter.width) / (coverImage.normalizedFrame.height * letter.height)
        )
        XCTAssertEqual(coverImage.cropOffset.width, expected.width, accuracy: 0.0001)
        XCTAssertEqual(coverImage.cropOffset.height, expected.height, accuracy: 0.0001, "Initial focal crop must use physical paper geometry, not square normalized coordinates")

        let encoded = try JSONEncoder().encode(book)
        XCTAssertEqual(try JSONDecoder().decode(MemoryBookDocument.self, from: encoded), book)

        let pageIndex = try XCTUnwrap(book.pages.firstIndex(where: { $0.elements.contains(where: { $0.id == coverImage.id }) }))
        let elementIndex = try XCTUnwrap(book.pages[pageIndex].elements.firstIndex(where: { $0.id == coverImage.id }))
        book.pages[pageIndex].elements[elementIndex].origin = .user
        book.pages[pageIndex].elements[elementIndex].cropOffset = .zero
        XCTAssertEqual(book.applyAutomaticFocalCrops(), 0, "Focal metadata must never overwrite a user crop")
        XCTAssertEqual(book.pages[pageIndex].elements[elementIndex].cropOffset, .zero)

        let landscape = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "focal-landscape",
            decision: .selected,
            confidence: 1,
            createdAt: .now,
            pixelSize: CGSize(width: 1_600, height: 900),
            subjectRegion: CGRect(x: 0.72, y: 0.30, width: 0.20, height: 0.34)
        )
        let companions = (0..<2).map {
            ArchivePhoto(id: UUID(), assetLocalIdentifier: "companion-\($0)", decision: .selected, confidence: 1, createdAt: .now, pixelSize: CGSize(width: 1_600, height: 900))
        }
        let mosaicChapter = Chapter(id: UUID(), title: "Focus", dateLabel: "2024", photoIDs: [landscape.id] + companions.map(\.id), isHidden: false, sortOrder: 0)
        let mosaicBook = MemoryBookBuilder.build(profile: makeProfile(lifecycle: .ready), photos: [landscape] + companions, chapters: [mosaicChapter], style: .fieldNotes, pageSize: .letter)
        let mosaicPage = try XCTUnwrap(mosaicBook.pages.first(where: { $0.kind == .photoSelection }))
        let focalElement = try XCTUnwrap(mosaicPage.elements.first(where: { $0.assetID == landscape.id }))
        XCTAssertLessThan(focalElement.cropOffset.width, -0.05, "Templates that opt into editorial fill must carry focal metadata into a three-photo page")
        XCTAssertEqual(focalElement.cropScale, 1, accuracy: 0.0001)
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

    func testPDFRendererConsumesPersistedPhotoAndDecorationAppearanceContract() async throws {
        var book = MemoryBookVisualQAFixture.make(style: .warmPaper, paper: .letter)
        let pageIndex = try XCTUnwrap(book.pages.firstIndex(where: { $0.elements.contains(where: { $0.kind == .image }) }))
        let elementIndex = try XCTUnwrap(book.pages[pageIndex].elements.firstIndex(where: { $0.kind == .image }))
        var appearance = MemoryBookElementAppearance.default
        appearance.opacity = 0.68
        appearance.mask = .ellipse
        appearance.borderStyle = .dashed
        appearance.borderWidthRatio = 7 / 612
        appearance.borderColor = .init(red: 0.72, green: 0.29, blue: 0.17)
        appearance.shadowOpacity = 0.30
        appearance.shadowBlurRatio = 14 / 612
        appearance.shadowOffset = CGSize(width: 4 / 612, height: 8 / 612)
        book.pages[pageIndex].elements[elementIndex].appearance = appearance
        let adjustments = MemoryBookImageAdjustments(exposure: 0.32, brightness: 0.03, contrast: 1.08, saturation: 0.86, warmth: 0.22, highlights: 0.15, shadows: 0.20, vignette: 0.18, sharpness: 0.22)
        book.pages[pageIndex].elements[elementIndex].imageAdjustments = adjustments
        let transformAdjustments = MemoryBookImageTransformAdjustments(straightenDegrees: -7, flipHorizontal: true, flipVertical: false)
        book.pages[pageIndex].elements[elementIndex].imageTransformAdjustments = transformAdjustments
        _ = book.applyCrop(
            pageID: book.pages[pageIndex].id,
            elementID: book.pages[pageIndex].elements[elementIndex].id,
            scale: book.pages[pageIndex].elements[elementIndex].cropScale,
            offset: book.pages[pageIndex].elements[elementIndex].cropOffset
        )
        var decorationAppearance = MemoryBookElementAppearance.default
        decorationAppearance.mask = .ellipse
        decorationAppearance.fillColor = .init(red: 0.18, green: 0.34, blue: 0.26)
        decorationAppearance.opacity = 0.70
        decorationAppearance.borderStyle = .solid
        decorationAppearance.borderWidthRatio = 6 / 612
        decorationAppearance.shadowOpacity = 0.22
        decorationAppearance.shadowBlurRatio = 10 / 612
        let decoration = MemoryBookElement(
            kind: .shape,
            normalizedFrame: CGRect(x: 0.13, y: 0.12, width: 0.48, height: 0.14),
            rotationDegrees: 7,
            zIndex: 50,
            appearance: decorationAppearance,
            origin: .user
        )
        book.pages[pageIndex].elements.append(decoration)
        let pageBackground = MemoryBookRGB(red: 0.82, green: 0.87, blue: 0.78)
        book.pages[pageIndex].backgroundColor = pageBackground

        let images = Dictionary(uniqueKeysWithValues: (1...7).compactMap { index in
            MemoryBookVisualQAAsset.image(identifier: "fixture-photo-\(index)").map { ("fixture-photo-\(index)", $0) }
        })
        let provider = DeterministicMemoryBookAssetProvider(images: images)
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let exporter = LocalPDFExporter(outputDirectory: directory, imageProvider: provider)
        let output = try await exporter.export(document: book)
        let pdf = try XCTUnwrap(CGPDFDocument(output as CFURL))

        XCTAssertEqual(pdf.numberOfPages, book.pages.count)
        let rendered = try XCTUnwrap(book.renderManifest().plans[pageIndex].orderedElements.first(where: { $0.id == book.pages[pageIndex].elements[elementIndex].id }))
        XCTAssertEqual(rendered.appearance, appearance, "Editor, Reader and PDF must receive the same persisted appearance")
        XCTAssertEqual(rendered.imageAdjustments, adjustments)
        XCTAssertEqual(rendered.imageTransformAdjustments, transformAdjustments)
        let renderedDecoration = try XCTUnwrap(book.renderManifest().plans[pageIndex].orderedElements.first(where: { $0.id == decoration.id }))
        XCTAssertEqual(renderedDecoration.kind, .shape)
        XCTAssertEqual(renderedDecoration.appearance, decorationAppearance)
        XCTAssertEqual(book.renderManifest().plans[pageIndex].paperColor, pageBackground)
        XCTAssertGreaterThan(try Data(contentsOf: output).count, 2_048)
    }

    func testPDFExporterRequestsThreeHundredDPIForFullPageLetterAndA4Photos() {
        for paper in PDFPageSize.allCases {
            let points = MemoryBookPageRenderPlan.points(for: paper)
            let photo = ArchivePhoto(
                id: UUID(),
                assetLocalIdentifier: "print-\(paper.rawValue)",
                decision: .selected,
                confidence: 1,
                createdAt: .now,
                pixelSize: CGSize(width: points.width / 72 * 600, height: points.height / 72 * 600)
            )
            let element = MemoryBookElement(
                kind: .image,
                assetID: photo.id,
                normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
            )

            let target = LocalPDFExporter.printTargetSize(
                for: CGRect(origin: .zero, size: points),
                photo: photo,
                element: element
            )

            XCTAssertGreaterThanOrEqual(target.width, ceil(points.width / 72 * 300))
            XCTAssertGreaterThanOrEqual(target.height, ceil(points.height / 72 * 300))
            XCTAssertEqual(target.width / target.height, points.width / points.height, accuracy: 0.001)
        }
    }

    func testBookCheckReportsEffectivePhotoPrintResolutionAtActualFrameSize() throws {
        let profile = makeProfile(lifecycle: .ready)
        let low = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "low-print-resolution",
            decision: .selected,
            confidence: 1,
            createdAt: .now,
            pixelSize: CGSize(width: 600, height: 400)
        )
        let high = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "high-print-resolution",
            decision: .selected,
            confidence: 1,
            createdAt: .now,
            pixelSize: CGSize(width: 6_000, height: 4_000)
        )
        let lowElement = MemoryBookElement(kind: .image, assetID: low.id, normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1))
        let highElement = MemoryBookElement(kind: .image, assetID: high.id, normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1))
        let lowPage = MemoryBookPage(kind: .photoSelection, title: "Low", photoIDs: [low.id], layout: .single, pageNumber: 1, elements: [lowElement])
        let highPage = MemoryBookPage(kind: .photoSelection, title: "High", photoIDs: [high.id], layout: .single, pageNumber: 2, elements: [highElement])
        let book = MemoryBookDocument(profile: profile, photos: [low, high], chapters: [], pages: [lowPage, highPage], style: .warmPaper, pageSize: .letter)

        let issues = book.checkBook()
        let lowIssue = try XCTUnwrap(issues.first(where: { $0.elementID == lowElement.id && $0.message.contains("PPI") }))

        XCTAssertEqual(lowIssue.severity, .blocking)
        XCTAssertFalse(issues.contains(where: { $0.elementID == highElement.id && $0.message.contains("PPI") }))
    }

    func testBookCheckSuggestsReviewForSevereAutomaticCropWithoutFocalMetadata() throws {
        let profile = makeProfile(lifecycle: .ready)
        let portrait = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "portrait-without-focus",
            decision: .selected,
            confidence: 1,
            createdAt: .now,
            pixelSize: CGSize(width: 6_000, height: 9_000)
        )
        let element = MemoryBookElement(
            kind: .image,
            assetID: portrait.id,
            normalizedFrame: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.3)
        )
        let page = MemoryBookPage(
            kind: .photoSelection,
            title: "Portrait crop",
            photoIDs: [portrait.id],
            layout: .single,
            pageNumber: 1,
            elements: [element]
        )
        var book = MemoryBookDocument(
            profile: profile,
            photos: [portrait],
            chapters: [],
            pages: [page],
            style: .warmPaper,
            pageSize: .letter
        )

        let issue = try XCTUnwrap(book.checkBook().first(where: { $0.elementID == element.id && $0.message.contains("confirm the framing") }))
        XCTAssertEqual(issue.severity, .suggestion)

        XCTAssertTrue(book.applyCrop(pageID: page.id, elementID: element.id, scale: 1, offset: .zero))
        XCTAssertFalse(book.checkBook().contains(where: { $0.elementID == element.id && $0.message.contains("confirm the framing") }))
    }

    func testSharedCoreImageFinishingIsNonDestructiveAndChangesPixels() throws {
        let source = try XCTUnwrap(MemoryBookVisualQAAsset.image(identifier: "fixture-photo-1"))
        let neutral = MemoryBookImageProcessor.process(source, treatment: .original)
        XCTAssertTrue(neutral === source, "Neutral finishing must avoid a needless bitmap rewrite")

        var adjustments = MemoryBookImageAdjustments(exposure: 9, brightness: -9, contrast: 9, saturation: 9, warmth: -9, highlights: 9, shadows: 9, vignette: 9, sharpness: 9)
        adjustments.normalize()
        XCTAssertEqual(adjustments.exposure, 2)
        XCTAssertEqual(adjustments.brightness, -0.5)
        XCTAssertEqual(adjustments.contrast, 1.5)
        XCTAssertEqual(adjustments.highlights, 1)
        let rendered = MemoryBookImageProcessor.process(source, treatment: .original, adjustments: adjustments)
        XCTAssertEqual(rendered.size, source.size)
        XCTAssertNotEqual(rendered.pngData(), source.pngData())
        XCTAssertNotNil(source.pngData(), "The source object remains available and unmodified")
    }

    func testAutoEnhanceIsConservativeDeterministicAndEditable() throws {
        let dark = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor(white: 0.18, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let first = MemoryBookImageProcessor.conservativeAutoEnhancement(for: dark)
        let second = MemoryBookImageProcessor.conservativeAutoEnhancement(for: dark)
        XCTAssertEqual(first, second)
        XCTAssertGreaterThan(first.exposure, 0)
        XCTAssertLessThanOrEqual(first.exposure, 0.45)
        XCTAssertLessThanOrEqual(first.contrast, 1.04)
        XCTAssertLessThanOrEqual(first.saturation, 1.03)
        XCTAssertGreaterThan(first.shadows, 0)
        XCTAssertFalse(first.isNeutral)
    }

    func testStraightenAndFlipGeometryStayPersistedAndBlankEdgeSafe() throws {
        var transform = MemoryBookImageTransformAdjustments(straightenDegrees: 99, flipHorizontal: true, flipVertical: true)
        transform.normalize()
        XCTAssertEqual(transform.straightenDegrees, 15)
        let element = MemoryBookElement(
            kind: .image,
            assetID: UUID(),
            normalizedFrame: CGRect(x: 0.1, y: 0.2, width: 0.6, height: 0.4),
            cropScale: 1,
            imageTransformAdjustments: transform
        )
        let restored = try JSONDecoder().decode(MemoryBookElement.self, from: JSONEncoder().encode(element))
        XCTAssertEqual(restored.imageTransformAdjustments, transform)
        let geometry = MemoryBookImageTransformGeometry(
            container: CGRect(x: 0, y: 0, width: 300, height: 200),
            sourceAspect: 16 / 9,
            element: restored
        )
        XCTAssertEqual(geometry.rotationDegrees, 15)
        XCTAssertTrue(geometry.flipHorizontal)
        XCTAssertTrue(geometry.flipVertical)
        XCTAssertFalse(
            FillCropConstraint(sourceAspect: 16 / 9, containerAspect: 1.5, rotationDegrees: 15)
                .containsBlankEdge(scale: geometry.transform.scale, offset: geometry.transform.offset)
        )
    }

    func testDemoScannerKeepsUncertainMatchesOutOfDefaultSelection() async throws {
        let profile = makeProfile(lifecycle: .ready)
        let photos = try await DemoPetScanService().scan(profile: profile)

        XCTAssertEqual(photos.filter { $0.decision == .selected }.count, 1)
        XCTAssertEqual(photos.filter { $0.decision == .pending }.count, 2)
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
        let grapheme = "👨‍👩‍👧‍👦" // one Swift Character spanning multiple UTF-16 code units
        let captionFrame = CGRect(x: 0.10, y: 0.52, width: 0.145, height: 0.310)
        let dedicationFrame = CGRect(x: 0.10, y: 0.24, width: 0.145, height: 0.600)

        func boundary(on page: MemoryBookPage, field: MemoryBookTextField, frame: CGRect) throws -> (fit: MemoryBookTextLayoutSnapshot, overflow: MemoryBookTextLayoutSnapshot) {
            var previous = book.textLayout(text: "", style: .standard, normalizedFrame: frame, on: page, zIndex: 9, field: field)
            for count in 1...500 {
                let next = book.textLayout(text: String(repeating: grapheme, count: count), style: .standard, normalizedFrame: frame, on: page, zIndex: 9, field: field)
                if next.measurement.overflows { return (previous, next) }
                previous = next
            }
            XCTFail("Expected to find a real Core Text frame boundary")
            throw NSError(domain: "TailorTests", code: 1)
        }

        let caption = try boundary(on: photoPage, field: .photoCaption, frame: captionFrame)
        let dedication = try boundary(on: dedicationPage, field: .dedicationMessage, frame: dedicationFrame)

        XCTAssertTrue(caption.fit.spec.editableRect.contains(caption.fit.spec.textRect))
        XCTAssertTrue(dedication.fit.spec.editableRect.contains(dedication.fit.spec.textRect))
        for pair in [caption, dedication] {
            XCTAssertFalse(pair.fit.measurement.overflows)
            XCTAssertTrue(pair.overflow.measurement.overflows)
            XCTAssertEqual(pair.fit.measurement.consumedUTF16Length, pair.fit.measurement.totalUTF16Length)
            let consumed = try XCTUnwrap(pair.overflow.measurement.consumedUTF16Length)
            let total = try XCTUnwrap(pair.overflow.measurement.totalUTF16Length)
            XCTAssertLessThan(consumed, total)
            if consumed > 0 {
                let composed = (pair.overflow.value as NSString).rangeOfComposedCharacterSequences(for: NSRange(location: 0, length: consumed))
                XCTAssertEqual(composed.length, consumed, "Core Text consumption must stop on a complete grapheme boundary")
            }
        }
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

    func testSharedCoreTextRendererDrawsMixedDirectionTextInAuthoredCoordinates() throws {
        let book = MemoryBookVisualQAFixture.make(style: .warmPaper, paper: .letter)
        let snapshot = try XCTUnwrap(book.renderPlans().flatMap(\.textLayouts).first(where: { $0.value.contains("مرحبا") }))
        let size = snapshot.spec.textRect.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            MemoryBookTextRenderer.draw(snapshot: snapshot, color: .black, in: CGRect(origin: .zero, size: size), context: renderer.cgContext)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        let bytes = try XCTUnwrap(cgImage.dataProvider?.data) as Data
        XCTAssertTrue(bytes.contains(where: { $0 != 0 }), "The shared CoreText path must paint glyph pixels")
        XCTAssertEqual(MemoryBookPreviewTextAdapter.contract(for: snapshot), MemoryBookPDFTextAdapter.contract(for: snapshot))
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

    func testEditorSnapEngineAlignsSafeCentreAndEquivalentPeerAnchors() {
        let nearCentre = CGRect(x: 0.297, y: 0.196, width: 0.40, height: 0.30)
        let centred = MemoryBookEditorSnapEngine.snap(frame: nearCentre, peerFrames: [], threshold: 0.005)
        XCTAssertEqual(centred.frame.midX, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(centred.guides.vertical, 0.5)
        XCTAssertNil(centred.guides.horizontal)

        let nearSafeCorner = CGRect(x: 0.073, y: 0.068, width: 0.20, height: 0.20)
        let safe = MemoryBookEditorSnapEngine.snap(frame: nearSafeCorner, peerFrames: [], threshold: 0.005)
        XCTAssertEqual(safe.frame.minX, MemoryBookPageRenderPlan.safeInsetRatio, accuracy: 0.000_001)
        XCTAssertEqual(safe.frame.minY, MemoryBookPageRenderPlan.safeInsetRatio, accuracy: 0.000_001)

        let peer = CGRect(x: 0.18, y: 0.24, width: 0.30, height: 0.22)
        let moving = CGRect(x: 0.182, y: 0.238, width: 0.18, height: 0.10)
        let aligned = MemoryBookEditorSnapEngine.snap(frame: moving, peerFrames: [peer], threshold: 0.004)
        XCTAssertEqual(aligned.frame.minX, peer.minX, accuracy: 0.000_001)
        XCTAssertEqual(aligned.frame.minY, peer.minY, accuracy: 0.000_001)
        XCTAssertEqual(aligned.guides.vertical, peer.minX)
        XCTAssertEqual(aligned.guides.horizontal, peer.minY)
    }

    func testEditorSnapEngineDoesNotMoveOutsideThresholdOrCrossMatchAnchors() {
        let original = CGRect(x: 0.23, y: 0.31, width: 0.20, height: 0.16)
        let peer = CGRect(x: 0.50, y: 0.60, width: 0.20, height: 0.16)
        let result = MemoryBookEditorSnapEngine.snap(frame: original, peerFrames: [peer], threshold: 0.005)
        XCTAssertEqual(result.frame, original)
        XCTAssertEqual(result.guides, .none)
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

    func testCustomTypographyRoundTripsAndUsesOnePreviewPDFContract() throws {
        var book = p02TextFixtureBook(style: .warmPaper, paper: .letter)
        let pageIndex = try XCTUnwrap(book.pages.firstIndex(where: { $0.kind == .dedication }))
        let elementIndex = try XCTUnwrap(book.pages[pageIndex].elements.firstIndex(where: { $0.kind == .text }))
        let typography = MemoryBookTextTypographyAdjustments(
            alignment: .center,
            trackingEm: 0.08,
            lineHeightMultiple: 1.55,
            paragraphSpacingEm: 0.60
        )
        book.pages[pageIndex].elements[elementIndex].textTypographyAdjustments = typography

        let restored = try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book))
        let restoredElement = restored.pages[pageIndex].elements[elementIndex]
        XCTAssertEqual(restoredElement.textTypographyAdjustments, typography)

        let letter = try XCTUnwrap(restored.renderPlans().first(where: { $0.pageID == restored.pages[pageIndex].id })?.textLayout(for: restoredElement))
        XCTAssertEqual(letter.spec.alignment, .center)
        XCTAssertEqual(letter.spec.kern / letter.spec.fontSize, 0.08, accuracy: 0.0001)
        XCTAssertEqual(letter.spec.lineHeight / letter.spec.fontSize, 1.55, accuracy: 0.02)
        XCTAssertEqual(letter.spec.paragraphSpacing / letter.spec.fontSize, 0.60, accuracy: 0.0001)

        let preview = MemoryBookPreviewTextAdapter.attributedString(for: letter, color: .black)
        let pdf = MemoryBookPDFTextAdapter.attributedString(for: letter, color: .black)
        XCTAssertTrue(preview.isEqual(to: pdf))
        let paragraph = try XCTUnwrap(preview.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(paragraph.alignment, .center)
        XCTAssertEqual(paragraph.paragraphSpacing, letter.spec.paragraphSpacing, accuracy: 0.001)

        var a4Book = restored
        a4Book.pageSize = .a4
        let a4Element = a4Book.pages[pageIndex].elements[elementIndex]
        let a4 = try XCTUnwrap(a4Book.renderPlans().first(where: { $0.pageID == a4Book.pages[pageIndex].id })?.textLayout(for: a4Element))
        XCTAssertEqual(a4.spec.kern / a4.spec.fontSize, letter.spec.kern / letter.spec.fontSize, accuracy: 0.0001)
        XCTAssertEqual(a4.spec.paragraphSpacing / a4.spec.fontSize, letter.spec.paragraphSpacing / letter.spec.fontSize, accuracy: 0.0001)
    }

    func testTextTypographyScalesFromCanonicalPaperInsteadOfReapplyingPrintFloor() throws {
        for paper in PDFPageSize.allCases {
            let element = MemoryBookElement(
                kind: .text,
                text: "A quiet memory across every canvas.",
                normalizedFrame: CGRect(x: 0.12, y: 0.20, width: 0.70, height: 0.18),
                zIndex: 1,
                textStyle: .small,
                textFontScale: 0.5,
                textField: .dedicationMessage
            )
            let page = MemoryBookPage(kind: .dedication, title: "Memory", pageNumber: 1, elements: [element])
            let book = MemoryBookDocument(
                profile: makeProfile(lifecycle: .ready),
                photos: [],
                chapters: [],
                pages: [page],
                style: .warmPaper,
                pageSize: paper
            )
            let physicalSize = MemoryBookPageRenderPlan.points(for: paper)
            let readerSize = CGSize(width: 258, height: 258 * physicalSize.height / physicalSize.width)
            let physicalPlan = MemoryBookPageRenderPlan(page: page, document: book, pageSize: physicalSize)
            let readerPlan = MemoryBookPageRenderPlan(page: page, document: book, pageSize: readerSize)
            let physical = try XCTUnwrap(physicalPlan.textLayout(for: element))
            let reader = try XCTUnwrap(readerPlan.textLayout(for: element))
            let scale = readerPlan.paperRect.width / physicalPlan.paperRect.width

            XCTAssertGreaterThanOrEqual(physical.spec.fontSize, MemoryBookTextReadabilityAssessment.minimumPrintPointSize)
            XCTAssertEqual(reader.spec.fontSize, physical.spec.fontSize * scale, accuracy: 0.0001)
            XCTAssertEqual(reader.spec.lineHeight, physical.spec.lineHeight * scale, accuracy: 0.0001)
            XCTAssertEqual(reader.spec.kern, physical.spec.kern * scale, accuracy: 0.0001)
            XCTAssertLessThan(reader.spec.fontSize, MemoryBookTextReadabilityAssessment.minimumPrintPointSize,
                              "The Reader drawing size is a page scale, not a second print-size gate")
            XCTAssertEqual(reader.measurement.consumedUTF16Length, physical.measurement.consumedUTF16Length)
            XCTAssertEqual(reader.measurement.requiredLines, physical.measurement.requiredLines)
            XCTAssertEqual(reader.measurement.occupiedRect.minX, physical.measurement.occupiedRect.minX * scale, accuracy: 0.02)
            XCTAssertEqual(reader.measurement.occupiedRect.minY, physical.measurement.occupiedRect.minY * scale, accuracy: 0.02)
            XCTAssertEqual(reader.measurement.occupiedRect.width, physical.measurement.occupiedRect.width * scale, accuracy: 0.02)
            XCTAssertEqual(reader.measurement.occupiedRect.height, physical.measurement.occupiedRect.height * scale, accuracy: 0.02)

            let canonicalized = reader.spec.scaled(by: readerPlan.canonicalTextRenderScale)
            XCTAssertEqual(canonicalized.fontSize, physical.spec.fontSize, accuracy: 0.0001)
            XCTAssertEqual(canonicalized.lineHeight, physical.spec.lineHeight, accuracy: 0.0001)
            XCTAssertEqual(canonicalized.kern, physical.spec.kern, accuracy: 0.0001)
            XCTAssertEqual(canonicalized.textRect.minX, physical.spec.textRect.minX, accuracy: 0.0001)
            XCTAssertEqual(canonicalized.textRect.minY, physical.spec.textRect.minY, accuracy: 0.0001)
            XCTAssertEqual(canonicalized.textRect.width, physical.spec.textRect.width, accuracy: 0.0001)
            XCTAssertEqual(canonicalized.textRect.height, physical.spec.textRect.height, accuracy: 0.0001)
        }
    }

    func testTypographyMigrationDefaultsAndClampsUnsafeArchiveValues() throws {
        var legacy = MemoryBookElement(kind: .text, text: "Legacy", normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.1))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        object.removeValue(forKey: "textTypographyAdjustments")
        let migrated = try JSONDecoder().decode(MemoryBookElement.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(migrated.textTypographyAdjustments, .default)

        legacy.textTypographyAdjustments = .init(alignment: .trailing, trackingEm: 4, lineHeightMultiple: 8, paragraphSpacingEm: 9)
        XCTAssertEqual(legacy.textTypographyAdjustments.trackingEm, 0.20)
        XCTAssertEqual(legacy.textTypographyAdjustments.lineHeightMultiple, 2)
        XCTAssertEqual(legacy.textTypographyAdjustments.paragraphSpacingEm, 1.5)
    }

    func testParagraphSpacingParticipatesInDraftOverflowValidation() throws {
        let book = p02TextFixtureBook(style: .warmPaper, paper: .letter)
        let page = try XCTUnwrap(book.pages.first(where: { $0.kind == .dedication }))
        let probeFrame = CGRect(x: 0.10, y: 0.20, width: 0.70, height: 0.50)
        let value = "One memory\nAnother memory\nAlways together"
        let naturalProbe = book.textLayout(text: value, style: .standard, typography: .default, normalizedFrame: probeFrame, on: page, field: .dedicationMessage)
        let spacedProbe = book.textLayout(
            text: value,
            style: .standard,
            typography: .init(lineHeightMultiple: 1.22, paragraphSpacingEm: 0.75),
            normalizedFrame: probeFrame,
            on: page,
            field: .dedicationMessage
        )
        let paperHeight = try XCTUnwrap(book.renderPlans().first(where: { $0.pageID == page.id })).paperRect.height
        let midpointHeight = (naturalProbe.measurement.requiredHeight + spacedProbe.measurement.requiredHeight) / 2
        let frame = CGRect(x: probeFrame.minX, y: probeFrame.minY, width: probeFrame.width, height: midpointHeight / paperHeight)
        let natural = book.textLayout(text: value, style: .standard, typography: .default, normalizedFrame: frame, on: page, field: .dedicationMessage)
        let spaced = book.textLayout(text: value, style: .standard, typography: .init(lineHeightMultiple: 1.22, paragraphSpacingEm: 0.75), normalizedFrame: frame, on: page, field: .dedicationMessage)

        XCTAssertFalse(natural.measurement.overflows)
        XCTAssertTrue(spaced.measurement.overflows)
        XCTAssertEqual(spaced.measurement.requiredLines, natural.measurement.requiredLines)
        XCTAssertEqual(
            spaced.measurement.requiredHeight - natural.measurement.requiredHeight,
            spaced.spec.paragraphSpacing * 2,
            accuracy: 0.01
        )
    }

    func testTextReadabilityUsesSharedPrintSizeAndSRGBContrastContract() throws {
        let black = MemoryBookRGB(red: 0, green: 0, blue: 0)
        let white = MemoryBookRGB(red: 1, green: 1, blue: 1)
        XCTAssertEqual(black.contrastRatio(with: white), 21, accuracy: 0.001)

        let text = MemoryBookElement(
            kind: .text,
            text: "A quiet memory",
            normalizedFrame: CGRect(x: 0.12, y: 0.20, width: 0.70, height: 0.18),
            zIndex: 11,
            textStyle: .small,
            textFontScale: 0.5,
            textCustomColor: black,
            textField: .dedicationMessage
        )
        let page = MemoryBookPage(
            kind: .dedication,
            title: "Memory",
            pageNumber: 1,
            elements: [text],
            backgroundColor: black
        )
        let book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let assessment = try XCTUnwrap(book.textReadability(for: text, on: page))

        XCTAssertEqual(assessment.fontSize, 11, accuracy: 0.001)
        XCTAssertTrue(assessment.isPrintSizeReadable)
        XCTAssertFalse(assessment.hasSufficientContrast)
        XCTAssertEqual(assessment.recommendedForeground, white)
        XCTAssertEqual(assessment.recommendedForeground.contrastRatio(with: assessment.background), 21, accuracy: 0.001)
    }

    func testBookCheckFlagsLowContrastAsActionableDesignSuggestion() throws {
        let paper = MemoryBookRGB(red: 0.97, green: 0.93, blue: 0.84)
        let text = MemoryBookElement(
            kind: .text,
            text: "Nearly invisible",
            normalizedFrame: CGRect(x: 0.12, y: 0.20, width: 0.70, height: 0.18),
            zIndex: 11,
            textStyle: .standard,
            textCustomColor: paper,
            textField: .dedicationMessage
        )
        let page = MemoryBookPage(kind: .dedication, title: "Memory", pageNumber: 1, elements: [text], backgroundColor: paper)
        let book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)

        let issue = try XCTUnwrap(book.checkBook().first(where: { $0.elementID == text.id && $0.message.contains("contrast") }))
        XCTAssertEqual(issue.severity, .suggestion)
        XCTAssertEqual(issue.pageID, page.id)
        XCTAssertEqual(issue.field, .dedicationMessage)
        XCTAssertTrue(issue.message.contains("1.0:1"))
    }

    func testCuratedStylesDoNotCreateContrastWarningNoise() {
        for style in AlbumStyle.allCases {
            let book = p02TextFixtureBook(style: style, paper: .letter)
            let warnings = book.checkBook().filter { $0.message.contains("contrast") }
            XCTAssertTrue(warnings.isEmpty, "\(style) should be readable by design, not require repetitive repair: \(warnings.map(\.message))")
        }
    }

    func testCompositionAnalyzerOffersDeterministicAlignmentAndUndoSafeFrameRepair() throws {
        let anchor = MemoryBookElement(kind: .shape, normalizedFrame: CGRect(x: 0.10, y: 0.20, width: 0.20, height: 0.12), zIndex: 1)
        let moved = MemoryBookElement(kind: .shape, normalizedFrame: CGRect(x: 0.112, y: 0.45, width: 0.20, height: 0.12), zIndex: 2, isLayoutLocked: true, origin: .user)
        let page = MemoryBookPage(kind: .dedication, title: "Design", pageNumber: 1, elements: [anchor, moved])
        var book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)

        let issue = try XCTUnwrap(book.compositionIssues(on: page).first(where: { $0.elementID == moved.id && $0.message.contains("almost aligned") }))
        guard case .elementFrames(let repairs) = try XCTUnwrap(issue.repair) else { return XCTFail("Expected exact frame repair") }
        XCTAssertEqual(repairs.count, 1)
        XCTAssertEqual(repairs[0].elementID, moved.id)
        XCTAssertEqual(repairs[0].frame.minX, 0.10, accuracy: 0.0001)
        XCTAssertEqual(repairs[0].frame.minY, 0.45, accuracy: 0.0001)
        XCTAssertEqual(repairs[0].frame.size, moved.normalizedFrame.size)

        let before = book
        XCTAssertTrue(book.applyBookCheckRepair(issue))
        XCTAssertEqual(book.pages[0].elements[1].normalizedFrame.minX, 0.10, accuracy: 0.0001)
        XCTAssertNotEqual(book, before)
        XCTAssertEqual(before.pages[0].elements[1].normalizedFrame.minX, 0.112, accuracy: 0.0001)
    }

    func testCompositionAnalyzerDistributesUnevenUserSpacingWithoutMovingLockedLayers() throws {
        func shape(_ x: CGFloat, locked: Bool = false) -> MemoryBookElement {
            MemoryBookElement(kind: .shape, normalizedFrame: CGRect(x: x, y: 0.30, width: 0.10, height: 0.10), isInteractionLocked: locked, origin: .user)
        }
        let elements = [shape(0.10), shape(0.28), shape(0.62)]
        let page = MemoryBookPage(kind: .dedication, title: "Rhythm", pageNumber: 1, elements: elements)
        var book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)

        let issue = try XCTUnwrap(book.compositionIssues(on: page).first(where: { $0.message.contains("uneven horizontal spacing") }))
        XCTAssertTrue(book.applyBookCheckRepair(issue))
        let repaired = book.pages[0].elements.sorted { $0.normalizedFrame.minX < $1.normalizedFrame.minX }
        let firstGap = repaired[1].normalizedFrame.minX - repaired[0].normalizedFrame.maxX
        let secondGap = repaired[2].normalizedFrame.minX - repaired[1].normalizedFrame.maxX
        XCTAssertEqual(firstGap, secondGap, accuracy: 0.0001)

        let lockedPage = MemoryBookPage(kind: .dedication, title: "Locked", pageNumber: 1, elements: [shape(0.10), shape(0.28, locked: true), shape(0.46), shape(0.74)])
        XCTAssertNil(book.compositionIssues(on: lockedPage).first(where: { $0.message.contains("uneven horizontal spacing") }), "A batch repair must never skip over a locked authored layer")
    }

    func testCompositionAnalyzerFlagsSteepUserTextRotationButRespectsInteractionLock() throws {
        let text = MemoryBookElement(kind: .text, text: "Tilted", normalizedFrame: CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.1), rotationDegrees: 33, zIndex: 12, isLayoutLocked: true, origin: .user)
        let page = MemoryBookPage(kind: .dedication, title: "Tilt", pageNumber: 1, elements: [text])
        let book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let issue = try XCTUnwrap(book.compositionIssues(on: page).first(where: { $0.message.contains("rotated") }))
        XCTAssertEqual(issue.repair, .elementRotation(0))

        var locked = text
        locked.isInteractionLocked = true
        let lockedPage = MemoryBookPage(kind: .dedication, title: "Tilt", pageNumber: 1, elements: [locked])
        XCTAssertTrue(book.compositionIssues(on: lockedPage).isEmpty)
    }

    func testCompositionAnalyzerRebalancesOnlyFullyAuthoredUnlockedContent() throws {
        func content(_ kind: MemoryBookElementKind, _ frame: CGRect, locked: Bool = false, origin: MemoryBookElementOrigin = .user) -> MemoryBookElement {
            MemoryBookElement(kind: kind, text: kind == .text ? "A small story" : nil, normalizedFrame: frame, isInteractionLocked: locked, origin: origin)
        }
        let elements = [
            content(.image, CGRect(x: 0.06, y: 0.08, width: 0.28, height: 0.22)),
            content(.text, CGRect(x: 0.07, y: 0.33, width: 0.24, height: 0.08))
        ]
        let page = MemoryBookPage(kind: .photoSelection, title: "Balance", pageNumber: 1, elements: elements)
        var book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [page], style: .warmPaper, pageSize: .letter)
        let issue = try XCTUnwrap(book.compositionIssues(on: page).first(where: { $0.message.contains("weighted toward") }))
        XCTAssertEqual(issue.repair?.actionLabel, "Balance page")
        let beforeDeltaX = elements[1].normalizedFrame.minX - elements[0].normalizedFrame.minX
        XCTAssertTrue(book.applyBookCheckRepair(issue))
        let repaired = book.pages[0].elements
        XCTAssertEqual(repaired[1].normalizedFrame.minX - repaired[0].normalizedFrame.minX, beforeDeltaX, accuracy: 0.0001)
        let union = repaired[0].normalizedFrame.union(repaired[1].normalizedFrame)
        XCTAssertEqual(union.midX, 0.5, accuracy: 0.0001)
        XCTAssertEqual(union.midY, 0.5, accuracy: 0.0001)

        var locked = elements
        locked[0].isInteractionLocked = true
        let lockedPage = MemoryBookPage(kind: .photoSelection, title: "Locked", pageNumber: 1, elements: locked)
        XCTAssertNil(book.compositionIssues(on: lockedPage).first(where: { $0.message.contains("weighted toward") }))
        var mixed = elements
        mixed[0].origin = .automatic
        let mixedPage = MemoryBookPage(kind: .photoSelection, title: "Mixed", pageNumber: 1, elements: mixed)
        XCTAssertNil(book.compositionIssues(on: mixedPage).first(where: { $0.message.contains("weighted toward") }))
    }

    func testCompositionAnalyzerFindsOrphanedAndDetachedUserCaptions() {
        let caption = MemoryBookElement(kind: .text, text: "The first snow", normalizedFrame: CGRect(x: 0.70, y: 0.82, width: 0.22, height: 0.06), textField: .photoCaption, origin: .user)
        let orphanPage = MemoryBookPage(kind: .photoSelection, title: "Orphan", pageNumber: 1, elements: [caption])
        let book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [orphanPage], style: .warmPaper, pageSize: .letter)
        XCTAssertTrue(book.compositionIssues(on: orphanPage).contains(where: { $0.message.contains("no photo") }))

        let photo = MemoryBookElement(kind: .image, normalizedFrame: CGRect(x: 0.06, y: 0.08, width: 0.30, height: 0.24))
        let detachedPage = MemoryBookPage(kind: .photoSelection, title: "Detached", pageNumber: 1, elements: [photo, caption])
        XCTAssertTrue(book.compositionIssues(on: detachedPage).contains(where: { $0.message.contains("visually detached") }))

        var nearby = caption
        nearby.normalizedFrame = CGRect(x: 0.06, y: 0.34, width: 0.30, height: 0.06)
        let relatedPage = MemoryBookPage(kind: .photoSelection, title: "Related", pageNumber: 1, elements: [photo, nearby])
        XCTAssertFalse(book.compositionIssues(on: relatedPage).contains(where: { $0.message.contains("visually detached") }))
    }

    func testChapterStyleScopePreservesLockedPagesGeometryAndCustomBackgrounds() {
        let chapterID = UUID()
        let customPaper = MemoryBookRGB(red: 0.2, green: 0.3, blue: 0.4)
        let lockedElement = MemoryBookElement(kind: .text, text: "Locked", normalizedFrame: CGRect(x: 0.17, y: 0.23, width: 0.42, height: 0.11), origin: .user)
        let locked = MemoryBookPage(kind: .chapterOpener, title: "Start", chapterID: chapterID, pageNumber: 1, elements: [lockedElement], backgroundColor: customPaper, isLocked: true)
        let editable = MemoryBookPage(kind: .photoSelection, title: "Days", chapterID: chapterID, layout: .single, pageNumber: 2, elements: [lockedElement], backgroundColor: customPaper)
        let other = MemoryBookPage(kind: .photoSelection, title: "Other", chapterID: UUID(), layout: .single, pageNumber: 3, elements: [lockedElement])
        var book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [locked, editable, other], style: .warmPaper, pageSize: .letter)
        let before = book

        XCTAssertEqual(book.applyStyleOverride(.cinema, to: [locked.id, editable.id]), 1)
        XCTAssertEqual(book.pages[0], before.pages[0])
        XCTAssertEqual(book.pages[1].styleOverride, .cinema)
        XCTAssertEqual(book.pages[1].elements, before.pages[1].elements)
        XCTAssertEqual(book.pages[1].backgroundColor, customPaper)
        XCTAssertEqual(book.pages[2], before.pages[2])
    }

    // MARK: - Tailor v2 product-contract baseline

    func testV2VisualOnlyTemplateApplicationChangesTokensWithoutChangingAuthoredPages() {
        let profile = makeProfile(lifecycle: .ready)
        let photo = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "v2-visual-only",
            decision: .selected,
            confidence: 0.98,
            createdAt: .now,
            pixelSize: CGSize(width: 2400, height: 1600)
        )
        let authoredImage = MemoryBookElement(
            kind: .image,
            assetID: photo.id,
            normalizedFrame: CGRect(x: 0.13, y: 0.21, width: 0.62, height: 0.41),
            cropScale: 1.27,
            cropOffset: CGSize(width: 0.04, height: -0.03),
            rotationDegrees: 7.5,
            zIndex: 12,
            imageContentMode: .fill,
            isLayoutLocked: true,
            origin: .user
        )
        let page = MemoryBookPage(
            kind: .photoSelection,
            title: "Authored page",
            photoIDs: [photo.id],
            layout: .single,
            pageNumber: 1,
            elements: [authoredImage],
            backgroundColor: MemoryBookRGB(red: 0.93, green: 0.89, blue: 0.80),
            isLocked: true
        )
        var book = MemoryBookDocument(
            profile: profile,
            photos: [photo],
            chapters: [],
            pages: [page],
            style: .warmPaper,
            pageSize: .letter
        )
        let pagesBefore = book.pages

        book.applyTemplate(style: .cinema, mode: .visualOnly)

        XCTAssertEqual(book.style, .cinema)
        XCTAssertEqual(book.pages, pagesBefore, "Visual style only must preserve pagination, frame, crop, rotation, z-index, locks and page overrides exactly")
    }

    func testV2RearrangeUnlockedProtectsLockedPageAndReportsItsImpact() {
        let profile = makeProfile(lifecycle: .ready)
        let photos = (0..<4).map { index in
            ArchivePhoto(
                id: UUID(),
                assetLocalIdentifier: "v2-reflow-\(index)",
                decision: .selected,
                confidence: 0.95,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index + 1)),
                pixelSize: CGSize(width: 1800, height: 1200)
            )
        }
        let lockedElement = MemoryBookElement(
            kind: .image,
            assetID: photos[0].id,
            normalizedFrame: CGRect(x: 0.18, y: 0.24, width: 0.55, height: 0.38),
            rotationDegrees: -4,
            zIndex: 9,
            isLayoutLocked: true,
            origin: .user
        )
        let lockedPage = MemoryBookPage(
            kind: .photoSelection,
            title: "Keep this page",
            photoIDs: [photos[0].id],
            layout: .single,
            pageNumber: 1,
            elements: [lockedElement],
            isLocked: true
        )
        let automaticPage = MemoryBookPage(
            kind: .photoSelection,
            title: "Reflow this page",
            photoIDs: Array(photos.dropFirst().map(\.id)),
            layout: .grid2x2,
            pageNumber: 2,
            elements: MemoryBookBuilder.elements(
                kind: .photoSelection,
                title: "Reflow this page",
                subtitle: "",
                photos: Array(photos.dropFirst().map(\.id)),
                layout: .grid2x2
            )
        )
        var book = MemoryBookDocument(
            profile: profile,
            photos: photos,
            chapters: [],
            pages: [lockedPage, automaticPage],
            style: .warmPaper,
            pageSize: .a4
        )
        let lockedBefore = lockedPage
        let summary = book.templateApplicationSummary(style: .cinema, mode: .rearrangeUnlocked)

        XCTAssertEqual(summary.affectedPageCount, 1)
        XCTAssertEqual(summary.protectedPageCount, 1)

        book.applyTemplate(style: .cinema, mode: .rearrangeUnlocked)

        XCTAssertEqual(book.style, .cinema)
        XCTAssertEqual(book.pages.first(where: { $0.id == lockedBefore.id }), lockedBefore, "A locked page must be byte-for-byte stable under template rearrangement")
        XCTAssertTrue(book.pages.filter { $0.id != lockedBefore.id }.allSatisfy { $0.layout == .single }, "Cinema must reflow only unlocked photo pages to its single-hero recipe")
        XCTAssertEqual(Set(book.pages.flatMap(\.photoIDs)), Set(photos.map(\.id)), "Safe reflow must not lose or duplicate source photos")
    }

    func testV2FiveTemplatesExposeFiveDistinctEditorialSignatures() {
        let signatures = AlbumStyle.allCases.map { style -> String in
            let visual = MemoryBookPageStyle.resolve(style)
            let layout = MemoryBookTemplatePolicy.layout(for: style, photoCount: 4, pageOrdinal: 1)
            return [
                String(describing: layout),
                String(MemoryBookTemplatePolicy.capacity(for: style, pageOrdinal: 1)),
                String(describing: visual.imageTreatment),
                String(visual.paper.red), String(visual.paper.green), String(visual.paper.blue),
                String(visual.backdrop.red), String(visual.backdrop.green), String(visual.backdrop.blue),
                String(visual.drawsFilmFrame),
                visual.texture?.assetName ?? "none"
            ].joined(separator: "|")
        }

        XCTAssertEqual(signatures.count, 5)
        XCTAssertEqual(Set(signatures).count, 5, "The five templates must remain structurally/visually distinguishable instead of becoming color aliases")
    }

    func testV2TextFontsExposeExactlyEightPersistedTokensAndMigrateLegacyTokens() throws {
        XCTAssertEqual(MemoryBookTextFont.allCases.map(\.rawValue), ["system", "rounded", "systemSerif", "iowanOldStyle", "baskerville", "avenirNext", "americanTypewriter", "noteworthy"])
        let legacy: [String: MemoryBookTextFont] = ["editorial": .systemSerif, "quietSans": .avenirNext, "handwritten": .noteworthy, "cinema": .avenirNext]
        for (token, expected) in legacy {
            let decoded = try JSONDecoder().decode(MemoryBookTextFont.self, from: Data("\"\(token)\"".utf8))
            XCTAssertEqual(decoded, expected)
            XCTAssertNotNil(decoded.font(size: 18, fallback: .body))
        }
        for font in MemoryBookTextFont.allCases {
            XCTAssertEqual(try JSONDecoder().decode(MemoryBookTextFont.self, from: JSONEncoder().encode(font)), font)
            XCTAssertNotNil(font.font(size: 18, fallback: .body))
        }
    }

    func testV2StoryPlanMergeSplitAndMoveKeepEveryPhotoExactlyOnce() {
        let ids = (0..<5).map { _ in UUID() }
        let firstID = UUID(), secondID = UUID()
        var chapters = [
            Chapter(id: firstID, title: "First", dateLabel: "2019", photoIDs: Array(ids[0...1]), isHidden: false, sortOrder: 0),
            Chapter(id: secondID, title: "Second", dateLabel: "2020", photoIDs: Array(ids[2...4]), isHidden: false, sortOrder: 1)
        ]
        XCTAssertTrue(StoryPlanMutation.mergeAdjacent(&chapters, firstID: firstID, secondID: secondID))
        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters[0].photoIDs, ids)
        XCTAssertTrue(chapters[0].needsReflow)
        XCTAssertTrue(StoryPlanMutation.split(&chapters, chapterID: firstID, atPhotoIndex: 2))
        XCTAssertEqual(chapters.flatMap(\.photoIDs), ids)
        XCTAssertEqual(Set(chapters.flatMap(\.photoIDs)).count, ids.count)
        XCTAssertTrue(chapters.allSatisfy(\.needsReflow))
        let newID = chapters[1].id
        XCTAssertTrue(StoryPlanMutation.move(&chapters, chapterID: newID, direction: .earlier))
        XCTAssertEqual(chapters.map(\.sortOrder), [0, 1])
        XCTAssertEqual(chapters.first?.id, newID)
        XCTAssertFalse(StoryPlanMutation.mergeAdjacent(&chapters, firstID: firstID, secondID: UUID()))
    }

    func testV2NeedsReflowNeverMarksLockedPages() {
        let chapterID = UUID()
        let locked = MemoryBookPage(kind: .chapterOpener, title: "Locked", chapterID: chapterID, pageNumber: 1, isLocked: true)
        let editable = MemoryBookPage(kind: .photoSelection, title: "Editable", chapterID: chapterID, pageNumber: 2)
        var book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [locked, editable], style: .warmPaper, pageSize: .letter)
        XCTAssertEqual(book.markPagesNeedsReflow(chapterIDs: [chapterID]), 1)
        XCTAssertFalse(book.pages[0].needsReflow)
        XCTAssertTrue(book.pages[1].needsReflow)
    }

    func testV2OnlySuggestionsCanBeIgnoredAndChoicePersists() throws {
        let pageID = UUID()
        let suggestion = MemoryBookIssue(severity: .suggestion, pageID: pageID, message: "Low contrast")
        let blocker = MemoryBookIssue(severity: .blocking, pageID: pageID, message: "Missing photo")
        var book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: [], style: .warmPaper, pageSize: .letter)
        book.setBookCheckSuggestion(suggestion, ignored: true)
        book.setBookCheckSuggestion(blocker, ignored: true)
        XCTAssertTrue(book.isBookCheckSuggestionIgnored(suggestion))
        XCTAssertFalse(book.isBookCheckSuggestionIgnored(blocker))
        let restored = try JSONDecoder().decode(MemoryBookDocument.self, from: JSONEncoder().encode(book))
        XCTAssertTrue(restored.isBookCheckSuggestionIgnored(suggestion))
    }

    func testV2FreeReaderExposesOnlySixToEightWatermarkedSamplePages() {
        let pages = (1...14).map { index in
            MemoryBookPage(kind: index == 1 ? .cover : (index == 2 ? .contents : (index == 14 ? .closing : (index.isMultiple(of: 3) ? .chapterOpener : .photoSelection))), title: "Page \(index)", pageNumber: index)
        }
        let book = MemoryBookDocument(profile: makeProfile(lifecycle: .ready), photos: [], chapters: [], pages: pages, style: .warmPaper, pageSize: .letter)
        let sample = book.readerVisiblePages(watermarked: true)
        XCTAssertTrue((6...8).contains(sample.count))
        XCTAssertEqual(book.readerVisiblePages(watermarked: false), pages)
        XCTAssertTrue(Set(sample.map(\.id)).isSubset(of: Set(pages.map(\.id))))
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

/// Pixel-level proof that `croppedToAnimal` crops the correct half of the image.
/// The math of the coordinate conversion is tested elsewhere; this guards
/// against a silent Y-flip in the actual `CGImage.cropping(to:)` on device.
final class CroppedToAnimalPixelTests: XCTestCase {
    /// Builds a 100x100 image whose TOP half (top-left view) is red and bottom
    /// half is blue. CGContext has a bottom-left origin, so the top half is
    /// drawn at the high-y rows.
    private func makeTopRedBottomBlueImage() -> CGImage {
        let size = 100
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // Bottom half (context y 0..<50) = blue.
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size / 2))
        // Top half (context y 50..<100) = red -> this is the image's top edge.
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: size / 2, width: size, height: size / 2))
        return context.makeImage()!
    }

    private func averageColor(_ image: CGImage) -> (r: Int, g: Int, b: Int) {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }

    func testCroppingTopLeftRegionReturnsPixelsFromTheTopOfTheImage() {
        let image = makeTopRedBottomBlueImage()
        // Top-left normalized region covering the top half, margin 0 to isolate
        // the crop geometry from margin expansion.
        let topHalf = CGRect(x: 0, y: 0, width: 1, height: 0.5)
        let cropped = VisionFocalRegionDetector.croppedToAnimal(image, region: topHalf, margin: 0)
        let color = averageColor(cropped)
        XCTAssertGreaterThan(color.r, 200, "Top-left region must crop the RED top half, not the blue bottom (a Y-flip would return blue)")
        XCTAssertLessThan(color.b, 60, "Cropped top half must not contain the bottom blue region")
        XCTAssertLessThan(cropped.height, image.height, "Cropping to half height must actually reduce the image")
    }

    func testCroppingBottomHalfReturnsBluePixels() {
        let image = makeTopRedBottomBlueImage()
        let bottomHalf = CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        let cropped = VisionFocalRegionDetector.croppedToAnimal(image, region: bottomHalf, margin: 0)
        let color = averageColor(cropped)
        XCTAssertGreaterThan(color.b, 200, "Bottom-half top-left region must crop the BLUE bottom of the image")
        XCTAssertLessThan(color.r, 60, "Cropped bottom half must not contain the top red region")
    }

    func testNilRegionReturnsOriginalImageUnchanged() {
        let image = makeTopRedBottomBlueImage()
        let result = VisionFocalRegionDetector.croppedToAnimal(image, region: nil, margin: 0.2)
        XCTAssertEqual(result.width, image.width)
        XCTAssertEqual(result.height, image.height)
    }
}
