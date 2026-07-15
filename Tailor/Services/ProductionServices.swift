import Foundation
import StoreKit
import UIKit
import Photos

enum TailorServiceError: LocalizedError {
    case productUnavailable
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .productUnavailable: "The Tailor unlock is not available right now."
        case .unverifiedTransaction: "We could not verify this purchase."
        }
    }
}

actor StoreKitPurchaseService: PurchaseServicing {
    private let productIdentifier = "tailor.life_archive.unlock"

    func purchaseUnlock() async throws -> PurchaseState {
        guard let product = try await Product.products(for: [productIdentifier]).first else {
            throw TailorServiceError.productUnavailable
        }
        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return .entitled
        case .userCancelled: return .cancelled
        case .pending: return .purchasing
        @unknown default: return .failed("Purchase could not be completed.")
        }
    }

    func restorePurchases() async throws -> PurchaseState {
        try await AppStore.sync()
        return await isEntitled() ? .restored : .idle
    }

    func isEntitled() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == productIdentifier && transaction.revocationDate == nil { return true }
        }
        return false
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): value
        case .unverified: throw TailorServiceError.unverifiedTransaction
        }
    }
}

struct LocalPDFExporter: PDFExporting {
    func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL {
        let page = pageSize == .a4 ? CGSize(width: 595, height: 842) : CGSize(width: 612, height: 792)
        let output = URL.documentsDirectory.appending(path: "\(profile.id.uuidString)-life-archive.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: page))
        try renderer.writePDF(to: output) { context in
            context.beginPage()
            let inset: CGFloat = 48
            let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: UIColor(red: 0.08, green: 0.20, blue: 0.16, alpha: 1)]
            let bodyAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.darkGray]
            "\(profile.name)’s Life Archive".draw(in: CGRect(x: inset, y: 88, width: page.width - inset * 2, height: 44), withAttributes: titleAttributes)
            "Made from the photographs you chose. Created privately on this iPhone.".draw(in: CGRect(x: inset, y: 146, width: page.width - inset * 2, height: 36), withAttributes: bodyAttributes)
            let photoLookup = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
            var y: CGFloat = 230
            for chapter in chapters.sorted(by: { $0.sortOrder < $1.sortOrder }) where !chapter.isHidden {
                if y > page.height - 190 { context.beginPage(); y = 64 }
                chapter.dateLabel.draw(in: CGRect(x: inset, y: y, width: page.width - inset * 2, height: 20), withAttributes: bodyAttributes)
                chapter.title.draw(in: CGRect(x: inset, y: y + 24, width: page.width - inset * 2, height: 28), withAttributes: titleAttributes)
                "\(chapter.photoIDs.count) selected photographs".draw(in: CGRect(x: inset, y: y + 60, width: page.width - inset * 2, height: 18), withAttributes: bodyAttributes)
                let chapterPhotos = chapter.photoIDs.compactMap { photoLookup[$0] }.prefix(3)
                var x = inset
                for photo in chapterPhotos {
                    if let image = thumbnail(for: photo.assetLocalIdentifier) {
                        image.draw(in: CGRect(x: x, y: y + 88, width: 150, height: 100))
                        x += 162
                    }
                }
                y += chapterPhotos.isEmpty ? 116 : 210
            }
        }
        return output
    }

    private func thumbnail(for identifier: String) -> UIImage? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        var resultImage: UIImage?
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 500, height: 340), contentMode: .aspectFill, options: options) { image, _ in resultImage = image }
        return resultImage
    }
}
