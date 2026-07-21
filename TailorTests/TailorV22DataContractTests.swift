import XCTest
@testable import Tailor

/// WP-1 contract tests derived from the frozen Tailor v2.2 product/prototype baseline.
/// These tests deliberately assert the contract rather than preserving accidental
/// behavior in the current implementation.
final class TailorV22DataContractTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_735_689_600)

    // MARK: - StoryPlanDraft

    func testStoryPlanDraftRoundTripPreservesSemanticPlanWithoutRenderedPages() throws {
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let heroID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        let duplicateID = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
        let event = StoryPlanEventGroup(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            eventKey: "2021",
            dateLabel: "2021",
            photoIDs: [heroID, duplicateID]
        )
        let chapter = StoryPlanChapterCandidate(
            id: event.id,
            title: "Days together",
            dateLabel: "2021",
            note: "A real note supplied by the user.",
            photoIDs: event.photoIDs,
            representativePhotoID: heroID,
            sortOrder: 0
        )
        let profile = MemoryBookEditorialProfile(
            photoID: heroID,
            eventKey: "2021",
            role: .hero,
            qualityScore: 0.92,
            heroScore: 0.95,
            duplicateGroupID: "burst-1"
        )
        let draft = StoryPlanDraft(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            petProfileID: profileID,
            sourceMatchGenerationID: "generation-1",
            eventGroups: [event],
            chapterCandidates: [chapter],
            photoProfiles: [profile],
            duplicateGroups: [.init(groupID: "burst-1", retainedPhotoID: heroID, duplicatePhotoIDs: [duplicateID])],
            suggestedPageCount: 6,
            state: .generated,
            createdAt: fixedDate,
            updatedAt: fixedDate
        )

        let data = try JSONEncoder().encode(draft)
        let restored = try JSONDecoder().decode(StoryPlanDraft.self, from: data)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(restored, draft)
        XCTAssertEqual(restored.state, .generated)
        XCTAssertNil(restored.confirmedAt)
        XCTAssertEqual(restored.eventGroups.first?.photoIDs, [heroID, duplicateID])
        XCTAssertEqual(restored.chapterCandidates.first?.representativePhotoID, heroID)
        XCTAssertNil(object["pages"], "Smart Draft must not materialize MemoryBookPage values")
        XCTAssertNil(object["elements"], "Smart Draft must remain semantic, not rendered geometry")
    }

    func testConfirmedStoryPlanPersistsConfirmationWithoutCreatingDocument() throws {
        let confirmedAt = fixedDate.addingTimeInterval(120)
        let draft = StoryPlanDraft(
            petProfileID: UUID(),
            sourceMatchGenerationID: "generation-2",
            eventGroups: [],
            chapterCandidates: [],
            photoProfiles: [],
            duplicateGroups: [],
            suggestedPageCount: 6,
            state: .confirmed,
            createdAt: fixedDate,
            updatedAt: confirmedAt,
            confirmedAt: confirmedAt
        )
        let archive = ArchiveDocument(
            profile: makeProfile(),
            storyPlanDraft: draft,
            archiveCheckpoint: .init(stage: .stylePending, updatedAt: confirmedAt),
            updatedAt: confirmedAt
        )

        let restored: ArchiveDocument = try roundTrip(archive)

        XCTAssertEqual(restored.storyPlanDraft, draft)
        XCTAssertEqual(restored.archiveCheckpoint?.resumeRoute, .bookStyle)
        XCTAssertNil(restored.memoryBook, "08 confirms StoryPlanDraft; 09 creates the first document")
    }

    // MARK: - Archive checkpoints

    func testAllEightCheckpointStagesRoundTripToTheirFrozenResumeRoutes() throws {
        let cases: [(ArchiveCheckpointStage, ArchiveResumeRoute, String)] = [
            (.profile, .profile, "Continue profile"),
            (.references, .references, "Choose photos"),
            (.scan, .scan, "Resume scan"),
            (.review, .photoReview, "Review photos"),
            (.smartDraft, .smartDraft, "Continue draft"),
            (.storyPlan, .storyPlan, "Review story"),
            (.stylePending, .bookStyle, "Choose style"),
            (.documentReady, .bookPreview, "Continue editing")
        ]

        for (stage, route, label) in cases {
            let cursor = stage == .smartDraft ? "step-3" : nil
            let checkpoint = ArchiveCheckpoint(stage: stage, smartDraftStepCursor: cursor, updatedAt: fixedDate)
            let restored: ArchiveCheckpoint = try roundTrip(checkpoint)

            XCTAssertEqual(restored, checkpoint, "Round trip failed for \(stage.rawValue)")
            XCTAssertEqual(restored.resumeRoute, route, "Route mismatch for \(stage.rawValue)")
            XCTAssertEqual(restored.resumeRoute.actionLabel, label, "CTA mismatch for \(stage.rawValue)")
        }
    }

    func testInvalidLateCheckpointFallsBackToEarliestRepairableStage() throws {
        let archive = ArchiveDocument(
            profile: makeProfile(referenceIDs: []),
            memoryBook: nil,
            storyPlanDraft: nil,
            archiveCheckpoint: ArchiveCheckpoint(stage: .documentReady, updatedAt: fixedDate),
            updatedAt: fixedDate
        )

        let restored: ArchiveDocument = try roundTrip(archive)

        XCTAssertEqual(restored.archiveCheckpoint?.stage, .references)
        XCTAssertEqual(restored.archiveCheckpoint?.resumeRoute, .references)
    }

    // MARK: - Book Check cache key

    func testBookCheckCacheKeyIsExactlyRevisionPaperAndRulesVersion() throws {
        let revision = UUID()
        let base = BookCheckCacheKey(documentRevisionID: revision, paperSize: .letter)
        let identical: BookCheckCacheKey = try roundTrip(base)

        XCTAssertEqual(BookCheckCacheKey.currentRulesVersion, 1)
        XCTAssertEqual(base, identical)
        XCTAssertNotEqual(base, .init(documentRevisionID: UUID(), paperSize: .letter, rulesVersion: 1))
        XCTAssertNotEqual(base, .init(documentRevisionID: revision, paperSize: .a4, rulesVersion: 1))
        XCTAssertNotEqual(base, .init(documentRevisionID: revision, paperSize: .letter, rulesVersion: 2))
        XCTAssertEqual(Set([base, identical]).count, 1)
    }

    func testCachedBookCheckResultRequiresAnExactThreePartKeyMatch() {
        let revision = UUID()
        let letterBook = makeBook(revision: revision, paper: .letter)
        let exact = BookCheckResult(
            cacheKey: .init(documentRevisionID: revision, paperSize: .letter, rulesVersion: 1),
            status: .passed,
            findings: [],
            checkedAt: fixedDate
        )
        let archive = ArchiveDocument(profile: letterBook.profile, bookCheckResults: [exact])

        XCTAssertEqual(archive.cachedBookCheckResult(for: letterBook), exact)
        XCTAssertNil(archive.cachedBookCheckResult(for: makeBook(revision: UUID(), paper: .letter)))
        XCTAssertNil(archive.cachedBookCheckResult(for: makeBook(revision: revision, paper: .a4)))
        XCTAssertNil(archive.cachedBookCheckResult(for: letterBook, rulesVersion: 2))
    }

    // MARK: - Recognition generations and eligibility

    func testMatchGenerationIgnoresNameYearsAndCreationTime() {
        let profileID = UUID()
        let first = RecognitionGeneration(
            petProfileID: profileID,
            species: .dog,
            referenceSetFingerprint: "refs-A",
            matcherVersion: "matcher-1",
            createdAt: fixedDate
        )
        let afterNameAndYearEdit = RecognitionGeneration(
            petProfileID: profileID,
            species: .dog,
            referenceSetFingerprint: "refs-A",
            matcherVersion: "matcher-1",
            createdAt: fixedDate.addingTimeInterval(3_600)
        )

        XCTAssertEqual(first.matchGenerationID, afterNameAndYearEdit.matchGenerationID)
    }

    func testMatchGenerationChangesForProfileSpeciesReferenceOrMatcher() {
        let profileID = UUID()
        let base = RecognitionGeneration(petProfileID: profileID, species: .dog, referenceSetFingerprint: "refs-A", matcherVersion: "matcher-1", createdAt: fixedDate)
        let variants = [
            RecognitionGeneration(petProfileID: UUID(), species: .dog, referenceSetFingerprint: "refs-A", matcherVersion: "matcher-1", createdAt: fixedDate),
            RecognitionGeneration(petProfileID: profileID, species: .cat, referenceSetFingerprint: "refs-A", matcherVersion: "matcher-1", createdAt: fixedDate),
            RecognitionGeneration(petProfileID: profileID, species: .dog, referenceSetFingerprint: "refs-B", matcherVersion: "matcher-1", createdAt: fixedDate),
            RecognitionGeneration(petProfileID: profileID, species: .dog, referenceSetFingerprint: "refs-A", matcherVersion: "matcher-2", createdAt: fixedDate)
        ]

        XCTAssertEqual(Set(variants.map(\.matchGenerationID)).count, variants.count)
        XCTAssertFalse(variants.map(\.matchGenerationID).contains(base.matchGenerationID))
    }

    func testEmbeddingKeyDoesNotDependOnPetOrMatchGeneration() {
        let first = FeatureEmbeddingKey(assetID: "asset-1", featureExtractorVersion: "extractor-1")
        let sameAssetForAnotherPet = FeatureEmbeddingKey(assetID: "asset-1", featureExtractorVersion: "extractor-1")
        let upgradedExtractor = FeatureEmbeddingKey(assetID: "asset-1", featureExtractorVersion: "extractor-2")

        XCTAssertEqual(first, sameAssetForAnotherPet)
        XCTAssertNotEqual(first, upgradedExtractor)
    }

    func testGenerationChangeMakesOldHumanDecisionStaleAndIneligible() {
        var photo = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "asset-1",
            decision: .selected,
            confidence: 0.99,
            createdAt: fixedDate,
            matchGenerationID: "generation-1",
            decisionSource: .human
        )

        photo.invalidateForRecognitionGeneration("generation-2")

        XCTAssertEqual(photo.staleDecision, .selected)
        XCTAssertEqual(photo.decision, .pending)
        XCTAssertEqual(photo.matchGenerationID, "generation-2")
        XCTAssertFalse(photo.isEligibleForArchive)
    }

    func testSensitiveApprovalIsAuditableAndNeverUseCannotBeOverridden() {
        let approvalTime = fixedDate.addingTimeInterval(60)
        var sensitive = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "sensitive",
            decision: .pending,
            confidence: 0.9,
            createdAt: fixedDate,
            sensitivityState: .sensitive,
            matchGenerationID: "generation-1"
        )
        sensitive.reconfirm(.selected, generationID: "generation-1", approvedSensitiveAt: nil)
        XCTAssertFalse(sensitive.isEligibleForArchive)
        XCTAssertNil(sensitive.sensitiveApprovedAt)

        sensitive.reconfirm(.selected, generationID: "generation-1", approvedSensitiveAt: approvalTime)
        XCTAssertTrue(sensitive.isEligibleForArchive)
        XCTAssertEqual(sensitive.sensitiveApprovedAt, approvalTime)

        var neverUse = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "never-use",
            decision: .excluded,
            confidence: 1,
            createdAt: fixedDate,
            sensitivityState: .neverUse,
            excludedReason: .neverUse,
            matchGenerationID: "generation-1"
        )
        neverUse.reconfirm(.selected, generationID: "generation-1", approvedSensitiveAt: approvalTime)
        XCTAssertFalse(neverUse.isEligibleForArchive)
        XCTAssertEqual(neverUse.sensitivityState, .neverUse)
    }

    func testNewGenerationClearsSensitiveApprovalUntilExplicitReconfirmation() {
        var sensitive = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "sensitive",
            decision: .selected,
            confidence: 0.9,
            createdAt: fixedDate,
            sensitivityState: .sensitive,
            matchGenerationID: "generation-1",
            decisionSource: .human,
            sensitiveApprovedAt: fixedDate
        )

        sensitive.invalidateForRecognitionGeneration("generation-2")

        XCTAssertEqual(sensitive.staleDecision, .selected)
        XCTAssertNil(sensitive.sensitiveApprovedAt)
        XCTAssertFalse(sensitive.isEligibleForArchive)
    }

    // MARK: - Manual asset lifecycle

    func testManualAssetLifecycleStatesRoundTripWithStableIdentity() throws {
        let id = UUID()
        let privateCopy = ManualAssetReference(
            id: id,
            relativePath: "ManualImports/archive-1/photo.heic",
            contentFingerprint: "sha256-A",
            importedAt: fixedDate,
            copyState: .privateCopy
        )
        let mapped = ManualAssetReference(
            id: id,
            relativePath: "ManualImports/archive-1/photo.heic",
            contentFingerprint: "sha256-A",
            importedAt: fixedDate,
            copyState: .mappedToPhotoLibrary,
            resolvedPHAssetIdentifier: "PHAsset-1"
        )
        let missing = ManualAssetReference(
            id: id,
            relativePath: "ManualImports/archive-1/photo.heic",
            contentFingerprint: "sha256-A",
            importedAt: fixedDate,
            copyState: .missing
        )

        XCTAssertEqual(try roundTrip(privateCopy), privateCopy)
        XCTAssertEqual(try roundTrip(mapped), mapped)
        XCTAssertEqual(try roundTrip(missing), missing)
        XCTAssertEqual(mapped.id, privateCopy.id)
        XCTAssertEqual(mapped.contentFingerprint, privateCopy.contentFingerprint)
        XCTAssertEqual(mapped.resolvedPHAssetIdentifier, "PHAsset-1")
        XCTAssertNil(privateCopy.resolvedPHAssetIdentifier)
    }

    func testManualAssetMustPersistOnlyASandboxRelativePath() {
        let reference = ManualAssetReference(
            relativePath: "/private/var/mobile/Containers/Data/Application/volatile/photo.heic",
            contentFingerprint: "sha256-A",
            importedAt: fixedDate
        )

        XCTAssertFalse(reference.relativePath.hasPrefix("/"), "Absolute container URLs are unstable and forbidden by the frozen contract")
        XCTAssertFalse(reference.relativePath.contains("/Containers/Data/Application/"))
    }

    func testArchiveRoundTripPreservesManualAssetAndPhotoRelationship() throws {
        let manual = ManualAssetReference(
            relativePath: "ManualImports/archive-1/photo.heic",
            contentFingerprint: "sha256-A",
            importedAt: fixedDate
        )
        let photo = ArchivePhoto(
            id: UUID(),
            assetLocalIdentifier: "manual:\(manual.id.uuidString)",
            decision: .pending,
            confidence: 1,
            createdAt: fixedDate,
            decisionSource: .manualImport,
            manualAssetID: manual.id
        )
        let archive = ArchiveDocument(profile: makeProfile(), photos: [photo], manualAssets: [manual])

        let restored: ArchiveDocument = try roundTrip(archive)

        XCTAssertEqual(restored.manualAssets, [manual])
        XCTAssertEqual(restored.photos.first?.manualAssetID, manual.id)
        XCTAssertEqual(restored.photos.first?.decision, .pending)
        XCTAssertEqual(restored.photos.first?.decisionSource, .manualImport)
    }

    // MARK: - ReturnContextStack

    func testReturnContextStackPushPopIsStrictlyLIFO() {
        let root = makeReturnFrame(source: .bookCheck, pageIndex: 4, withIssue: true)
        let child = makeReturnFrame(source: .pageEditorStyle, pageIndex: 4, withIssue: false)
        var stack = ReturnContextStack()

        stack.push(root)
        stack.push(child)

        XCTAssertEqual(stack.top, child)
        XCTAssertEqual(stack.pop(), child, "16 must return to its immediate 11 parent")
        XCTAssertEqual(stack.top, root, "Popping the child must not overwrite the editor's parent context")
        XCTAssertEqual(stack.pop(), root)
        XCTAssertTrue(stack.isEmpty)
    }

    func testReturnContextStackRoundTripPreservesNestedIssueAndPageFallbackData() throws {
        let root = makeReturnFrame(source: .bookCheck, pageIndex: 7, withIssue: true)
        let child = makeReturnFrame(source: .pageEditorStyle, pageIndex: 7, withIssue: false)
        let stack = ReturnContextStack(frames: [root, child])

        let restored: ReturnContextStack = try roundTrip(stack)

        XCTAssertEqual(restored, stack)
        XCTAssertEqual(restored.top, child)
        XCTAssertEqual(root.issueLocator?.ruleID, "text-overflow")
        XCTAssertEqual(root.issueLocator?.formerIssueIndex, 3)
        XCTAssertEqual(root.formerPageIndex, 7)
    }

    func testArchivePersistenceRoundTripRetainsReturnContextStack() throws {
        let frames = [
            makeReturnFrame(source: .finalPreview, pageIndex: 4, withIssue: false),
            makeReturnFrame(source: .pageEditorStyle, pageIndex: 4, withIssue: false)
        ]
        let archive = ArchiveDocument(profile: makeProfile(), returnContextStack: .init(frames: frames))

        let restored: ArchiveDocument = try roundTrip(archive)

        XCTAssertEqual(restored.returnContextStack, .init(frames: frames))
        XCTAssertEqual(restored.returnContextStack.top?.source, .pageEditorStyle)
    }

    func testLegacyDecisionAndSensitivityRawValuesMigrateToFrozenCases() throws {
        let oldDecision = Data("\"needsReview\"".utf8)
        let oldSensitivity = Data("\"needsSensitiveReview\"".utf8)

        XCTAssertEqual(try JSONDecoder().decode(PhotoDecision.self, from: oldDecision), .pending)
        XCTAssertEqual(try JSONDecoder().decode(PhotoSensitivityState.self, from: oldSensitivity), .sensitive)
    }

    // MARK: - Helpers

    private func makeProfile(referenceIDs: [String] = ["ref-1", "ref-2", "ref-3"]) -> PetProfile {
        PetProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            name: "Milo",
            species: .dog,
            arrivalYear: 2018,
            departureYear: 2024,
            lifecycle: .ready,
            referenceAssetIdentifiers: referenceIDs,
            albumStyle: .warmPaper
        )
    }

    private func makeBook(revision: UUID, paper: PDFPageSize) -> MemoryBookDocument {
        MemoryBookDocument(
            profile: makeProfile(),
            photos: [],
            chapters: [],
            pages: [],
            style: .warmPaper,
            pageSize: paper,
            updatedAt: fixedDate,
            documentRevisionID: revision
        )
    }

    private func makeReturnFrame(source: ReturnSourceScreen, pageIndex: Int, withIssue: Bool) -> ReturnContextFrame {
        let pageID = UUID()
        return ReturnContextFrame(
            source: source,
            logicalPageID: pageID,
            formerPageIndex: pageIndex,
            paperSize: .letter,
            issueLocator: withIssue
                ? BookCheckIssueLocator(
                    ruleID: "text-overflow",
                    pageID: pageID,
                    elementID: UUID(),
                    formerIssueIndex: 3
                )
                : nil
        )
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }
}
