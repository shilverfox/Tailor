import SwiftUI
import UIKit
import Photos

/// The single production rule for whether a stored Photos identifier can still
/// be used. A selected ArchivePhoto is not proof that the user retained access.
enum PhotoAssetAvailability {
    static func isAvailable(_ photo: ArchivePhoto) -> Bool {
        if ManualAssetStore.isAvailable(identifier: photo.assetLocalIdentifier) { return true }
        // UI automation uses deterministic identifiers instead of a developer's
        // Photos library. Production identifiers always resolve through Photos.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTesting"), (photo.assetLocalIdentifier.hasPrefix("ui-") || photo.assetLocalIdentifier.hasPrefix("fixture-photo-")) { return true }
        return PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetLocalIdentifier], options: nil).count == 1
    }
}

enum PhotoAssetImageLoader {
    static func image(identifier: String, targetSize: CGSize = CGSize(width: 1_200, height: 1_200)) async -> UIImage? {
        if let fixture = MemoryBookVisualQAAsset.image(identifier: identifier) { return fixture }
        if let manual = ManualAssetStore.image(identifier: identifier) { return manual }
        return await Task.detached(priority: .userInitiated) {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            guard let asset = result.firstObject else { return nil }
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true
            options.isSynchronous = true
            var output: UIImage?
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                output = image
            }
            return output
        }.value
    }
}

/// Invalidates active editor and reader pages when Photos permission or assets
/// change. The predicate above remains the sole availability decision.
@MainActor
final class PhotoAssetAvailabilityMonitor: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var revision = 0

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in self.refresh() }
    }

    @objc private func refresh() { revision &+= 1 }
}

/// Loads editorial PNGs as ordinary bundle resources. The asset catalog remains the
/// canonical design source but is intentionally not compiled in this local Xcode setup.
struct EditorialImage: View {
    let name: String
    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Editorial"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable()
        } else {
            ZStack { TailorColor.mist; Image(systemName: "photo").font(.largeTitle).foregroundStyle(TailorColor.ink) }
        }
    }
}

struct TailorScreen<Content: View>: View {
    let eyebrow: String; let title: String; let back: (() -> Void)?; @ViewBuilder var content: Content
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TailorColor.paper.ignoresSafeArea()
                ScrollView {
                    // The editorial screens use a 16pt rhythm between the header,
                    // title, and first content block. Individual content sections
                    // keep their own larger spacing where needed.
                    VStack(alignment: .leading, spacing: TailorSpacing.m) {
                        HStack { if let back { Button(action: back) { Image(systemName: "chevron.left") }.frame(width: TailorSpacing.touchTarget, height: TailorSpacing.touchTarget).accessibilityLabel("Back") }; Spacer(); Text(eyebrow).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(TailorColor.clay) }
                        Text(title)
                            .font(TailorFont.display(36))
                            .foregroundStyle(TailorColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            // UI tests and VoiceOver should receive a natural sentence,
                            // not SwiftUI's visual line-break representation.
                            .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
                        content
                    }
                    .frame(width: max(0, proxy.size.width - (TailorSpacing.l * 2)), alignment: .leading)
                    .padding(.horizontal, TailorSpacing.l)
                    .padding(.top, TailorSpacing.s)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .tint(TailorColor.ink)
        }
    }
}

struct TailorPrimaryButton: View {
    let title: String; var disabled = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 56)
            // The visible, rounded rectangle must also be the complete hit
            // target. Without an explicit content shape, a long review page
            // can occasionally hand a tap to its ScrollView rather than its
            // bottom action after a scroll settles.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(disabled ? TailorColor.ink.opacity(0.35) : TailorColor.ink)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .disabled(disabled)
        .accessibilityLabel(title)
    }
}

/// The visual contract for Tailor's primary action is shared by ordinary
/// buttons and system-provided actions such as ShareLink.  Keeping the label
/// separate means the export completion CTA can invoke the real system share
/// sheet without visually degrading into a secondary text link.
struct TailorPrimaryActionLabel: View {
    let title: String
    var systemImage = "arrow.right"

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: systemImage)
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
        .foregroundStyle(.white)
        .background(TailorColor.ink)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TailorInfoCard: View {
    let symbol: String; let title: String; let message: String; var tint: Color = TailorColor.ink
        var body: some View { HStack(alignment: .top, spacing: TailorSpacing.s) { Image(systemName: symbol).foregroundStyle(tint).frame(width: 28); VStack(alignment: .leading, spacing: 4) { Text(title).font(.callout.weight(.semibold)); Text(message).font(.footnote).foregroundStyle(TailorColor.secondaryInk).fixedSize(horizontal: false, vertical: true) } }.padding(TailorSpacing.m).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.line, lineWidth: 1)) }
}

struct TailorProgressRing: View {
    let progress: Double; let label: String
    var body: some View { ZStack { Circle().stroke(TailorColor.mist, lineWidth: 14); Circle().trim(from: 0, to: max(0.03, progress)).stroke(TailorColor.clay, style: .init(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90)); VStack { Text("\(Int(progress * 100))%").font(.title.weight(.bold)); Text(label).font(.caption) } }.frame(width: 180, height: 180).accessibilityElement(children: .ignore).accessibilityLabel("Scan progress").accessibilityValue("\(Int(progress * 100)) percent") }
}

/// Process-wide thumbnail cache keyed by the same render key the view derives
/// (identifier + treatment + adjustments). Grid cells recycle constantly while
/// a long review list scrolls; without a cache each reappearance cleared the
/// image and issued a fresh PhotoKit request, and the resulting placeholder →
/// image relayout fed the ScrollView's contentSize oscillation. A cache lets a
/// recycled cell paint its final image immediately, with no intermediate state.
private final class ThumbnailImageCache {
    static let shared = ThumbnailImageCache()
    private let store = NSCache<NSString, UIImage>()
    private init() { store.countLimit = 400 }
    func image(for key: String) -> UIImage? { store.object(forKey: key as NSString) }
    func insert(_ image: UIImage, for key: String) { store.setObject(image, forKey: key as NSString) }
}

/// A small PhotoKit-backed image view used by archive screens. The app stores only the
/// Photos local identifier, never a second copy of the user's image.
struct PhotoAssetThumbnail: View {
    let identifier: String
    var contentMode: ContentMode = .fill
    var treatment: MemoryBookImageTreatment = .original
    var adjustments: MemoryBookImageAdjustments = .default
    var background: Color = TailorColor.mist
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    var body: some View {
        ZStack {
            background
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: "photo").font(.title3).foregroundStyle(TailorColor.ink.opacity(0.72))
            }
        }
        .clipped()
        .task(id: renderKey) { requestImage() }
        .onDisappear {
            guard requestID != PHInvalidImageRequestID else { return }
            PHImageManager.default().cancelImageRequest(requestID)
        }
        .accessibilityLabel("Photo from your library")
    }

    private func requestImage() {
        // A recycled cell whose image is already cached paints it immediately,
        // with no placeholder frame and no repeat PhotoKit request — this is
        // what keeps a scrolling grid's contentSize from oscillating.
        if let cached = ThumbnailImageCache.shared.image(for: renderKey) {
            image = cached
            return
        }
        image = nil
        if let manual = ManualAssetStore.image(identifier: identifier) {
            let processed = MemoryBookImageProcessor.process(manual, treatment: treatment, adjustments: adjustments)
            ThumbnailImageCache.shared.insert(processed, for: renderKey)
            image = processed
            return
        }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        // UI automation crop fixtures deliberately avoid a user's Photos
        // library. They are deterministic local bitmaps with centre and edge
        // markers, so visual evidence can prove crop/rotation behavior rather
        // than showing the generic missing-photo placeholder.
        guard let asset = fetched.firstObject else {
            if let fixture = localCropFixture(identifier: identifier) {
                let processed = MemoryBookImageProcessor.process(fixture, treatment: treatment, adjustments: adjustments)
                ThumbnailImageCache.shared.insert(processed, for: renderKey)
                image = processed
            }
            return
        }
        let options = PHImageRequestOptions()
        // A grid cell's geometry is fixed, but repeated degraded/full-quality
        // callbacks still trigger dozens of state mutations while a long
        // review list settles. Request one final thumbnail to keep scrolling
        // deterministic at the bottom of the confirmation screen.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let key = renderKey
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 480, height: 480),
            contentMode: contentMode == .fit ? .aspectFit : .aspectFill,
            options: options
        ) { result, _ in
            guard let result else { return }
            let rendered = MemoryBookImageProcessor.process(result, treatment: treatment, adjustments: adjustments)
            ThumbnailImageCache.shared.insert(rendered, for: key)
            Task { @MainActor in image = rendered }
        }
    }

    private var renderKey: String {
        let a = adjustments
        return "\(identifier)|\(treatment)|\(a.exposure)|\(a.brightness)|\(a.contrast)|\(a.saturation)|\(a.warmth)|\(a.highlights)|\(a.shadows)|\(a.vignette)|\(a.sharpness)"
    }

    private func localCropFixture(identifier: String) -> UIImage? {
        MemoryBookVisualQAAsset.image(identifier: identifier)
    }
}

/// Shared SwiftUI implementation of the memory-book image pipeline.  The
/// order is non-negotiable and mirrors `MemoryBookImageTransformGeometry` in
/// the Core Graphics PDF renderer: destination clip → scale/offset/rotation →
/// source.  Keeping this as a single component prevents Crop, Editor and
/// Reader from quietly acquiring different rotation/crop semantics.
struct MemoryBookImageTransform<Source: View>: View {
    let geometry: MemoryBookImageTransformGeometry
    @ViewBuilder let source: () -> Source

    var body: some View {
        source()
            .frame(width: geometry.container.width, height: geometry.container.height)
            .scaleEffect(geometry.transform.scale)
            .offset(
                x: geometry.transform.offset.width * geometry.container.width,
                y: geometry.transform.offset.height * geometry.container.height
            )
            .scaleEffect(
                x: geometry.flipHorizontal ? -1 : 1,
                y: geometry.flipVertical ? -1 : 1
            )
            .rotationEffect(.degrees(geometry.rotationDegrees))
            .frame(width: geometry.container.width, height: geometry.container.height)
            .clipped()
    }
}
