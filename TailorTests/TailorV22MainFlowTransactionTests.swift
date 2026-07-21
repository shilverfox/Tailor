import XCTest
import SwiftData
@testable import Tailor

/// WP-2 tests for the frozen 03–09 transaction boundary. These tests exercise
/// persisted aggregate state and private-file lifecycle, rather than duplicating
/// `MilestoneRootView`'s transient navigation state.
final class TailorV22MainFlowTransactionTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_735_689_600)

    // MARK: - 03–09 checkpoint transactions and recovery

    func testEachCheckpointTransactionPersistsExactlyOneResumeRoute() async throws {
        let fixtures = makeValidCheckpointFixtures()

        for (stage, expectedRoute, expectedLabel, source) in fixtures {
            let repository = try makeRepository()
            let committed = ArchiveWorkflowTransaction.advancing(source, to: stage, at: fixedDate)

            try await repository.save(document: committed)
            let fetched = try await repository.document(id: committed.id)
            let restored = try XCTUnwrap(fetched)

            XCTAssertEqual(restored.archiveCheckpoint?.stage, stage, "Wrong checkpoint for \(stage.rawValue)")
            XCTAssertEqual(restored.archiveCheckpoint?.resumeRoute, expectedRoute)
            XCTAssertEqual(restored.archiveCheckpoint?.resumeRoute.actionLabel, expectedLabel)
        }
    }

    func testPausedSmartDraftPersistsItsLastCompleteStepCursor() async throws {
        let repository = try makeRepository()
        var archive = makeEligibleArchive()
        archive.archiveCheckpoint = ArchiveCheckpoint(stage: .smartDraft, smartDraftStepCursor: "group-events-complete", updatedAt: fixedDate)

        try await repository.save(document: archive)
        let fetched = try await repository.document(id: archive.id)
        let restored = try XCTUnwrap(fetched)

        XCTAssertEqual(restored.archiveCheckpoint?.resumeRoute, .smartDraft)
        XCTAssertEqual(restored.archiveCheckpoint?.smartDraftStepCursor, "group-events-complete")
        XCTAssertNil(restored.memoryBook)
    }

    func testInvalidCheckpointsFallBackToEarliestRepairableStageWithoutErasingSnapshots() throws {
        let retainedDecision = makePhoto(index: 1, decision: .selected)
        let retainedExport = MemoryBookExportRecord(
            fileName: "retained.pdf",
            exportedAt: fixedDate,
            pageCount: 6,
            pageSize: .letter,
            watermarked: false
        )
        let cases: [(ArchiveCheckpointStage, ArchiveDocument, ArchiveCheckpointStage)] = [
            (.scan, ArchiveDocument(profile: makeProfile(referenceIDs: []), photos: [retainedDecision], exportRecords: [retainedExport]), .references),
            (.review, ArchiveDocument(profile: makeProfile(), photos: [], exportRecords: [retainedExport]), .scan),
            (.storyPlan, makeEligibleArchive(), .smartDraft),
            (.stylePending, archiveWithDraft(state: .generated), .storyPlan),
            (.documentReady, archiveWithDraft(state: .confirmed), .stylePending)
        ]

        for (invalidStage, source, expectedFallback) in cases {
            var encodedSource = source
            encodedSource.archiveCheckpoint = ArchiveCheckpoint(stage: invalidStage, updatedAt: fixedDate)
            let restored = try JSONDecoder().decode(ArchiveDocument.self, from: JSONEncoder().encode(encodedSource))

            XCTAssertEqual(restored.archiveCheckpoint?.stage, expectedFallback, "Wrong fallback from \(invalidStage.rawValue)")
            XCTAssertEqual(restored.photos, source.photos, "Fallback must retain review decisions")
            XCTAssertEqual(restored.exportRecords, source.exportRecords, "Fallback must retain successful exports")
            XCTAssertEqual(restored.memoryBook, source.memoryBook, "Fallback must not rewrite a surviving document snapshot")
        }
    }

    func testValidEarlierCheckpointIsNotSilentlyAdvancedByLaterArtifacts() throws {
        var archive = archiveWithDraft(state: .confirmed)
        archive.archiveCheckpoint = ArchiveCheckpoint(stage: .review, updatedAt: fixedDate)

        let restored = try JSONDecoder().decode(ArchiveDocument.self, from: JSONEncoder().encode(archive))

        XCTAssertEqual(restored.archiveCheckpoint?.stage, .review)
        XCTAssertEqual(restored.archiveCheckpoint?.resumeRoute, .photoReview)
        XCTAssertNotNil(restored.storyPlanDraft, "A deliberate earlier resume point must not destroy later snapshots")
    }

    // MARK: - Denied manual import boundaries and lifecycle

    func testManualImportBoundaryAcceptsThreeAndFiveHundredButRejectsTwoAndFiveHundredOne() {
        XCTAssertEqual(ManualImportPolicy.minimumCount, 3)
        XCTAssertEqual(ManualImportPolicy.maximumCount, 500)
        XCTAssertFalse(ManualImportPolicy.canContinue(count: 2))
        XCTAssertTrue(ManualImportPolicy.canContinue(count: 3))
        XCTAssertTrue(ManualImportPolicy.canContinue(count: 500))
        XCTAssertFalse(ManualImportPolicy.canContinue(count: 501))
        XCTAssertEqual(ManualImportFlowPolicy.resumeRoute(forValidSelectionCount: 2), .references)
        XCTAssertEqual(ManualImportFlowPolicy.resumeRoute(forValidSelectionCount: 3), .photoReview)
        XCTAssertEqual(ManualImportFlowPolicy.resumeRoute(forValidSelectionCount: 500), .photoReview)
        XCTAssertEqual(ManualImportFlowPolicy.resumeRoute(forValidSelectionCount: 501), .references)
    }

    func testFiveHundredOneSelectionKeepsTheFirstFiveHundredAndRejectsOnlyOverflow() {
        let proposed = Array(0...500)
        let accepted = ManualImportPolicy.acceptedPrefix(proposed, existingCount: 0)

        XCTAssertEqual(accepted.count, 500)
        XCTAssertEqual(accepted, Array(0..<500))
        XCTAssertFalse(accepted.contains(500))
    }

    func testManualCandidatesArePendingAndResumeDirectlyAtReviewWithoutScanCheckpoint() throws {
        let archive = makeManualArchive(count: 3)
        let restored = try JSONDecoder().decode(ArchiveDocument.self, from: JSONEncoder().encode(archive))

        XCTAssertEqual(restored.photos.count, 3)
        XCTAssertTrue(restored.photos.allSatisfy { $0.decision == .pending && $0.decisionSource == .manualImport })
        XCTAssertNil(restored.scanCheckpoint, "Denied manual import must not enter the PhotoKit scanner")
        XCTAssertEqual(restored.archiveCheckpoint?.resumeRoute, .photoReview)
    }

    func testManualImportColdStartAndContinueAddingPreservePrivateReferences() async throws {
        let repository = try makeRepository()
        var archive = makeManualArchive(count: 3)
        try await repository.save(document: archive)

        let coldStartFetch = try await repository.document(id: archive.id)
        var coldStarted = try XCTUnwrap(coldStartFetch)
        let additions = makeManualResults(range: 3..<5, profileID: archive.id)
        coldStarted.manualAssets.append(contentsOf: additions.map(\.asset))
        coldStarted.photos.append(contentsOf: additions.map(\.photo))
        coldStarted.archiveCheckpoint = ArchiveCheckpoint(stage: .review, updatedAt: fixedDate)
        try await repository.save(document: coldStarted)

        let resumedFetch = try await repository.document(id: archive.id)
        archive = try XCTUnwrap(resumedFetch)
        XCTAssertEqual(archive.manualAssets.count, 5)
        XCTAssertEqual(archive.photos.count, 5)
        XCTAssertEqual(Set(archive.photos.compactMap(\.manualAssetID)), Set(archive.manualAssets.map(\.id)))
        XCTAssertTrue(archive.photos.allSatisfy { $0.decision == .pending })
        XCTAssertEqual(archive.archiveCheckpoint?.resumeRoute, .photoReview)
    }

    func testFingerprintMappingReplacesOnlyMatchedPhotoAndDeletesOnlyMatchedPrivateCopy() throws {
        let profileID = UUID()
        defer { try? ManualAssetStore.deleteCopies(profileID: profileID) }
        let results = makeManualResults(range: 0..<2, profileID: profileID)
        for (index, result) in results.enumerated() {
            let url = ManualAssetStore.url(for: result.asset.relativePath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("fixture-\(index)".utf8).write(to: url, options: .atomic)
        }
        var archive = ArchiveDocument(
            profile: makeProfile(id: profileID, referenceIDs: []),
            photos: results.map(\.photo),
            archiveCheckpoint: ArchiveCheckpoint(stage: .review, updatedAt: fixedDate),
            manualAssets: results.map(\.asset),
            updatedAt: fixedDate
        )
        let retainedDecision = archive.photos[0].decision

        ManualAssetStore.applyingMappings([results[0].asset.contentFingerprint: "PHAsset-mapped"], to: &archive)

        XCTAssertEqual(archive.photos[0].assetLocalIdentifier, "PHAsset-mapped")
        XCTAssertNil(archive.photos[0].manualAssetID)
        XCTAssertEqual(archive.photos[0].decision, retainedDecision)
        XCTAssertEqual(archive.manualAssets[0].copyState, .mappedToPhotoLibrary)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ManualAssetStore.url(for: results[0].asset.relativePath).path))
        XCTAssertEqual(archive.photos[1].manualAssetID, results[1].asset.id)
        XCTAssertEqual(archive.manualAssets[1].copyState, .privateCopy)
        XCTAssertTrue(FileManager.default.fileExists(atPath: ManualAssetStore.url(for: results[1].asset.relativePath).path))
    }

    func testDeleteCopiesRemovesOnlyTheDeletedArchivesPrivateDirectory() throws {
        let deletedID = UUID()
        let retainedID = UUID()
        defer {
            try? ManualAssetStore.deleteCopies(profileID: deletedID)
            try? ManualAssetStore.deleteCopies(profileID: retainedID)
        }
        let deletedURL = try createManualFixtureFile(profileID: deletedID, name: "deleted.asset")
        let retainedURL = try createManualFixtureFile(profileID: retainedID, name: "retained.asset")

        try ManualAssetStore.deleteCopies(profileID: deletedID)

        XCTAssertFalse(FileManager.default.fileExists(atPath: deletedURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: retainedURL.path))
    }

    func testMappedManualAssetRoundTripKeepsDecisionAndPhotoLibraryReference() throws {
        let result = makeManualResults(range: 0..<1, profileID: UUID())[0]
        var archive = ArchiveDocument(profile: makeProfile(referenceIDs: []), photos: [result.photo], manualAssets: [result.asset])
        ManualAssetStore.applyingMappings([result.asset.contentFingerprint: "PHAsset-1"], to: &archive)

        let restored = try JSONDecoder().decode(ArchiveDocument.self, from: JSONEncoder().encode(archive))

        XCTAssertEqual(restored.photos[0].assetLocalIdentifier, "PHAsset-1")
        XCTAssertEqual(restored.photos[0].decision, .pending)
        XCTAssertEqual(restored.manualAssets[0].resolvedPHAssetIdentifier, "PHAsset-1")
        XCTAssertEqual(restored.manualAssets[0].copyState, .mappedToPhotoLibrary)
    }

    // MARK: - 07 / 08 / 09 product boundaries

    func test07PersistsOnlyStoryPlanDraftAndNeverMaterializesPages() async throws {
        let repository = try makeRepository()
        let source = makeEligibleArchive()
        let archive = try StoryPlanWorkflow.generateDraft(from: source, at: fixedDate)

        try await repository.save(document: archive)
        let fetched = try await repository.document(id: archive.id)
        let restored = try XCTUnwrap(fetched)

        XCTAssertNotNil(restored.storyPlanDraft)
        XCTAssertEqual(restored.storyPlanDraft?.state, .generated)
        XCTAssertNil(restored.memoryBook)
        XCTAssertTrue(restored.chapters.isEmpty, "07 persists semantic planning, not document chapters/pages")
        XCTAssertNil(source.storyPlanDraft, "The transaction must not mutate its source aggregate")
    }

    func test08ConfirmsStoryPlanWithoutCreatingMemoryBookDocument() async throws {
        let repository = try makeRepository()
        let source = archiveWithDraft(state: .generated)
        let chapters = try XCTUnwrap(source.storyPlanDraft).chapters
        let archive = try StoryPlanWorkflow.confirm(source, chapters: chapters, at: fixedDate)

        try await repository.save(document: archive)
        let fetched = try await repository.document(id: archive.id)
        let restored = try XCTUnwrap(fetched)

        XCTAssertEqual(restored.storyPlanDraft?.state, .confirmed)
        XCTAssertNotNil(restored.storyPlanDraft?.confirmedAt)
        XCTAssertNil(restored.memoryBook)
        XCTAssertEqual(restored.archiveCheckpoint?.resumeRoute, .bookStyle)
        XCTAssertEqual(source.storyPlanDraft?.state, .generated, "Confirm must be an atomic copy transaction")
    }

    func test09CreatesExactlyOneLetterDocumentFromConfirmedDraftStyleAndPaper() async throws {
        let repository = try makeRepository()
        let source = archiveWithDraft(state: .confirmed)
        let draft = try XCTUnwrap(source.storyPlanDraft)
        let archive = try StoryPlanWorkflow.createFirstDocument(
            from: source,
            style: .quietNight,
            paper: .letter,
            at: fixedDate
        )

        try await repository.save(document: archive)
        let fetched = try await repository.document(id: archive.id)
        let restored = try XCTUnwrap(fetched)

        XCTAssertEqual(restored.memoryBook?.style, .quietNight)
        XCTAssertEqual(restored.memoryBook?.pageSize, .letter)
        XCTAssertEqual(restored.memoryBook?.chapters, draft.chapters)
        XCTAssertEqual(restored.archiveCheckpoint?.resumeRoute, .bookPreview)
        XCTAssertNotNil(restored.memoryBook?.documentRevisionID)
        XCTAssertNil(source.memoryBook, "09 must publish exactly one completed aggregate, not mutate the source")
    }

    func test09FirstDocumentCanBeCreatedDirectlyAsA4WithoutIntermediateLetterRevision() {
        let archive = archiveWithDraft(state: .confirmed)
        let draft = try! XCTUnwrap(archive.storyPlanDraft)

        let result = try! StoryPlanWorkflow.createFirstDocument(
            from: archive,
            style: .fieldNotes,
            paper: .a4,
            at: fixedDate
        )
        let firstDocument = try! XCTUnwrap(result.memoryBook)

        XCTAssertEqual(firstDocument.pageSize, .a4)
        XCTAssertEqual(firstDocument.style, .fieldNotes)
    }

    func test09FailurePreconditionsLeaveSourceAggregateWithoutHalfBuiltDocument() {
        let source = makeEligibleArchive()
        XCTAssertNil(source.storyPlanDraft)
        XCTAssertNil(source.memoryBook)

        XCTAssertThrowsError(try StoryPlanWorkflow.createFirstDocument(from: source, style: .warmPaper, paper: .letter, at: fixedDate)) { error in
            XCTAssertEqual(error as? StoryPlanWorkflowError, .missingDraft)
        }
        XCTAssertNil(source.memoryBook)
        XCTAssertTrue(source.chapters.isEmpty)
    }

    func test09ExistingDocumentMarksOnlyUnlockedPagesNeedsReflowAndRenewsRevision() throws {
        let draftArchive = archiveWithDraft(state: .confirmed)
        var archive = try StoryPlanWorkflow.createFirstDocument(from: draftArchive, style: .warmPaper, paper: .letter, at: fixedDate)
        var book = try XCTUnwrap(archive.memoryBook)
        XCTAssertGreaterThanOrEqual(book.pages.count, 2)
        book.pages[0].isLocked = true
        let lockedPage = book.pages[0]
        let previousRevision = book.documentRevisionID

        archive.memoryBook = book
        let result = try StoryPlanWorkflow.markExistingDocumentNeedsReflow(archive, style: .cinema, paper: .a4, at: fixedDate)
        book = try XCTUnwrap(result.memoryBook)

        XCTAssertEqual(book.pages[0], lockedPage)
        XCTAssertFalse(book.pages[0].needsReflow)
        XCTAssertTrue(book.pages.dropFirst().allSatisfy(\.needsReflow))
        XCTAssertNotEqual(book.documentRevisionID, previousRevision)
        XCTAssertEqual(book.style, .cinema)
        XCTAssertEqual(book.pageSize, .a4)
    }

    // MARK: - Helpers

    private func makeRepository() throws -> SwiftDataArchiveRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredPetProfile.self, configurations: configuration)
        return SwiftDataArchiveRepository(modelContainer: container)
    }

    private func makeValidCheckpointFixtures() -> [(ArchiveCheckpointStage, ArchiveResumeRoute, String, ArchiveDocument)] {
        let profileDraft = ArchiveDocument(profile: PetProfile(name: "", species: .dog, departureYear: 2024))
        let references = ArchiveDocument(profile: makeProfile(referenceIDs: []))
        let scan = ArchiveDocument(profile: makeProfile())
        let review = ArchiveDocument(profile: makeProfile(), photos: [makePhoto(index: 1, decision: .pending)])
        let smartDraft = makeEligibleArchive()
        let storyPlan = archiveWithDraft(state: .generated)
        let stylePending = archiveWithDraft(state: .confirmed)
        var documentReady = archiveWithDraft(state: .confirmed)
        documentReady = try! StoryPlanWorkflow.createFirstDocument(from: documentReady, style: .warmPaper, paper: .letter, at: fixedDate)
        return [
            (.profile, .profile, "Continue profile", profileDraft),
            (.references, .references, "Choose photos", references),
            (.scan, .scan, "Resume scan", scan),
            (.review, .photoReview, "Review photos", review),
            (.smartDraft, .smartDraft, "Continue draft", smartDraft),
            (.storyPlan, .storyPlan, "Review story", storyPlan),
            (.stylePending, .bookStyle, "Choose style", stylePending),
            (.documentReady, .bookPreview, "Continue editing", documentReady)
        ]
    }

    private func makeProfile(id: UUID = UUID(), referenceIDs: [String] = ["ref-1", "ref-2", "ref-3"]) -> PetProfile {
        PetProfile(id: id, name: "Milo", species: .dog, arrivalYear: 2018, departureYear: 2024, lifecycle: .ready, referenceAssetIdentifiers: referenceIDs)
    }

    private func makePhoto(index: Int, decision: PhotoDecision) -> ArchivePhoto {
        ArchivePhoto(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 1_000 + index))!,
            assetLocalIdentifier: "asset-\(index)",
            decision: decision,
            confidence: decision == .selected ? 0.95 : 0.60,
            createdAt: fixedDate.addingTimeInterval(TimeInterval(index * 86_400)),
            decisionSource: decision == .selected ? .human : .automatic
        )
    }

    private func makeEligibleArchive() -> ArchiveDocument {
        let photos = (0..<3).map { makePhoto(index: $0, decision: .selected) }
        return ArchiveDocument(profile: makeProfile(), photos: photos, updatedAt: fixedDate)
    }

    private func makeDraft(profileID: UUID, photos: [ArchivePhoto], state: StoryPlanDraftState) -> StoryPlanDraft {
        let chapterID = UUID(uuidString: "00000000-0000-0000-0000-000000002001")!
        let ids = photos.map(\.id)
        return StoryPlanDraft(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000002002")!,
            petProfileID: profileID,
            sourceMatchGenerationID: "generation-1",
            eventGroups: [.init(id: chapterID, eventKey: "2021", dateLabel: "2021", photoIDs: ids)],
            chapterCandidates: [.init(id: chapterID, title: "Days together", dateLabel: "2021", photoIDs: ids, representativePhotoID: ids.first, sortOrder: 0)],
            photoProfiles: [],
            duplicateGroups: [],
            suggestedPageCount: 6,
            state: state,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            confirmedAt: state == .confirmed ? fixedDate : nil
        )
    }

    private func archiveWithDraft(state: StoryPlanDraftState) -> ArchiveDocument {
        var archive = makeEligibleArchive()
        archive.storyPlanDraft = makeDraft(profileID: archive.id, photos: archive.photos, state: state)
        archive.archiveCheckpoint = ArchiveCheckpoint(stage: state == .confirmed ? .stylePending : .storyPlan, updatedAt: fixedDate)
        return archive
    }

    private func makeManualArchive(count: Int) -> ArchiveDocument {
        let profileID = UUID()
        let results = makeManualResults(range: 0..<count, profileID: profileID)
        return ArchiveDocument(
            profile: makeProfile(id: profileID, referenceIDs: []),
            photos: results.map(\.photo),
            archiveCheckpoint: ArchiveCheckpoint(stage: count >= 3 ? .review : .references, updatedAt: fixedDate),
            manualAssets: results.map(\.asset),
            updatedAt: fixedDate
        )
    }

    private func makeManualResults(range: Range<Int>, profileID: UUID) -> [ManualImportResult] {
        range.map { index in
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 3_000 + index))!
            let relativePath = "Documents/ManualImports/\(profileID.uuidString)/\(id.uuidString).asset"
            let asset = ManualAssetReference(id: id, relativePath: relativePath, contentFingerprint: "fingerprint-\(index)", importedAt: fixedDate)
            let photo = ArchivePhoto(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 4_000 + index))!,
                assetLocalIdentifier: ManualAssetStore.identifier(for: relativePath),
                decision: .pending,
                confidence: 1,
                createdAt: nil,
                decisionSource: .manualImport,
                manualAssetID: id
            )
            return ManualImportResult(asset: asset, photo: photo)
        }
    }

    private func createManualFixtureFile(profileID: UUID, name: String) throws -> URL {
        let url = ManualAssetStore.url(for: "Documents/ManualImports/\(profileID.uuidString)/\(name)")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(name.utf8).write(to: url, options: .atomic)
        return url
    }

}
