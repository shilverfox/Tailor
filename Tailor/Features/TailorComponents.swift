import SwiftUI
import UIKit
import Photos

/// The single production rule for whether a stored Photos identifier can still
/// be used. A selected ArchivePhoto is not proof that the user retained access.
enum PhotoAssetAvailability {
    static func isAvailable(_ photo: ArchivePhoto) -> Bool {
        // UI automation uses deterministic identifiers instead of a developer's
        // Photos library. Production identifiers always resolve through Photos.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTesting"), (photo.assetLocalIdentifier.hasPrefix("ui-") || photo.assetLocalIdentifier.hasPrefix("fixture-photo-")) { return true }
        return PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetLocalIdentifier], options: nil).count == 1
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

/// A small PhotoKit-backed image view used by archive screens. The app stores only the
/// Photos local identifier, never a second copy of the user's image.
struct PhotoAssetThumbnail: View {
    let identifier: String
    var contentMode: ContentMode = .fill
    var treatment: MemoryBookImageTreatment = .original
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
        .task(id: identifier) { requestImage() }
        .onDisappear {
            guard requestID != PHInvalidImageRequestID else { return }
            PHImageManager.default().cancelImageRequest(requestID)
        }
        .accessibilityLabel("Photo from your library")
    }

    private func requestImage() {
        image = nil
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        // UI automation crop fixtures deliberately avoid a user's Photos
        // library. They are deterministic local bitmaps with centre and edge
        // markers, so visual evidence can prove crop/rotation behavior rather
        // than showing the generic missing-photo placeholder.
        guard let asset = fetched.firstObject else {
            if let fixture = localCropFixture(identifier: identifier) { image = fixture }
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
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 480, height: 480),
            contentMode: contentMode == .fit ? .aspectFit : .aspectFill,
            options: options
        ) { result, _ in
            guard let result else { return }
            let rendered = apply(treatment, to: result)
            Task { @MainActor in image = rendered }
        }
    }

    private func apply(_ treatment: MemoryBookImageTreatment, to image: UIImage) -> UIImage {
        guard treatment == .mono, let cgImage = image.cgImage else { return image }
        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIPhotoEffectMono") else { return image }
        filter.setValue(input, forKey: kCIInputImageKey)
        guard let output = filter.outputImage,
              let rendered = CIContext().createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
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
            .rotationEffect(.degrees(geometry.rotationDegrees))
            .frame(width: geometry.container.width, height: geometry.container.height)
            .clipped()
    }
}
