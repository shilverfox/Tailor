import Foundation
import Photos
import UIKit
import Vision
import CryptoKit

/// Pure scan policies deliberately live outside PhotoKit/Vision so recovery
/// rules can be exercised without manufacturing ML results in tests.
struct ScanCatalogSnapshot: Equatable, Sendable {
    let identifiers: [String]
    let fingerprint: String

    init(identifiers: [String]) {
        self.identifiers = identifiers
        let source = identifiers.joined(separator: "\u{1F}")
        fingerprint = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum ScanResumePolicy {
    static func startIndex(checkpoint: ScanCheckpoint?, catalog: ScanCatalogSnapshot) -> Int {
        guard checkpoint?.assetCatalogFingerprint == catalog.fingerprint else { return 0 }
        return min(max(checkpoint?.nextAssetIndex ?? 0, 0), catalog.identifiers.count)
    }

    static func retainedCandidates(checkpoint: ScanCheckpoint?, catalog: ScanCatalogSnapshot) -> [ArchivePhoto] {
        let available = Set(catalog.identifiers)
        return (checkpoint?.candidates ?? []).filter { available.contains($0.assetLocalIdentifier) }
    }
}

enum ScanAuditPolicy {
    /// Same catalog resumes the aggregate; any catalog fingerprint change
    /// starts a new audit window rather than mixing two libraries.
    static func startingMetrics(checkpoint: ScanCheckpoint?, catalog: ScanCatalogSnapshot) -> ScanAuditMetrics {
        checkpoint?.assetCatalogFingerprint == catalog.fingerprint ? (checkpoint?.auditMetrics ?? .init()) : .init()
    }

    static func recording(_ outcome: ScanAuditOutcome, into metrics: inout ScanAuditMetrics) {
        metrics.processed += 1
        switch outcome {
        case .imageUnavailable: metrics.imageUnavailable += 1
        case .animalVisionFailure: metrics.animalVisionFailures += 1
        case .speciesRejected: metrics.speciesRejected += 1
        case .identityRejected: metrics.identityRejected += 1
        case .candidate: metrics.candidates += 1
        }
    }
}

enum ScanAuditOutcome { case imageUnavailable, animalVisionFailure, speciesRejected, identityRejected, candidate }

enum ScanReferencePolicy {
    static let minimumCount = 3

    static func isValid(requestedIdentifiers: [String], resolvedCount: Int, usableFeatureCount: Int) -> Bool {
        Set(requestedIdentifiers).count >= minimumCount && resolvedCount >= minimumCount && usableFeatureCount >= minimumCount
    }
}

enum ScanThermalLevel: Sendable, Equatable { case nominal, fair, serious, critical }

struct ScanRuntimeState: Sendable, Equatable {
    var isLowPowerModeEnabled: Bool
    var thermalLevel: ScanThermalLevel

    static var current: ScanRuntimeState {
        let level: ScanThermalLevel
        switch ProcessInfo.processInfo.thermalState {
        case .serious: level = .serious
        case .critical: level = .critical
        case .fair: level = .fair
        default: level = .nominal
        }
        return ScanRuntimeState(isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled, thermalLevel: level)
    }
}

enum ScanRuntimePolicy {
    static func pauseFailure(for state: ScanRuntimeState) -> ScanFailure? {
        if state.isLowPowerModeEnabled { return .lowPower }
        if state.thermalLevel == .serious || state.thermalLevel == .critical { return .thermal }
        return nil
    }
}

/// Keeps the expensive identity embedding behind the inexpensive species
/// detector. A successful Vision request with confidence 0 means "no target
/// animal was found"; it is not an invitation to run a second model.
enum ScanWorkloadPolicy {
    static func shouldGenerateEmbedding(animalConfidence: Double) -> Bool {
        animalConfidence > 0
    }
}

/// Versioned local thresholds. Defaults are deliberately conservative starting
/// points, not calibrated claims: they must be reviewed against a labelled,
/// consented-on-device acceptance set before any release adjustment.
struct PetRecognitionPolicy: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var animalSpeciesGate: Double
    var identityCandidateGate: Double
    var highAutoConfidenceGate: Double
    var highAutoReferenceAgreementGate: Double
    var highAutoMinimumReferenceMatches: Int

    static let standard = PetRecognitionPolicy(
        animalSpeciesGate: 0.60,
        identityCandidateGate: 0.42,
        highAutoConfidenceGate: 0.86,
        highAutoReferenceAgreementGate: 0.56,
        highAutoMinimumReferenceMatches: 2
    )

    func assess(animalConfidence: Double, referenceSimilarities: [Double]) -> PetRecognitionAssessment {
        let normalizedAnimal = min(max(animalConfidence, 0), 1)
        let normalizedSimilarities = referenceSimilarities.map { min(max($0, 0), 1) }
        let maximumSimilarity = normalizedSimilarities.max() ?? 0
        let agreementCount = normalizedSimilarities.filter { $0 >= highAutoReferenceAgreementGate }.count
        let combinedConfidence = min(0.99, max(0.01, normalizedAnimal * 0.35 + maximumSimilarity * 0.65))

        guard normalizedAnimal >= animalSpeciesGate else {
            return PetRecognitionAssessment(disposition: .rejectedSpecies, confidence: combinedConfidence, maximumReferenceSimilarity: maximumSimilarity, agreeingReferenceCount: agreementCount, referenceCount: normalizedSimilarities.count)
        }
        guard maximumSimilarity >= identityCandidateGate else {
            return PetRecognitionAssessment(disposition: .rejectedIdentity, confidence: combinedConfidence, maximumReferenceSimilarity: maximumSimilarity, agreeingReferenceCount: agreementCount, referenceCount: normalizedSimilarities.count)
        }
        let highAuto = combinedConfidence >= highAutoConfidenceGate
            && agreementCount >= highAutoMinimumReferenceMatches
        return PetRecognitionAssessment(disposition: highAuto ? .autoSelected : .needsReview, confidence: combinedConfidence, maximumReferenceSimilarity: maximumSimilarity, agreeingReferenceCount: agreementCount, referenceCount: normalizedSimilarities.count)
    }
}

enum PetRecognitionDisposition: Equatable, Sendable {
    case rejectedSpecies, rejectedIdentity, needsReview, autoSelected
}

struct PetRecognitionAssessment: Equatable, Sendable {
    var disposition: PetRecognitionDisposition
    var confidence: Double
    var maximumReferenceSimilarity: Double
    var agreeingReferenceCount: Int
    var referenceCount: Int

    var isCandidate: Bool { disposition == .needsReview || disposition == .autoSelected }
}

/// Pure, labelled-sample reporting. It is intentionally not wired to change a
/// threshold automatically: samples must be reviewed before calibration.
struct PetRecognitionLabeledSample: Sendable, Equatable {
    var animalConfidence: Double
    var referenceSimilarities: [Double]
    var isTargetPet: Bool
}

struct PetRecognitionEvaluationReport: Sendable, Equatable {
    var evaluatedCount: Int
    var candidatePrecision: Double
    var candidateRecall: Double
    var highConfidenceFalsePositiveRate: Double
    var highConfidenceCount: Int

    static func evaluate(_ samples: [PetRecognitionLabeledSample], policy: PetRecognitionPolicy) -> PetRecognitionEvaluationReport {
        let assessments = samples.map { policy.assess(animalConfidence: $0.animalConfidence, referenceSimilarities: $0.referenceSimilarities) }
        let candidates = zip(samples, assessments).filter { $0.1.isCandidate }
        let trueCandidates = candidates.filter { $0.0.isTargetPet }.count
        let actualTargets = samples.filter(\.isTargetPet).count
        let high = zip(samples, assessments).filter { $0.1.disposition == .autoSelected }
        let highFalsePositives = high.filter { !$0.0.isTargetPet }.count
        return PetRecognitionEvaluationReport(
            evaluatedCount: samples.count,
            candidatePrecision: candidates.isEmpty ? 0 : Double(trueCandidates) / Double(candidates.count),
            candidateRecall: actualTargets == 0 ? 0 : Double(trueCandidates) / Double(actualTargets),
            highConfidenceFalsePositiveRate: high.isEmpty ? 0 : Double(highFalsePositives) / Double(high.count),
            highConfidenceCount: high.count
        )
    }
}

enum VisualDuplicateDisposition: Equatable, Sendable {
    case unique
    case grouped(anchorIdentifier: String, kind: VisualDuplicateKind)
    case suppressedByHistoricalDecision(anchorIdentifier: String)
}

enum VisualDuplicateKind: String, Codable, Equatable, Sendable { case burst, reimport }

/// Similar frames remain visible as a local group until reviewed; a new
/// duplicate never overwrites or deletes an earlier user decision.
enum VisualDuplicatePolicy {
    static let maximumHammingDistance = 4
    static let burstWindow: TimeInterval = 3

    static func classify(hash: UInt64?, createdAt: Date?, against existing: [ArchivePhoto]) -> VisualDuplicateDisposition {
        guard let hash,
              let anchor = existing.first(where: {
                  guard let existingHash = $0.visualHash else { return false }
                  return hammingDistance(hash, existingHash) <= maximumHammingDistance
              })
        else { return .unique }
        if anchor.decision != .needsReview {
            return .suppressedByHistoricalDecision(anchorIdentifier: anchor.assetLocalIdentifier)
        }
        let kind: VisualDuplicateKind
        if let createdAt, let anchorDate = anchor.createdAt, abs(createdAt.timeIntervalSince(anchorDate)) <= burstWindow {
            kind = .burst
        } else {
            kind = .reimport
        }
        return .grouped(anchorIdentifier: anchor.assetLocalIdentifier, kind: kind)
    }

    static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }
}

struct PhotoKitVisionScanner: PetScanServicing {
    // These thresholds are deliberately conservative: a false inclusion is
    // more harmful to a memorial archive than asking the user to review one
    // extra photo. They must be calibrated against the acceptance photo set.
    // Keep the first-pass gate permissive enough for age, pose and lighting
    // changes. Precision is enforced by the confidence buckets and review UI;
    // an overly strict gate silently drops real memories.
    private let policy: PetRecognitionPolicy
    private let runtimeState: @Sendable () -> ScanRuntimeState

    init(policy: PetRecognitionPolicy = .standard, runtimeState: @escaping @Sendable () -> ScanRuntimeState = { .current }) {
        self.policy = policy
        self.runtimeState = runtimeState
    }
    func scan(profile: PetProfile) async throws -> [ArchivePhoto] {
        try await scan(profile: profile, checkpoint: nil) { _ in }
    }

    func scan(
        profile: PetProfile,
        checkpoint: ScanCheckpoint?,
        onProgress: @escaping @Sendable (ScanCheckpoint) async -> Void
    ) async throws -> [ArchivePhoto] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { throw ScanFailure.insufficientAccess }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        guard assets.count > 0 else { throw ScanFailure.unavailable }
        let catalog = ScanCatalogSnapshot(identifiers: (0..<assets.count).map { assets.object(at: $0).localIdentifier })

        let featureIndex = PetFeaturePrintIndex(profileID: profile.id)
        await featureIndex.load()

        let referenceAssets = PHAsset.fetchAssets(withLocalIdentifiers: profile.referenceAssetIdentifiers, options: nil)
        let referencePrints = try await featurePrints(for: referenceAssets)
        guard ScanReferencePolicy.isValid(
            requestedIdentifiers: profile.referenceAssetIdentifiers,
            resolvedCount: referenceAssets.count,
            usableFeatureCount: referencePrints.count
        ) else { throw ScanFailure.insufficientReferences }

        var candidates = ScanResumePolicy.retainedCandidates(checkpoint: checkpoint, catalog: catalog)
        var auditMetrics = ScanAuditPolicy.startingMetrics(checkpoint: checkpoint, catalog: catalog)
        // Coverage is distinct from candidate results: most library photos are
        // rejected and must still be remembered as already considered. Without
        // it a later explicit refresh has no way to distinguish 8,000 rejected
        // historic assets from newly added assets.
        var processedAssetIdentifiers = checkpoint?.processedAssetIdentifiers ?? []
        var processedIdentifiers = Set(processedAssetIdentifiers)
        for identifier in profile.referenceAssetIdentifiers where processedIdentifiers.insert(identifier).inserted {
            processedAssetIdentifiers.append(identifier)
        }
        var seenIdentifiers = Set(candidates.map(\.assetLocalIdentifier))
        let startIndex = ScanResumePolicy.startIndex(checkpoint: checkpoint, catalog: catalog)
        // Publish the real library size before preparing or processing more assets.
        // A resumed scan must retain its candidates and cursor in this first update.
        await onProgress(ScanCheckpoint(nextAssetIndex: startIndex, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
        for index in startIndex..<assets.count {
            guard !Task.isCancelled else { auditMetrics.interrupted += 1; throw ScanFailure.interrupted }
            let asset = assets.object(at: index)
            // A completed catalogue may have a new fingerprint because the
            // user added one photo. Skip every previously indexed identifier
            // before applying runtime gates or audit accounting. Otherwise a
            // zero-delta refresh can be blocked by Low Power Mode and historic
            // assets are incorrectly counted as newly processed a second time.
            if processedIdentifiers.contains(asset.localIdentifier) { continue }
            if let resourceFailure = ScanRuntimePolicy.pauseFailure(for: runtimeState()) {
                if resourceFailure == .lowPower { auditMetrics.lowPower += 1 } else { auditMetrics.thermal += 1 }
                throw resourceFailure
            }
            auditMetrics.processed += 1
            processedIdentifiers.insert(asset.localIdentifier)
            processedAssetIdentifiers.append(asset.localIdentifier)
            if !profile.referenceAssetIdentifiers.contains(asset.localIdentifier),
               !seenIdentifiers.contains(asset.localIdentifier) {
                guard let cgImage = try? await image(for: asset) else {
                    auditMetrics.imageUnavailable += 1
                    await onProgress(ScanCheckpoint(nextAssetIndex: index + 1, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
                    continue
                }
                guard let animalConfidence = try? animalConfidence(in: cgImage, species: profile.species) else {
                    auditMetrics.animalVisionFailures += 1
                    await onProgress(ScanCheckpoint(nextAssetIndex: index + 1, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
                    continue
                }
                // `VNRecognizeAnimalsRequest` can complete successfully while
                // finding no target species.  Those assets must stop here.
                // Continuing into feature-print generation would run the
                // expensive embedding model for every landscape, person, and
                // screenshot in a large library.
                guard ScanWorkloadPolicy.shouldGenerateEmbedding(animalConfidence: animalConfidence) else {
                    auditMetrics.speciesRejected += 1
                    await onProgress(ScanCheckpoint(nextAssetIndex: index + 1, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
                    continue
                }
                let visualHash = averageHash(cgImage)
                let candidatePrint: VNFeaturePrintObservation?
                if let cached = await featureIndex.observation(for: asset.localIdentifier) {
                    candidatePrint = cached
                } else if let generated = try? featurePrint(for: cgImage) {
                    await featureIndex.store(generated, for: asset.localIdentifier)
                    candidatePrint = generated
                } else {
                    candidatePrint = nil
                }
                let similarities = (try? similaritiesToReferences(candidatePrint, references: referencePrints)) ?? []
                let assessment = policy.assess(animalConfidence: animalConfidence, referenceSimilarities: similarities)
                // Both strict species and identity gates must pass before an
                // image enters review. A weak single-reference match can still
                // be reviewed, but it can never be selected automatically.
                guard assessment.isCandidate else {
                    if assessment.disposition == .rejectedSpecies { auditMetrics.speciesRejected += 1 }
                    if assessment.disposition == .rejectedIdentity { auditMetrics.identityRejected += 1 }
                    await onProgress(ScanCheckpoint(nextAssetIndex: index + 1, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
                    continue
                }
                let duplicate = VisualDuplicatePolicy.classify(hash: visualHash, createdAt: asset.creationDate, against: candidates)
                if case .suppressedByHistoricalDecision = duplicate {
                    auditMetrics.duplicateSuppressed += 1
                    // An earlier explicit user decision is immutable. Do not
                    // re-add a near-identical reimport and do not alter it.
                    await onProgress(ScanCheckpoint(nextAssetIndex: index + 1, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
                    continue
                }
                var duplicateGroupID: String?
                var decision: PhotoDecision = assessment.disposition == .autoSelected ? .selected : .needsReview
                if case .grouped(let anchorIdentifier, _) = duplicate {
                    auditMetrics.duplicateGrouped += 1
                    duplicateGroupID = "visual-\(anchorIdentifier)"
                    // A duplicate is never auto-selected. It remains a review
                    // candidate even if its anchor had strong evidence.
                    decision = .needsReview
                    if let anchorIndex = candidates.firstIndex(where: { $0.assetLocalIdentifier == anchorIdentifier }),
                       candidates[anchorIndex].visualDuplicateGroupID == nil {
                        candidates[anchorIndex].visualDuplicateGroupID = duplicateGroupID
                    }
                }
                // This scanner has no medically validated sensitive-content classifier.
                // Ambiguous assets remain ordinary low-confidence candidates instead of
                // being described as illness, end-of-life, or any other sensitive event.
                candidates.append(ArchivePhoto(
                    id: UUID(),
                    assetLocalIdentifier: asset.localIdentifier,
                    decision: decision,
                    confidence: assessment.confidence,
                    createdAt: asset.creationDate,
                    sensitivityState: .normal,
                    excludedReason: nil,
                    localDateRange: asset.creationDate.map { ArchivePhotoDateRange.day(containing: $0) },
                    pixelSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                    visualHash: visualHash,
                    recognitionEvidence: PetRecognitionEvidence(
                        policyVersion: PetRecognitionPolicy.currentVersion,
                        animalConfidence: animalConfidence,
                        maximumReferenceSimilarity: assessment.maximumReferenceSimilarity,
                        agreeingReferenceCount: assessment.agreeingReferenceCount,
                        referenceCount: assessment.referenceCount,
                        wasHighAutoSelected: assessment.disposition == .autoSelected
                    ),
                    visualDuplicateGroupID: duplicateGroupID
                ))
                auditMetrics.candidates += 1
                if decision == .selected { auditMetrics.autoSelected += 1 } else { auditMetrics.needsReview += 1 }
                seenIdentifiers.insert(asset.localIdentifier)
            }
            // Publish each asset: long libraries and slow PhotoKit requests must never
            // leave the UI looking stalled while waiting for an arbitrary batch.
            await onProgress(ScanCheckpoint(nextAssetIndex: index + 1, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
        }
        await onProgress(ScanCheckpoint(nextAssetIndex: assets.count, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
        await featureIndex.flush()
        return candidates.sorted { $0.confidence > $1.confidence }
    }

    func deleteLocalIndex(profileID: UUID) async {
        PetFeaturePrintIndex.delete(profileID: profileID)
    }

    private func featurePrints(for assets: PHFetchResult<PHAsset>) async throws -> [VNFeaturePrintObservation] {
        var prints: [VNFeaturePrintObservation] = []
        for index in 0..<assets.count {
            let asset = assets.object(at: index)
            guard let image = try? await image(for: asset), let print = try? featurePrint(for: image) else { continue }
            prints.append(print)
        }
        return prints
    }

    private func image(for asset: PHAsset) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            // A user-selected reference can be iCloud-only. This downloads that
            // asset to the phone for on-device processing; nothing is uploaded.
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 256, height: 256),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: ScanFailure.interrupted)
                } else if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let cgImage = image?.cgImage {
                    continuation.resume(returning: cgImage)
                } else {
                    continuation.resume(throwing: ScanFailure.unavailable)
                }
            }
        }
    }

    private func animalConfidence(in image: CGImage, species: PetSpecies) throws -> Double {
        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        let keyword = species == .dog ? "dog" : "cat"
        return (request.results ?? []).flatMap(\.labels).first(where: { $0.identifier.lowercased().contains(keyword) }).map { Double($0.confidence) } ?? 0
    }

    private func featurePrint(for image: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let observation = request.results?.first else { throw ScanFailure.unavailable }
        return observation
    }

    private func similaritiesToReferences(_ image: CGImage, references: [VNFeaturePrintObservation]) throws -> [Double] {
        try similaritiesToReferences(try featurePrint(for: image), references: references)
    }

    private func similaritiesToReferences(_ candidate: VNFeaturePrintObservation?, references: [VNFeaturePrintObservation]) throws -> [Double] {
        guard !references.isEmpty else { throw ScanFailure.insufficientReferences }
        guard let candidate else { return [] }
        return try references.map { reference -> Double in
            var distance: Float = 0
            try candidate.computeDistance(&distance, to: reference)
            return max(0, min(1, 1 - Double(distance) / 20))
        }
    }

    /// A small local average hash catches exact re-imports and near-identical
    /// burst frames without uploading or retaining image pixels. It is only a
    /// duplicate filter; identity matching still comes from Vision feature prints.
    private func averageHash(_ image: CGImage) -> UInt64? {
        var pixels = [UInt8](repeating: 0, count: 64)
        guard let context = CGContext(data: &pixels, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 8, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return nil }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: 8, height: 8))
        let average = pixels.reduce(0, { $0 + Int($1) }) / pixels.count
        var hash: UInt64 = 0
        for (index, pixel) in pixels.enumerated() where Int(pixel) >= average { hash |= UInt64(1) << UInt64(index) }
        return hash
    }

}

/// Local feature-print cache. It is intentionally file-backed for now; the
/// repository boundary can migrate this same record shape to SQLite without
/// changing scan or matching logic.
actor PetFeaturePrintIndex {
    private let fileURL: URL
    private var vectors: [String: Data] = [:]
    private var loaded = false

    init(profileID: UUID, baseDirectory: URL = .applicationSupportDirectory) {
        fileURL = Self.fileURL(profileID: profileID, baseDirectory: baseDirectory)
    }

    static func fileURL(profileID: UUID, baseDirectory: URL = .applicationSupportDirectory) -> URL {
        baseDirectory.appending(path: "Tailor/feature-index-\(profileID.uuidString).json")
    }

    static func delete(profileID: UUID, baseDirectory: URL = .applicationSupportDirectory) {
        try? FileManager.default.removeItem(at: fileURL(profileID: profileID, baseDirectory: baseDirectory))
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode([String: Data].self, from: data) else { return }
        vectors = decoded
    }

    func observation(for identifier: String) -> VNFeaturePrintObservation? {
        guard let data = vectors[identifier] else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }

    func store(_ observation: VNFeaturePrintObservation, for identifier: String) {
        vectors[identifier] = try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    // Internal for file-contract tests; production calls the Vision overload.
    func storeSerializedFeatureData(_ data: Data, for identifier: String) {
        vectors[identifier] = data
    }

    func serializedFeatureData(for identifier: String) -> Data? {
        vectors[identifier]
    }

    func flush() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(vectors) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
