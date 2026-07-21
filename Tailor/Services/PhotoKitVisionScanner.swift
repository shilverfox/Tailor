import Foundation
import Photos
import UIKit
import Vision
import CryptoKit
import CoreImage

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

/// The first image is intentionally cheap because it is requested for the
/// whole library. The second is requested only after the target dog/cat gate
/// passes, preserving detail for individual-similarity evidence without
/// turning a large library scan into a full-resolution photo download.
enum ScanImageResolution {
    static let speciesGate = CGSize(width: 256, height: 256)
    static let identityFeature = CGSize(width: 768, height: 768)
}

/// Versioned local thresholds. Defaults are deliberately conservative starting
/// points, not calibrated claims: they must be reviewed against a labelled,
/// consented-on-device acceptance set before any release adjustment.
struct PetRecognitionPolicy: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var animalSpeciesGate: Double
    /// Independent `VNClassifyImageRequest` confirmation for automatic
    /// selection of the requested generic species ("dog" or "cat"). It is
    /// deliberately separate from `VNRecognizeAnimalsRequest`: the latter can
    /// label macaques as dogs. Low evidence remains reviewable, never dropped.
    var genericSpeciesAutoSelectionGate: Double
    var identityCandidateGate: Double
    var highAutoConfidenceGate: Double
    var highAutoReferenceAgreementGate: Double
    var highAutoMinimumReferenceMatches: Int

    static let standard = PetRecognitionPolicy(
        animalSpeciesGate: 0.60,
        genericSpeciesAutoSelectionGate: 0.06,
        identityCandidateGate: 0.42,
        highAutoConfidenceGate: 0.86,
        highAutoReferenceAgreementGate: 0.56,
        highAutoMinimumReferenceMatches: 2
    )

    func assess(
        animalConfidence: Double,
        genericSpeciesConfidence: Double = 1,
        referenceSimilarities: [Double]
    ) -> PetRecognitionAssessment {
        let normalizedAnimal = min(max(animalConfidence, 0), 1)
        let normalizedGenericSpecies = min(max(genericSpeciesConfidence, 0), 1)
        let normalizedSimilarities = referenceSimilarities.map { min(max($0, 0), 1) }
        let maximumSimilarity = normalizedSimilarities.max() ?? 0
        let agreementCount = normalizedSimilarities.filter { $0 >= highAutoReferenceAgreementGate }.count
        let combinedConfidence = min(0.99, max(0.01, normalizedAnimal * 0.25 + normalizedGenericSpecies * 0.20 + maximumSimilarity * 0.55))

        guard normalizedAnimal >= animalSpeciesGate else {
            return PetRecognitionAssessment(disposition: .rejectedSpecies, confidence: combinedConfidence, maximumReferenceSimilarity: maximumSimilarity, agreeingReferenceCount: agreementCount, referenceCount: normalizedSimilarities.count)
        }
        guard maximumSimilarity >= identityCandidateGate else {
            return PetRecognitionAssessment(disposition: .rejectedIdentity, confidence: combinedConfidence, maximumReferenceSimilarity: maximumSimilarity, agreeingReferenceCount: agreementCount, referenceCount: normalizedSimilarities.count)
        }
        let highAuto = combinedConfidence >= highAutoConfidenceGate
            && normalizedGenericSpecies >= genericSpeciesAutoSelectionGate
            && agreementCount >= highAutoMinimumReferenceMatches
        return PetRecognitionAssessment(disposition: highAuto ? .autoSelected : .pending, confidence: combinedConfidence, maximumReferenceSimilarity: maximumSimilarity, agreeingReferenceCount: agreementCount, referenceCount: normalizedSimilarities.count)
    }
}

enum PetRecognitionDisposition: Equatable, Sendable {
    case rejectedSpecies, rejectedIdentity, pending, autoSelected
}

struct PetRecognitionAssessment: Equatable, Sendable {
    var disposition: PetRecognitionDisposition
    var confidence: Double
    var maximumReferenceSimilarity: Double
    var agreeingReferenceCount: Int
    var referenceCount: Int

    var isCandidate: Bool { disposition == .pending || disposition == .autoSelected }
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
        if anchor.decision != .pending {
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

struct VisionAnimalRecognitionResult {
    let confidence: Double
    let genericSpeciesConfidence: Double
    let subjectRegion: CGRect?
}

/// Composition evidence is deliberately separate from identity evidence.
/// Animal recognition remains the first choice, while attention saliency is
/// only a framing fallback when Vision cannot label the subject. The fallback
/// never changes scan inclusion, identity scores, or auto-selection gates.
enum VisionFocalRegionDetector {
    static func animalRecognition(in image: CGImage, preferredSpecies: PetSpecies?) throws -> VisionAnimalRecognitionResult {
        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        let keyword = preferredSpecies.map { $0 == .dog ? "dog" : "cat" }
        let candidates = (request.results ?? []).compactMap { observation -> (confidence: Double, region: CGRect)? in
            let labels = observation.labels.filter { label in
                guard let keyword else { return true }
                return label.identifier.lowercased().contains(keyword)
            }
            guard let label = labels.max(by: { $0.confidence < $1.confidence }) else { return nil }
            return (Double(label.confidence), FocalCropPolicy.topLeftRegion(fromVisionBoundingBox: observation.boundingBox))
        }
        if let best = candidates.max(by: { $0.confidence < $1.confidence }) {
            let genericSpeciesConfidence = try genericSpeciesConfidence(in: image, species: preferredSpecies)
            return VisionAnimalRecognitionResult(confidence: best.confidence, genericSpeciesConfidence: genericSpeciesConfidence, subjectRegion: best.region)
        }
        // A production scan with a requested species must stop here. Running
        // two saliency models for every landscape, screenshot, or wrong-species
        // photo would multiply the cost of a large-library scan without making
        // that rejected asset eligible. Generic callers (such as the isolated
        // framing QA route) may still ask for composition-only fallback data.
        guard preferredSpecies == nil else {
            return VisionAnimalRecognitionResult(confidence: 0, genericSpeciesConfidence: 0, subjectRegion: nil)
        }
        return VisionAnimalRecognitionResult(confidence: 0, genericSpeciesConfidence: 0, subjectRegion: try? salientRegion(in: image))
    }

    /// A second, independent Vision model is only evaluated after the animal
    /// recognizer has already found the requested species. This keeps the
    /// large-library workload bounded while preventing cross-species false
    /// positives from receiving an automatic selection.
    private static func genericSpeciesConfidence(in image: CGImage, species: PetSpecies?) throws -> Double {
        guard let species else { return 0 }
        let keyword = species == .dog ? "dog" : "cat"
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        return Double(
            (request.results ?? [])
                .filter { $0.identifier.caseInsensitiveCompare(keyword) == .orderedSame }
                .map(\.confidence)
                .max() ?? 0
        )
    }

    /// Crops the image to the detected animal region expanded by `margin` on
    /// each side (default 20%), so identity feature prints describe the pet
    /// rather than the background. `region` is top-left normalized (as produced
    /// by `FocalCropPolicy.topLeftRegion`); CGImage pixels are also top-left, so
    /// no Y flip is needed. Returns the original image when there is no usable
    /// region or cropping fails, keeping the pipeline safe by default.
    static func croppedToAnimal(_ image: CGImage, region: CGRect?, margin: CGFloat = 0.20) -> CGImage {
        guard let region, region.width > 0, region.height > 0 else { return image }
        let expanded = CGRect(
            x: region.minX - region.width * margin,
            y: region.minY - region.height * margin,
            width: region.width * (1 + margin * 2),
            height: region.height * (1 + margin * 2)
        )
        let clamped = expanded.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else { return image }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let pixelRect = CGRect(
            x: (clamped.minX * width).rounded(.down),
            y: (clamped.minY * height).rounded(.down),
            width: (clamped.width * width).rounded(.up),
            height: (clamped.height * height).rounded(.up)
        ).intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !pixelRect.isNull, pixelRect.width >= 1, pixelRect.height >= 1,
              let cropped = image.cropping(to: pixelRect) else { return image }
        return cropped
    }

    private static func salientRegion(in image: CGImage) throws -> CGRect? {
        let attention = VNGenerateAttentionBasedSaliencyImageRequest()
        try VNImageRequestHandler(cgImage: image).perform([attention])
        var observations = attention.results ?? []
        var objects = observations.flatMap { $0.salientObjects ?? [] }
        if objects.isEmpty {
            let objectness = VNGenerateObjectnessBasedSaliencyImageRequest()
            try VNImageRequestHandler(cgImage: image).perform([objectness])
            observations += objectness.results ?? []
            objects = observations.flatMap { $0.salientObjects ?? [] }
        }
        if let best = objects.max(by: {
            Double($0.confidence) * Double($0.boundingBox.width) * Double($0.boundingBox.height)
                < Double($1.confidence) * Double($1.boundingBox.width) * Double($1.boundingBox.height)
        }) {
            return FocalCropPolicy.topLeftRegion(fromVisionBoundingBox: best.boundingBox)
        }
        return heatmapRegion(from: observations)
    }

    private static func heatmapRegion(from observations: [VNSaliencyImageObservation]) -> CGRect? {
        guard let pixelBuffer = observations.first?.pixelBuffer else { return nil }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let width = max(1, Int(image.extent.width.rounded()))
        let height = max(1, Int(image.extent.height.rounded()))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        CIContext(options: [.cacheIntermediates: false]).render(
            image,
            toBitmap: &pixels,
            rowBytes: width * 4,
            bounds: image.extent,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        var total = 0.0
        var weightedX = 0.0
        var weightedY = 0.0
        var minimum = UInt8.max
        var maximum = UInt8.min
        for y in 0..<height {
            for x in 0..<width {
                let value = pixels[(y * width + x) * 4]
                minimum = min(minimum, value)
                maximum = max(maximum, value)
                let weight = Double(value)
                total += weight
                weightedX += (Double(x) + 0.5) * weight
                weightedY += (Double(y) + 0.5) * weight
            }
        }
        guard total > 0, Int(maximum) - Int(minimum) >= 4 else { return nil }
        let centre = CGPoint(
            x: weightedX / total / Double(width),
            // Core Image exposes the saliency buffer in bottom-left image
            // coordinates; Tailor persists top-left source coordinates.
            y: 1 - weightedY / total / Double(height)
        )
        return FocalCropPolicy.normalizedSubjectRegion(
            CGRect(x: centre.x - 0.15, y: centre.y - 0.15, width: 0.30, height: 0.30)
        )
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
        let referencePrints = try await featurePrints(for: referenceAssets, species: profile.species, index: featureIndex)
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
                guard let animalRecognition = try? animalRecognition(in: cgImage, species: profile.species) else {
                    auditMetrics.animalVisionFailures += 1
                    await onProgress(ScanCheckpoint(nextAssetIndex: index + 1, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
                    continue
                }
                // `VNRecognizeAnimalsRequest` can complete successfully while
                // finding no target species.  Those assets must stop here.
                // Continuing into feature-print generation would run the
                // expensive embedding model for every landscape, person, and
                // screenshot in a large library.
                let animalConfidence = animalRecognition.confidence
                let genericSpeciesConfidence = animalRecognition.genericSpeciesConfidence
                guard ScanWorkloadPolicy.shouldGenerateEmbedding(animalConfidence: animalConfidence),
                      animalConfidence >= policy.animalSpeciesGate else {
                    auditMetrics.speciesRejected += 1
                    await onProgress(ScanCheckpoint(nextAssetIndex: index + 1, totalAssets: assets.count, candidates: candidates, assetCatalogFingerprint: catalog.fingerprint, auditMetrics: auditMetrics, processedAssetIdentifiers: processedAssetIdentifiers))
                    continue
                }
                let visualHash = averageHash(cgImage)
                let candidatePrint: VNFeaturePrintObservation?
                if let cached = await featureIndex.observation(for: asset.localIdentifier) {
                    candidatePrint = cached
                } else {
                    let identitySource: CGImage
                    if let highResolution = try? await image(for: asset, targetSize: ScanImageResolution.identityFeature, highQuality: true) {
                        identitySource = highResolution
                        auditMetrics.highResolutionIdentityImages += 1
                    } else {
                        // Do not discard a local memory merely because its larger
                        // rendition is unavailable. It remains a lower-quality
                        // candidate and is visible in local scan diagnostics.
                        identitySource = cgImage
                        auditMetrics.identityImageFallbacks += 1
                    }
                    // Identity feature print is taken from the detected animal region
                    // (expanded by a safety margin), not the whole frame, so the
                    // embedding describes the pet rather than the background.
                    let candidateImage = VisionFocalRegionDetector.croppedToAnimal(identitySource, region: animalRecognition.subjectRegion)
                    if let generated = try? featurePrint(for: candidateImage) {
                        await featureIndex.store(generated, for: asset.localIdentifier)
                        candidatePrint = generated
                    } else {
                        candidatePrint = nil
                    }
                }
                let distances = (try? distancesToReferences(candidatePrint, references: referencePrints)) ?? []
                let similarities = distances.map(similarity(from:))
                let assessment = policy.assess(
                    animalConfidence: animalConfidence,
                    genericSpeciesConfidence: genericSpeciesConfidence,
                    referenceSimilarities: similarities
                )
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
                var decision: PhotoDecision = assessment.disposition == .autoSelected ? .selected : .pending
                if case .grouped(let anchorIdentifier, _) = duplicate {
                    auditMetrics.duplicateGrouped += 1
                    duplicateGroupID = "visual-\(anchorIdentifier)"
                    // A duplicate is never auto-selected. It remains a review
                    // candidate even if its anchor had strong evidence.
                    decision = .pending
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
                        wasHighAutoSelected: assessment.disposition == .autoSelected,
                        minimumReferenceDistance: distances.min(),
                        medianReferenceDistance: median(of: distances)
                    ),
                    subjectRegion: animalRecognition.subjectRegion,
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
        #if DEBUG
        print("[TailorRecognition] extractor=\(PetRecognitionVersion.featureExtractorVersion) total=\(assets.count) processed=\(auditMetrics.processed) candidates=\(auditMetrics.candidates) highResolution=\(auditMetrics.highResolutionIdentityImages) lowResolutionFallbacks=\(auditMetrics.identityImageFallbacks)")
        #endif
        return candidates.sorted { $0.confidence > $1.confidence }
    }

    func deleteLocalIndex(profileID: UUID) async {
        PetFeaturePrintIndex.delete(profileID: profileID)
    }

    private func featurePrints(for assets: PHFetchResult<PHAsset>, species: PetSpecies, index: PetFeaturePrintIndex) async throws -> [VNFeaturePrintObservation] {
        var prints: [VNFeaturePrintObservation] = []
        for assetIndex in 0..<assets.count {
            let asset = assets.object(at: assetIndex)
            if let cached = await index.observation(for: asset.localIdentifier) {
                prints.append(cached)
                continue
            }
            guard let speciesImage = try? await image(for: asset) else { continue }
            // References normally use the same detect → crop → feature-print
            // flow as candidates. Unlike candidates, however, a reference is
            // an explicit user choice: a false negative from the lightweight
            // animal detector must not silently reduce a valid 3-photo
            // selection below the minimum and block the scan at 0%.
            //
            // Fall back only for these user-selected references when the
            // detector cannot locate the requested species. The fallback is
            // intentionally not used for library candidates, so it cannot
            // introduce people or other animals into review results.
            let referenceImage: CGImage
            let identityImage = (try? await image(for: asset, targetSize: ScanImageResolution.identityFeature, highQuality: true)) ?? speciesImage
            if let recognition = try? animalRecognition(in: speciesImage, species: species),
               recognition.confidence > 0 {
                referenceImage = VisionFocalRegionDetector.croppedToAnimal(identityImage, region: recognition.subjectRegion)
            } else {
                referenceImage = identityImage
            }
            guard let print = try? featurePrint(for: referenceImage) else { continue }
            await index.store(print, for: asset.localIdentifier)
            prints.append(print)
        }
        await index.flush()
        return prints
    }

    private func image(
        for asset: PHAsset,
        targetSize: CGSize = ScanImageResolution.speciesGate,
        highQuality: Bool = false
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = highQuality ? .highQualityFormat : .fastFormat
            options.resizeMode = highQuality ? .exact : .fast
            // A user-selected reference can be iCloud-only. This downloads that
            // asset to the phone for on-device processing; nothing is uploaded.
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
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

    private func animalRecognition(in image: CGImage, species: PetSpecies) throws -> VisionAnimalRecognitionResult {
        try VisionFocalRegionDetector.animalRecognition(in: image, preferredSpecies: species)
    }

    private func featurePrint(for image: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let observation = request.results?.first else { throw ScanFailure.unavailable }
        return observation
    }

    private func distancesToReferences(_ candidate: VNFeaturePrintObservation?, references: [VNFeaturePrintObservation]) throws -> [Double] {
        guard !references.isEmpty else { throw ScanFailure.insufficientReferences }
        guard let candidate else { return [] }
        return try references.map { reference in
            var distance: Float = 0
            try candidate.computeDistance(&distance, to: reference)
            return Double(distance)
        }
    }

    /// Compatibility mapping for the existing review buckets. The raw distance
    /// is persisted above for later calibration; this value is not treated as a
    /// probability and will be replaced by calibrated multi-reference rules.
    private func similarity(from distance: Double) -> Double {
        max(0, min(1, 1 - distance / 20))
    }

    private func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) { return (sorted[middle - 1] + sorted[middle]) / 2 }
        return sorted[middle]
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

private struct FeatureEmbeddingIndexSnapshot: Codable {
    var schemaVersion: Int
    var vectorsByVersionedAssetKey: [String: Data]
}

/// Local feature-print cache keyed only by asset + extractor version. Pet
/// identity belongs to match generations, not reusable embeddings. The public
/// profileID initializer is retained so old call sites and on-disk indexes can
/// migrate without a destructive release.
actor PetFeaturePrintIndex {
    private let fileURL: URL
    private let legacyFileURL: URL
    private var vectors: [String: Data] = [:]
    private var loaded = false

    init(profileID: UUID, baseDirectory: URL = .applicationSupportDirectory) {
        fileURL = Self.fileURL(profileID: profileID, baseDirectory: baseDirectory)
        legacyFileURL = Self.legacyFileURL(profileID: profileID, baseDirectory: baseDirectory)
    }

    static func fileURL(profileID: UUID, baseDirectory: URL = .applicationSupportDirectory) -> URL {
        // profileID is deliberately ignored in v2.2. Keeping it in the method
        // signature avoids breaking callers while the cache becomes reusable.
        baseDirectory.appending(path: "Tailor/feature-index-v2.json")
    }

    private static func legacyFileURL(profileID: UUID, baseDirectory: URL) -> URL {
        baseDirectory.appending(path: "Tailor/feature-index-\(profileID.uuidString).json")
    }

    static func delete(profileID: UUID, baseDirectory: URL = .applicationSupportDirectory) {
        try? FileManager.default.removeItem(at: fileURL(profileID: profileID, baseDirectory: baseDirectory))
        try? FileManager.default.removeItem(at: legacyFileURL(profileID: profileID, baseDirectory: baseDirectory))
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: fileURL) {
            if let snapshot = try? decoder.decode(FeatureEmbeddingIndexSnapshot.self, from: data) {
                vectors = snapshot.vectorsByVersionedAssetKey
                return
            }
            // A short-lived development build may have written the legacy
            // dictionary at the shared path. Accept and version it once.
            if let legacy = try? decoder.decode([String: Data].self, from: data) {
                vectors = Self.versioned(legacy)
                return
            }
        }
        guard let data = try? Data(contentsOf: legacyFileURL),
              let legacy = try? decoder.decode([String: Data].self, from: data) else { return }
        vectors = Self.versioned(legacy)
    }

    func observation(for identifier: String, featureExtractorVersion: String = PetRecognitionVersion.featureExtractorVersion) -> VNFeaturePrintObservation? {
        guard let data = vectors[FeatureEmbeddingKey(assetID: identifier, featureExtractorVersion: featureExtractorVersion).storageKey] else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }

    func store(_ observation: VNFeaturePrintObservation, for identifier: String, featureExtractorVersion: String = PetRecognitionVersion.featureExtractorVersion) {
        let key = FeatureEmbeddingKey(assetID: identifier, featureExtractorVersion: featureExtractorVersion).storageKey
        vectors[key] = try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    // Internal for file-contract tests; production calls the Vision overload.
    func storeSerializedFeatureData(_ data: Data, for identifier: String, featureExtractorVersion: String = PetRecognitionVersion.featureExtractorVersion) {
        vectors[FeatureEmbeddingKey(assetID: identifier, featureExtractorVersion: featureExtractorVersion).storageKey] = data
    }

    func serializedFeatureData(for identifier: String, featureExtractorVersion: String = PetRecognitionVersion.featureExtractorVersion) -> Data? {
        vectors[FeatureEmbeddingKey(assetID: identifier, featureExtractorVersion: featureExtractorVersion).storageKey]
    }

    func flush() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = FeatureEmbeddingIndexSnapshot(schemaVersion: 2, vectorsByVersionedAssetKey: vectors)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func versioned(_ legacy: [String: Data]) -> [String: Data] {
        Dictionary(uniqueKeysWithValues: legacy.map {
            (FeatureEmbeddingKey(assetID: $0.key).storageKey, $0.value)
        })
    }
}
