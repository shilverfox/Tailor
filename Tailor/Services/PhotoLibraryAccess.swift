import Foundation
import Combine
import Photos
import PhotosUI
import UIKit
import CryptoKit
import SwiftUI

@MainActor
final class PhotoLibraryAccess: ObservableObject {
    @Published private(set) var scope: PhotoAccessScope

    init() {
        scope = Self.scope(for: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func refresh() {
        scope = Self.scope(for: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> PhotoAccessScope {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let resolvedScope = Self.scope(for: status)
        scope = resolvedScope
        return resolvedScope
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Resolves private manual copies after the user later grants Photos access.
    /// The scan is fingerprint-only and stops once every requested fingerprint
    /// has a PHAsset match; it never invokes the pet matcher or builds an index.
    func fingerprintMappings(for fingerprints: Set<String>) async -> [String: String] {
        guard !fingerprints.isEmpty, scope == .full || scope == .limited else { return [:] }
        let assets = PHAsset.fetchAssets(with: .image, options: nil)
        var remaining = fingerprints
        var mappings: [String: String] = [:]
        var index = 0
        while index < assets.count, !remaining.isEmpty {
            let asset = assets.object(at: index)
            index += 1
            guard let data = await originalData(for: asset) else { continue }
            let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            if remaining.remove(fingerprint) != nil { mappings[fingerprint] = asset.localIdentifier }
        }
        return mappings
    }

    private func originalData(for asset: PHAsset) async -> Data? {
        guard let resource = PHAssetResource.assetResources(for: asset).first else { return nil }
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            var data = Data()
            PHAssetResourceManager.default().requestData(for: resource, options: options) { chunk in
                data.append(chunk)
            } completionHandler: { error in
                continuation.resume(returning: error == nil ? data : nil)
            }
        }
    }

    private static func scope(for status: PHAuthorizationStatus) -> PhotoAccessScope {
        switch status {
        case .authorized: .full
        case .limited: .limited
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .restricted
        }
    }
}

struct ManualImportResult: Sendable {
    var asset: ManualAssetReference
    var photo: ArchivePhoto
}

/// Owns only files explicitly returned by PHPicker. Manual imports never enter
/// the PhotoKit scanner or its whole-library index.
enum ManualAssetStore {
    static let identifierPrefix = "tailor-manual:"

    static func identifier(for relativePath: String) -> String { identifierPrefix + relativePath }
    static func relativePath(from identifier: String) -> String? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        return String(identifier.dropFirst(identifierPrefix.count))
    }
    static func url(for relativePath: String) -> URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appending(path: relativePath)
    }
    static func image(identifier: String) -> UIImage? {
        guard let relativePath = relativePath(from: identifier) else { return nil }
        return UIImage(contentsOfFile: url(for: relativePath).path)
    }
    static func isAvailable(identifier: String) -> Bool {
        guard let relativePath = relativePath(from: identifier) else { return false }
        return FileManager.default.fileExists(atPath: url(for: relativePath).path)
    }

    static func importItems(_ items: [PhotosPickerItem], profileID: UUID) async throws -> [ManualImportResult] {
        var imported: [ManualImportResult] = []
        let directoryRelativePath = "Documents/ManualImports/\(profileID.uuidString)"
        let directory = url(for: directoryRelativePath)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for item in items {
            try Task.checkCancellation()
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let id = UUID()
            let relativePath = "\(directoryRelativePath)/\(id.uuidString).asset"
            let destination = url(for: relativePath)
            try data.write(to: destination, options: Data.WritingOptions.atomic)
            let asset = ManualAssetReference(id: id, relativePath: relativePath, contentFingerprint: fingerprint)
            let photo = ArchivePhoto(
                id: UUID(),
                assetLocalIdentifier: identifier(for: relativePath),
                decision: .pending,
                confidence: 1,
                createdAt: nil,
                pixelSize: CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale),
                decisionSource: .manualImport,
                manualAssetID: id
            )
            imported.append(.init(asset: asset, photo: photo))
        }
        return imported
    }

    static func deleteCopies(profileID: UUID) throws {
        let directory = url(for: "Documents/ManualImports/\(profileID.uuidString)")
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    /// Authorization-upgrade seam. A caller can provide fingerprint/PHAsset
    /// matches incrementally; mapped copies are removed only after the PHAsset
    /// identifier is durably attached to the archive.
    static func applyingMappings(_ mappings: [String: String], to document: inout ArchiveDocument, deleteCopies: Bool = true) {
        for index in document.manualAssets.indices {
            let fingerprint = document.manualAssets[index].contentFingerprint
            guard let phAssetID = mappings[fingerprint] else { continue }
            let manualID = document.manualAssets[index].id
            let oldIdentifier = identifier(for: document.manualAssets[index].relativePath)
            document.manualAssets[index].resolvedPHAssetIdentifier = phAssetID
            document.manualAssets[index].copyState = .mappedToPhotoLibrary
            if let photoIndex = document.photos.firstIndex(where: { $0.manualAssetID == manualID || $0.assetLocalIdentifier == oldIdentifier }) {
                document.photos[photoIndex].assetLocalIdentifier = phAssetID
                document.photos[photoIndex].manualAssetID = nil
            }
            if deleteCopies { try? FileManager.default.removeItem(at: url(for: document.manualAssets[index].relativePath)) }
        }
        document.updatedAt = .now
    }

    static func deleteMappedCopies(in document: ArchiveDocument) {
        for asset in document.manualAssets where asset.copyState == .mappedToPhotoLibrary {
            try? FileManager.default.removeItem(at: url(for: asset.relativePath))
        }
    }
}
