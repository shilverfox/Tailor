import Foundation
import Photos
import UIKit
import Vision

struct PhotoKitVisionScanner: PetScanServicing {
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

        // Publish the real library size before preparing references. Reference assets
        // may need an iCloud download, and the UI must not look frozen during that work.
        await onProgress(ScanCheckpoint(nextAssetIndex: 0, totalAssets: assets.count, candidates: []))
        let referenceAssets = PHAsset.fetchAssets(withLocalIdentifiers: profile.referenceAssetIdentifiers, options: nil)
        let referencePrints = try await featurePrints(for: referenceAssets)

        let canResume = checkpoint?.totalAssets == assets.count
        var candidates = canResume ? (checkpoint?.candidates ?? []) : []
        var seenIdentifiers = Set(candidates.map(\.assetLocalIdentifier))
        let startIndex = canResume ? min(checkpoint?.nextAssetIndex ?? 0, assets.count) : 0
        for index in startIndex..<assets.count {
            guard !Task.isCancelled else { throw ScanFailure.interrupted }
            let asset = assets.object(at: index)
            if !profile.referenceAssetIdentifiers.contains(asset.localIdentifier),
               !seenIdentifiers.contains(asset.localIdentifier),
               let cgImage = try? await image(for: asset),
               let animalConfidence = try? animalConfidence(in: cgImage, species: profile.species),
               animalConfidence > 0 {
                let similarity = (try? similarityToReferences(cgImage, references: referencePrints)) ?? 0
                let confidence = min(0.99, max(0.01, animalConfidence * 0.55 + similarity * 0.45))
                let decision: PhotoDecision = confidence >= 0.84 ? .selected : (confidence >= 0.45 ? .needsReview : .excluded)
                candidates.append(ArchivePhoto(id: UUID(), assetLocalIdentifier: asset.localIdentifier, decision: decision, confidence: confidence, createdAt: asset.creationDate))
                seenIdentifiers.insert(asset.localIdentifier)
            }
            // Publish each asset: long libraries and slow PhotoKit requests must never
            // leave the UI looking stalled while waiting for an arbitrary batch.
            await onProgress(ScanCheckpoint(nextAssetIndex: index + 1, totalAssets: assets.count, candidates: candidates))
        }
        await onProgress(ScanCheckpoint(nextAssetIndex: assets.count, totalAssets: assets.count, candidates: candidates))
        return candidates.sorted { $0.confidence > $1.confidence }
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

    private func similarityToReferences(_ image: CGImage, references: [VNFeaturePrintObservation]) throws -> Double {
        guard !references.isEmpty else { return 0.5 }
        let candidate = try featurePrint(for: image)
        let smallestDistance = try references.reduce(Double.greatestFiniteMagnitude) { smallest, reference in
            var distance: Float = 0
            try candidate.computeDistance(&distance, to: reference)
            return min(smallest, Double(distance))
        }
        return max(0, min(1, 1 - smallestDistance / 20))
    }
}
