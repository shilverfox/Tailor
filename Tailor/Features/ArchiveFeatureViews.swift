import SwiftUI
import PhotosUI
import UIKit

struct ReferencesFeatureView: View {
    @Binding var referenceAssetIdentifiers: [String]
    let next: () -> Void
    let back: () -> Void
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var thumbnails: [UIImage] = []

    private var count: Int { referenceAssetIdentifiers.count }

    var body: some View { TailorScreen(eyebrow: "REFERENCE PHOTOS", title: "Help us recognize them.", back: back) {
        Text("Choose 3–5 clear photos from different ages and angles.")
        ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(0..<5, id: \.self) { index in
            RoundedRectangle(cornerRadius: 20)
                .fill(index < count ? TailorColor.mist : .white)
                .frame(width: 116, height: 155)
                .overlay {
                    if index < thumbnails.count {
                        Image(uiImage: thumbnails[index]).resizable().scaledToFill().frame(width: 116, height: 155).clipped()
                    } else {
                        Image(systemName: index < count ? "photo" : "plus").font(.title).foregroundStyle(TailorColor.ink)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(alignment: .topTrailing) { if index < count { Button { remove(index) } label: { Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.white, TailorColor.ink).font(.title3) }.padding(6).accessibilityLabel("Remove reference photo \(index + 1)") } }
        } } }
        Text(count >= 3 ? "\(count) of 3 minimum selected" : "\(3 - count) more needed").font(.footnote)
        TailorInfoCard(symbol: "lightbulb", title: "A helpful mix", message: "One close-up, one full-body image, and photos from different years make matching more reliable.")
        PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images, photoLibrary: .shared()) {
            Label(count == 0 ? "Choose reference photos" : "Change selected photos", systemImage: "photo.on.rectangle.angled")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .foregroundStyle(TailorColor.clay)
        .onChange(of: pickerItems) { _, newItems in
            Task { await updateSelection(from: newItems) }
        }
        Spacer(minLength: 80)
    }.safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Start looking", disabled: count < 3, action: next).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }

    @MainActor
    private func updateSelection(from items: [PhotosPickerItem]) async {
        let fallbackIdentifiers = items.indices.map { "photos-picker-\($0)-\(UUID().uuidString)" }
        referenceAssetIdentifiers = zip(items, fallbackIdentifiers).map { item, fallback in item.itemIdentifier ?? fallback }
        thumbnails = await withTaskGroup(of: UIImage?.self) { group in
            for item in items {
                group.addTask {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
                    return UIImage(data: data)
                }
            }
            var images: [UIImage] = []
            for await image in group { if let image { images.append(image) } }
            return images
        }
    }
    private func remove(_ index: Int) { guard referenceAssetIdentifiers.indices.contains(index) else { return }; referenceAssetIdentifiers.remove(at: index); if thumbnails.indices.contains(index) { thumbnails.remove(at: index) } }
}

struct ScanFeatureView: View {
    @Binding var progress: Double; let completedAssets: Int; let totalAssets: Int; let matchCount: Int; @Binding var paused: Bool; let isScanning: Bool; let errorMessage: String?; let start: () -> Void; let pause: () -> Void; let next: () -> Void; let back: () -> Void
    var body: some View { ZStack { TailorColor.ink.ignoresSafeArea(); VStack(alignment: .leading, spacing: 24) { HStack { Button(action: back) { Image(systemName: "chevron.left") }.frame(width: 48, height: 48); Spacer(); Text("ON-DEVICE SCAN").font(.caption.weight(.bold)).tracking(1.2) }.foregroundStyle(.white)
        Text("Looking through the moments.").font(.largeTitle).foregroundStyle(.white)
        Spacer(); TailorProgressRing(progress: progress, label: paused ? "Paused" : "Checking").foregroundStyle(.white).frame(maxWidth: .infinity)
        Text(errorMessage ?? (paused ? "Scan paused at \(Int(progress * 100))%. Your progress is saved." : (progress >= 1 ? "Matches ready for your review." : (totalAssets > 0 && completedAssets == 0 ? "Preparing your reference photos on this iPhone." : "Checking \(totalAssets) photos safely on this device.")))).foregroundStyle(.white.opacity(0.82)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        HStack(spacing: 8) { ForEach(0..<4, id: \.self) { index in RoundedRectangle(cornerRadius: 8).fill(index == 1 ? TailorColor.clay.opacity(0.8) : TailorColor.mist).frame(width: 38, height: 38) } }.frame(maxWidth: .infinity)
        TailorInfoCard(symbol: "photo.on.rectangle", title: "\(completedAssets) photos checked", message: "\(matchCount) likely matches so far", tint: TailorColor.clay)
        Spacer()
        Text("Processed on this iPhone. Your photos are not uploaded.").font(.footnote).foregroundStyle(.white.opacity(0.72)).frame(maxWidth: .infinity)
    }.padding(24) }.safeAreaInset(edge: .bottom) { Button { if isScanning { pause() } else if progress >= 1 { next() } else { start() } } label: { HStack { Text(isScanning ? "Pause scan" : (progress >= 1 ? "Review photos" : "Start on-device scan")); Spacer(); Image(systemName: isScanning ? "pause.fill" : "arrow.right") }.font(.callout.weight(.bold)).padding(.horizontal, 18).frame(height: 56).background(TailorColor.paper).foregroundStyle(TailorColor.ink).clipShape(RoundedRectangle(cornerRadius: 16)) }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.ink) } }
}

struct ReviewFeatureView: View {
    let name: String; @Binding var photos: [ArchivePhoto]; let next: () -> Void; let back: () -> Void
    @State private var segment = 0
    private var filtered: [ArchivePhoto] { photos.filter { segment == 0 ? $0.decision == .selected : (segment == 1 ? $0.decision == .needsReview : $0.decision == .excluded) } }
    var body: some View { TailorScreen(eyebrow: "REVIEW", title: "We found \(photos.count) moments.", back: back) {
        HStack { ForEach(0..<3, id: \.self) { index in Button { segment = index } label: { Text(index == 0 ? "HIGH · \(photos.filter { $0.decision == .selected }.count)" : (index == 1 ? "NEEDS REVIEW · \(photos.filter { $0.decision == .needsReview }.count)" : "EXCLUDED · \(photos.filter { $0.decision == .excluded }.count)")).font(.caption.weight(.bold)).foregroundStyle(segment == index ? TailorColor.clay : TailorColor.ink).lineLimit(1).minimumScaleFactor(0.7) }.buttonStyle(.plain) } }
        Divider(); Button { } label: { Label("All years", systemImage: "line.3.horizontal.decrease.circle").font(.footnote.weight(.semibold)) }.foregroundStyle(TailorColor.ink)
        if filtered.isEmpty { TailorInfoCard(symbol: "photo", title: "No photos in this group", message: "Go back and add reference photos, or choose another confidence group.") }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) { ForEach(filtered) { photo in Button { toggle(photo) } label: { RoundedRectangle(cornerRadius: 12).fill(TailorColor.mist).aspectRatio(1, contentMode: .fit).overlay(VStack { Image(systemName: "photo"); Image(systemName: photo.decision == .selected ? "checkmark.circle.fill" : "xmark.circle"); Text("\(Int(photo.confidence * 100))% ").font(.caption2) }.foregroundStyle(TailorColor.ink)) }.accessibilityLabel("Photo confidence \(Int(photo.confidence * 100)) percent") } }
        TailorInfoCard(symbol: "checkmark.circle", title: "Needs your confirmation", message: "Nothing uncertain enters the archive automatically.")
    }.safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Create timeline", disabled: !photos.contains(where: { $0.decision == .selected }), action: next).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }
    private func toggle(_ photo: ArchivePhoto) { guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }; photos[index].decision = photos[index].decision == .selected ? .excluded : .selected }
}

struct TimelineFeatureView: View {
    let name: String; @Binding var chapters: [Chapter]; let edit: () -> Void; let next: () -> Void; let back: () -> Void
    var body: some View { TailorScreen(eyebrow: "TIMELINE", title: "\(name)’s life, in moments.", back: back) {
        Text("Made from the photos you chose. Change every chapter.").foregroundStyle(TailorColor.ink.opacity(0.72))
        VStack(alignment: .leading, spacing: 0) { ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
            HStack(alignment: .top, spacing: 14) { VStack(spacing: 0) { Circle().fill(TailorColor.clay).frame(width: 10, height: 10); Rectangle().fill(TailorColor.mist).frame(width: 2).frame(maxHeight: .infinity).padding(.top, 4) }.frame(width: 20)
                VStack(alignment: .leading, spacing: 6) { Text(chapter.dateLabel).font(.caption.weight(.bold)).foregroundStyle(TailorColor.clay); Button(action: edit) { HStack(spacing: 12) { RoundedRectangle(cornerRadius: 12).fill(index == 1 ? TailorColor.clay.opacity(0.65) : TailorColor.mist).frame(width: 58, height: 58); VStack(alignment: .leading, spacing: 3) { Text(chapter.title).font(.callout.weight(.bold)).foregroundStyle(TailorColor.ink); Text("\(chapter.photoIDs.count) selected photos").font(.footnote).foregroundStyle(TailorColor.ink.opacity(0.68)) }; Spacer(); Image(systemName: chapter.isHidden ? "eye.slash" : "chevron.right").foregroundStyle(TailorColor.ink) }.padding(14).background(Color.white.opacity(0.72)).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.mist, lineWidth: 1)) }.buttonStyle(.plain) }.padding(.bottom, index == chapters.count - 1 ? 0 : 18) }
        } }
        Text("When dates do not establish a story, use neutral titles such as “2018–2020” or “Days together.”").font(.caption).foregroundStyle(TailorColor.ink.opacity(0.65)).padding(.top, 6)
    }.safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Preview album", action: next).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }
}
struct ChapterEditorFeatureView: View {
    @Binding var chapters: [Chapter]; let next: () -> Void; let back: () -> Void
    var body: some View { TailorScreen(eyebrow: chapters.first?.dateLabel ?? "CHAPTER", title: "Edit this chapter.", back: back) {
        if let index = chapters.indices.first { VStack(alignment: .leading, spacing: 16) { Text("CHAPTER TITLE").font(.caption.weight(.bold)).tracking(1).foregroundStyle(TailorColor.ink.opacity(0.7)); TextField("Chapter title", text: $chapters[index].title).padding(14).background(TailorColor.mist.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 12)); Text("A few quiet pages made from the days you chose.").font(.callout).foregroundStyle(TailorColor.ink.opacity(0.72)).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(TailorColor.mist, lineWidth: 1)); LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) { ForEach(0..<6, id: \.self) { photo in RoundedRectangle(cornerRadius: 12).fill(photo == 1 || photo == 4 ? TailorColor.clay.opacity(0.72) : TailorColor.mist).frame(height: 88) } }; TailorInfoCard(symbol: "photo", title: "Cover photo", message: "Tap any photo to set the cover. Hold and drag to reorder.") } }
    }.safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Save chapter", action: next).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }
}
