import Foundation
import StoreKit
import UIKit
import Photos
import AVFoundation
import CoreImage

enum TailorServiceError: LocalizedError {
    case productUnavailable
    case unverifiedTransaction
    case photoUnavailable
    case bookHasBlockingIssues

    var errorDescription: String? {
        switch self {
        case .productUnavailable: "The Tailor unlock is not available right now."
        case .unverifiedTransaction: "We could not verify this purchase."
        case .photoUnavailable: "One or more selected photos are no longer available. Replace them before exporting."
        case .bookHasBlockingIssues: "Fix the blocking Book Check items before exporting."
        }
    }
}

/// Supplies the source bitmap for a Memory Book image element.  Production
/// resolves identifiers through PhotoKit; test and visual-QA fixtures inject
/// deterministic bitmaps instead.  Keeping this boundary at the PDF renderer
/// makes the exported page independently reproducible without weakening the
/// app's on-device Photos policy.
protocol MemoryBookAssetImageProviding: Sendable {
    func isAvailable(identifier: String) -> Bool
    func image(identifier: String, targetSize: CGSize) -> UIImage?
}

/// The production implementation deliberately mirrors the existing local
/// PhotoKit policy: no original-photo copy is persisted and iCloud retrieval
/// is not silently enabled during export.
struct PhotoKitMemoryBookAssetImageProvider: MemoryBookAssetImageProviding {
    func isAvailable(identifier: String) -> Bool {
        if ManualAssetStore.isAvailable(identifier: identifier) { return true }
        return PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).count == 1
    }

    func image(identifier: String, targetSize: CGSize) -> UIImage? {
        if let manual = ManualAssetStore.image(identifier: identifier) { return manual }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        var resultImage: UIImage?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in resultImage = image }
        return resultImage
    }
}

actor StoreKitPurchaseService: PurchaseServicing {
    static let unlockProductIdentifier = "tailor.life_archive.unlock"
    private let productIdentifier = StoreKitPurchaseService.unlockProductIdentifier
    private let transactionUpdates: Task<Void, Never>

    init() {
        let productIdentifier = Self.unlockProductIdentifier
        // Purchases can complete outside the immediate purchase sheet (such
        // as Ask to Buy approval). Finish only verified transactions.
        transactionUpdates = Task.detached(priority: .background) {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result,
                      transaction.productID == productIdentifier else { continue }
                await transaction.finish()
            }
        }
    }

    deinit {
        transactionUpdates.cancel()
    }

    func unlockDisplayPrice() async -> String? {
        try? await Product.products(for: [productIdentifier]).first?.displayPrice
    }

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
        case .pending: return .pending
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
    private let outputDirectory: URL
    private let imageProvider: any MemoryBookAssetImageProviding
    private let imageTargetSizeOverride: CGSize?

    init(
        outputDirectory: URL = .documentsDirectory,
        imageProvider: any MemoryBookAssetImageProviding = PhotoKitMemoryBookAssetImageProvider(),
        imageTargetSize: CGSize? = nil
    ) {
        self.outputDirectory = outputDirectory
        self.imageProvider = imageProvider
        self.imageTargetSizeOverride = imageTargetSize
    }

    func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL {
        let document = MemoryBookBuilder.build(profile: profile, photos: photos, chapters: chapters, style: profile.albumStyle, pageSize: pageSize)
        return try await export(document: document)
    }

    func export(document book: MemoryBookDocument) async throws -> URL {
        try await export(document: book, watermarked: false, progress: { _, _ in })
    }

    func export(document book: MemoryBookDocument, progress: @escaping @Sendable (Int, Int) -> Void) async throws -> URL {
        try await export(document: book, watermarked: false, progress: progress)
    }

    /// The renderer accepts the exact same free-sample state as SwiftUI. Product
    /// flow uses `false` for a paid PDF; the explicit argument keeps snapshot
    /// tests from relying on an untestable UI-only watermark.
    func export(document book: MemoryBookDocument, watermarked: Bool, progress: @escaping @Sendable (Int, Int) -> Void) async throws -> URL {
        // The editor's menu check is useful feedback, but it is not a security
        // or data-integrity boundary. Direct callers must receive the same
        // rejection before an output URL is allocated or a PDF is written.
        guard !book.checkBook(assetIsAvailable: { imageProvider.isAvailable(identifier: $0.assetLocalIdentifier) }).contains(where: { $0.severity == .blocking }) else {
            throw TailorServiceError.bookHasBlockingIssues
        }
        let snapshot = book.exportSnapshot(watermarked: watermarked)
        let frozenBook = snapshot.document
        // Do not silently leave holes in a paid keepsake. Review eligibility is
        // not enough: the asset can have been deleted from Photos or access can
        // have been narrowed since the user last edited the page.
        let eligible = Dictionary(uniqueKeysWithValues: frozenBook.photos.filter(\.isEligibleForArchive).map { ($0.id, $0) })
        let photoIDs = frozenBook.pages.flatMap(\.elements).filter { $0.kind == .image }.compactMap(\.assetID)
        guard photoIDs.allSatisfy({ id in
            guard let photo = eligible[id] else { return false }
            return imageProvider.isAvailable(identifier: photo.assetLocalIdentifier)
        }) else { throw TailorServiceError.photoUnavailable }

        let page = MemoryBookPageRenderPlan.points(for: frozenBook.pageSize)
        let renderPlans = snapshot.manifest.plans
        // Exports are keepsakes in their own right. Never overwrite a previous
        // version merely because the owner made another edit and exported again.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = String(UUID().uuidString.prefix(8))
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let output = outputDirectory.appending(path: "\(frozenBook.profile.id.uuidString)-life-archive-\(formatter.string(from: .now))-\(suffix).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: page))
        var wasCancelled = false
        var imageUnavailable = false
        try renderer.writePDF(to: output) { context in
            // A document can contain stale chapter IDs after a later review decision.
            // Filter again at the final rendering boundary so sensitive and never-use
            // assets can never be written into a PDF.
            let photoLookup = eligible
            for (index, plan) in renderPlans.enumerated() {
                if Task.isCancelled { wasCancelled = true; break }
                context.beginPage()
                // Explicitly paint both surfaces. Leaving the PDF page transparent
                // caused black pages in some viewers and made preview/export differ.
                color(plan.style.backdrop).setFill(); UIBezierPath(rect: plan.pageRect).fill()
                color(plan.paperColor).setFill(); UIBezierPath(roundedRect: plan.paperRect, cornerRadius: 4).fill()
                // Use the exact PageStyle descriptor consumed by the SwiftUI
                // canvas.  A missing bundled asset deliberately leaves the
                // solid paper fallback in place; it must not produce a
                // renderer-specific substitute background.
                if let texture = plan.style.texture,
                   let textureImage = UIImage(named: texture.assetName) {
                    textureImage.draw(in: plan.paperRect, blendMode: .normal, alpha: texture.opacity)
                }
                // The normalized element frame is the document contract. It is
                // mapped to the same paper rectangle that the SwiftUI canvas
                // displays, rather than to a second, hidden inner layout.
                for element in plan.orderedElements {
                    let rect = plan.rect(for: element.normalizedFrame)
                    switch element.kind {
                    case .text:
                        // The same TextLayoutSpec/paragraph contract used for
                        // Preview and Book Check.  This avoids a PDF-only word
                        // wrapping rule that could make the exported keepsake
                        // overflow despite an editor that looked valid.
                        if let textLayout = plan.textLayout(for: element) {
                            let fallback = plan.fontToken(for: element) == .display ? plan.style.ink : plan.style.secondary
                            let textColor = color(element.textCustomColor ?? element.textColor.rgb(fallback: fallback))
                            context.cgContext.saveGState()
                            context.cgContext.translateBy(x: rect.midX, y: rect.midY)
                            context.cgContext.rotate(by: CGFloat(element.rotationDegrees * .pi / 180))
                            context.cgContext.translateBy(x: -rect.midX, y: -rect.midY)
                            MemoryBookTextRenderer.draw(
                                snapshot: textLayout,
                                color: textColor,
                                in: rect,
                                context: context.cgContext
                            )
                            context.cgContext.restoreGState()
                        }
                    case .shape:
                        drawShape(
                            in: rect,
                            element: element,
                            fallbackFill: plan.style.accent,
                            paperWidth: plan.paperRect.width,
                            context: context.cgContext
                        )
                    case .image:
                        guard let photoID = element.assetID,
                              let photo = photoLookup[photoID],
                              let image = imageProvider.image(
                                identifier: photo.assetLocalIdentifier,
                                targetSize: imageTargetSizeOverride ?? Self.printTargetSize(
                                    for: rect,
                                    photo: photo,
                                    element: element
                                )
                              )
                        else {
                            // A Photos asset can remain addressable while its
                            // local bitmap is unavailable.  Never finish a
                            // paid PDF with a silent blank frame.
                            imageUnavailable = true
                            break
                        }
                        draw(image: MemoryBookImageProcessor.process(image, treatment: plan.style.imageTreatment, adjustments: element.imageAdjustments), in: rect, element: element, paperWidth: plan.paperRect.width, context: context.cgContext)
                        if let borderRect = plan.filmImageBorderRect(in: rect),
                           let lineWidth = plan.filmImageBorderLineWidth(),
                           let cornerRadius = plan.filmImageBorderCornerRadius() {
                            color(plan.style.accent).setStroke()
                            let border = UIBezierPath(roundedRect: borderRect, cornerRadius: cornerRadius)
                            border.lineWidth = lineWidth
                            border.stroke()
                        }
                    }
                    if imageUnavailable { break }
                }
                if imageUnavailable { break }
                if let frame = plan.filmFrameRect(),
                   let lineWidth = plan.filmFrameLineWidth(),
                   let dash = plan.filmFrameDash(),
                   let cornerRadius = plan.filmFrameCornerRadius() {
                    let cg = context.cgContext
                    cg.saveGState()
                    cg.setStrokeColor(color(plan.style.accent).cgColor)
                    cg.setLineWidth(lineWidth)
                    cg.setLineDash(phase: 0, lengths: dash)
                    cg.addPath(UIBezierPath(roundedRect: frame, cornerRadius: cornerRadius).cgPath)
                    cg.strokePath()
                    cg.restoreGState()
                }
                drawWatermark(plan: plan, context: context.cgContext)
                progress(index + 1, renderPlans.count)
            }
        }
        if wasCancelled || imageUnavailable {
            try? FileManager.default.removeItem(at: output)
            if wasCancelled { throw CancellationError() }
            throw TailorServiceError.photoUnavailable
        }
        return output
    }

    /// Requests enough source pixels for the element's actual 300-DPI printed
    /// footprint, including aspect-fill excess and committed crop zoom. The
    /// request is reduced proportionally when the original has fewer pixels;
    /// the exporter never invents detail by asking PhotoKit to upscale it.
    static func printTargetSize(
        for container: CGRect,
        photo: ArchivePhoto,
        element: MemoryBookElement,
        dpi: CGFloat = 300
    ) -> CGSize {
        let drawn = MemoryBookPrintQuality.drawnSizeInPoints(container: container, photo: photo, element: element)
        let pixelScale = max(1, dpi) / 72
        var target = CGSize(width: drawn.width * pixelScale, height: drawn.height * pixelScale)
        if let source = photo.pixelSize, source.width > 0, source.height > 0 {
            let reduction = min(1, source.width / max(1, target.width), source.height / max(1, target.height))
            target.width *= reduction
            target.height *= reduction
        }
        return CGSize(width: max(1, ceil(target.width)), height: max(1, ceil(target.height)))
    }

    private func color(_ rgb: MemoryBookRGB) -> UIColor { UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1) }

    private func drawWatermark(plan: MemoryBookPageRenderPlan, context: CGContext) {
        guard let watermark = plan.watermark,
              let fontSize = plan.watermarkFontSize(),
              let letterSpacing = plan.watermarkLetterSpacing() else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color(plan.style.accent).withAlphaComponent(watermark.opacity),
            .kern: letterSpacing
        ]
        for center in plan.watermarkCenters() {
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(watermark.rotationDegrees * .pi / 180))
            let size = (watermark.text as NSString).size(withAttributes: attributes)
            (watermark.text as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
            context.restoreGState()
        }
    }

    private func draw(image: UIImage, in container: CGRect, element: MemoryBookElement, paperWidth: CGFloat, context: CGContext) {
        guard let cgImage = image.cgImage else { return }
        context.saveGState()
        // Rotate the image element first, then clip and draw inside its local
        // bounds. This matches the editor: the photo frame rotates as a whole
        // rather than turning pixels inside an unrotated rectangle.
        context.translateBy(x: container.midX, y: container.midY)
        context.rotate(by: CGFloat(element.rotationDegrees * .pi / 180))
        context.translateBy(x: -container.midX, y: -container.midY)
        let cornerRadius = element.appearance.cornerRadiusRatio * paperWidth
        let maskPath = elementMaskPath(element.appearance.mask, rect: container, cornerRadius: cornerRadius)
        context.setAlpha(element.appearance.opacity)
        context.setShadow(
            offset: CGSize(
                width: element.appearance.shadowOffset.width * paperWidth,
                height: element.appearance.shadowOffset.height * paperWidth
            ),
            blur: element.appearance.shadowBlurRatio * paperWidth,
            color: UIColor.black.withAlphaComponent(element.appearance.shadowOpacity).cgColor
        )
        // Composite the clipped image and its border as one layer so opacity
        // and shadow match the SwiftUI element rather than affecting pixels
        // inside the crop independently.
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.saveGState()
        context.addPath(maskPath.cgPath)
        context.clip()
        var contentElement = element
        contentElement.rotationDegrees = 0
        let geometry = MemoryBookImageTransformGeometry(
            container: container,
            sourceAspect: CGFloat(cgImage.width) / max(1, CGFloat(cgImage.height)),
            element: contentElement
        )
        context.translateBy(x: container.midX, y: container.midY)
        context.rotate(by: CGFloat(geometry.rotationDegrees * .pi / 180))
        context.scaleBy(x: geometry.flipHorizontal ? -1 : 1, y: geometry.flipVertical ? -1 : 1)
        context.translateBy(x: -container.midX, y: -container.midY)
        image.draw(in: geometry.sourceRect(sourcePixelSize: CGSize(width: cgImage.width, height: cgImage.height)))
        context.restoreGState()
        if element.appearance.borderStyle != .none {
            context.setStrokeColor(color(element.appearance.borderColor).cgColor)
            context.setLineWidth(element.appearance.borderWidthRatio * paperWidth)
            context.setLineDash(phase: 0, lengths: element.appearance.borderStyle == .dashed ? [6 / 612 * paperWidth, 4 / 612 * paperWidth] : [])
            context.addPath(maskPath.cgPath)
            context.strokePath()
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private func drawShape(
        in container: CGRect,
        element: MemoryBookElement,
        fallbackFill: MemoryBookRGB,
        paperWidth: CGFloat,
        context: CGContext
    ) {
        context.saveGState()
        context.translateBy(x: container.midX, y: container.midY)
        context.rotate(by: CGFloat(element.rotationDegrees * .pi / 180))
        context.translateBy(x: -container.midX, y: -container.midY)
        let cornerRadius = element.appearance.cornerRadiusRatio * paperWidth
        let maskPath = elementMaskPath(element.appearance.mask, rect: container, cornerRadius: cornerRadius)
        context.setAlpha(element.appearance.opacity)
        context.setShadow(
            offset: CGSize(
                width: element.appearance.shadowOffset.width * paperWidth,
                height: element.appearance.shadowOffset.height * paperWidth
            ),
            blur: element.appearance.shadowBlurRatio * paperWidth,
            color: UIColor.black.withAlphaComponent(element.appearance.shadowOpacity).cgColor
        )
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setFillColor(color(element.appearance.fillColor ?? fallbackFill).cgColor)
        context.addPath(maskPath.cgPath)
        context.fillPath()
        if element.appearance.borderStyle != .none {
            context.setStrokeColor(color(element.appearance.borderColor).cgColor)
            context.setLineWidth(element.appearance.borderWidthRatio * paperWidth)
            context.setLineDash(
                phase: 0,
                lengths: element.appearance.borderStyle == .dashed
                    ? [6 / 612 * paperWidth, 4 / 612 * paperWidth]
                    : []
            )
            context.addPath(maskPath.cgPath)
            context.strokePath()
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private func elementMaskPath(_ mask: MemoryBookElementMask, rect: CGRect, cornerRadius: CGFloat) -> UIBezierPath {
        switch mask {
        case .rectangle:
            UIBezierPath(rect: rect)
        case .roundedRectangle:
            UIBezierPath(roundedRect: rect, cornerRadius: min(cornerRadius, min(rect.width, rect.height) / 2))
        case .ellipse:
            UIBezierPath(ovalIn: rect)
        }
    }

}

struct LocalVideoExporter: VideoExporting {
    func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], duration: TimeInterval = 30) async throws -> URL {
        let eligible = photos.filter(\.isEligibleForArchive).sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        guard !eligible.isEmpty else { throw TailorServiceError.productUnavailable }
        let output = URL.documentsDirectory.appending(path: "\(profile.id.uuidString)-life-archive.mp4")
        try? FileManager.default.removeItem(at: output)
        let size = CGSize(width: 1080, height: 1920)
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size.width, AVVideoHeightKey: size.height])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: size.width, kCVPixelBufferHeightKey as String: size.height])
        writer.add(input)
        writer.startWriting(); writer.startSession(atSourceTime: .zero)
        let frameDuration = CMTime(seconds: max(0.5, duration / Double(eligible.count)), preferredTimescale: 600)
        for (index, photo) in eligible.enumerated() {
            guard let image = thumbnail(for: photo.assetLocalIdentifier), let buffer = makeBuffer(image: image, size: size) else { continue }
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            adaptor.append(buffer, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(index)))
        }
        input.markAsFinished()
        await withCheckedContinuation { continuation in writer.finishWriting { continuation.resume() } }
        guard writer.status == .completed else { throw writer.error ?? TailorServiceError.productUnavailable }
        return output
    }

    private func thumbnail(for identifier: String) -> UIImage? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return nil }
        let options = PHImageRequestOptions(); options.deliveryMode = .highQualityFormat; options.resizeMode = .fast; options.isSynchronous = true; options.isNetworkAccessAllowed = false
        var image: UIImage?
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1080, height: 1920), contentMode: .aspectFit, options: options) { result, _ in image = result }
        return image
    }

    private func makeBuffer(image: UIImage, size: CGSize) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &buffer)
        guard let buffer, let cgImage = image.cgImage else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let context = CGContext(data: base, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        context?.setFillColor(UIColor.black.cgColor); context?.fill(CGRect(origin: .zero, size: size))
        let scale = min(size.width / CGFloat(cgImage.width), size.height / CGFloat(cgImage.height))
        let rect = CGRect(x: (size.width - CGFloat(cgImage.width) * scale) / 2, y: (size.height - CGFloat(cgImage.height) * scale) / 2, width: CGFloat(cgImage.width) * scale, height: CGFloat(cgImage.height) * scale)
        context?.draw(cgImage, in: rect)
        return buffer
    }
}
