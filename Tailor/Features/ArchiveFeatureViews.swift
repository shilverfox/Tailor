import SwiftUI
import PhotosUI
import UIKit

struct ReferencesFeatureView: View {
    @Binding var referenceAssetIdentifiers: [String]
    let next: () -> Void
    let back: () -> Void
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var thumbnails: [UIImage] = []
    @State private var selectionError: String?

    private var count: Int { referenceAssetIdentifiers.count }
    private var visibleSlotCount: Int { count < 5 ? max(3, count + 1) : 5 }

    var body: some View { TailorScreen(eyebrow: "REFERENCE PHOTOS", title: "Help us recognize\nthem.", back: back) {
        Text("Choose 3–5 clear photos from different ages and angles.")
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(100), spacing: 10), count: 3), alignment: .leading, spacing: 15) { ForEach(0..<visibleSlotCount, id: \.self) { index in
            if index < count { referenceTile(index) }
            else { PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images, photoLibrary: .shared()) { emptyReferenceTile }.buttonStyle(.plain) }
        } }
        Text(count >= 3 ? "\(count) of 3 minimum selected" : "\(3 - count) more needed")
            .font(.footnote)
            .padding(.top, 6)
        referenceHelpCard
        if let selectionError {
            Text(selectionError).font(.caption).foregroundStyle(.red)
        }
        Spacer(minLength: 80)
    }
    .task(id: referenceAssetIdentifiers) {
        // Picker previews are in-memory only. Rehydrate them from the stable
        // PHAsset identifiers whenever this page is recreated after a cold
        // launch, so a saved reference is never represented as a fake empty
        // tile merely because the view's @State was reset.
        guard !referenceAssetIdentifiers.isEmpty else { thumbnails = []; return }
        thumbnails = await loadThumbnails(for: referenceAssetIdentifiers)
    }
    .onChange(of: pickerItems) { _, newItems in
        Task { await updateSelection(from: newItems) }
    }
    .safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Start looking", disabled: count < 3, action: next).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }

    private var referenceHelpCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A helpful mix").font(.callout.weight(.semibold))
            Text("Different ages and angles make matching more reliable.")
                .font(.caption)
                .foregroundStyle(TailorColor.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(.horizontal, 16)
        .background(TailorColor.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.line))
    }

    @MainActor
    private func updateSelection(from items: [PhotosPickerItem]) async {
        let identifiers = items.compactMap(\.itemIdentifier)
        guard identifiers.count == items.count, Set(identifiers).count == identifiers.count else {
            selectionError = "Tailor needs photos that remain available in your selected library to use them as references."
            return
        }
        let resolved = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard resolved.count == identifiers.count else {
            selectionError = "Some reference photos are no longer available to Tailor. Check photo access and choose them again."
            return
        }
        selectionError = nil
        referenceAssetIdentifiers = identifiers
        // Preserve slot order. A task group returns in completion order, which
        // can silently show the right photos in the wrong reference slots.
        var loaded = [UIImage]()
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                loaded.append(image)
            }
        }
        thumbnails = loaded
    }
    @MainActor private func loadThumbnails(for identifiers: [String]) async -> [UIImage] {
        var images: [UIImage] = []
        for identifier in identifiers {
            guard let image = await thumbnail(for: identifier) else { continue }
            images.append(image)
        }
        return images
    }
    private func thumbnail(for identifier: String) async -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 240, height: 320), contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    private var emptyReferenceTile: some View { RoundedRectangle(cornerRadius: 18).fill(TailorColor.elevated).frame(width: 100, height: 134).overlay(Image(systemName: "plus").font(.title).foregroundStyle(TailorColor.secondaryInk)).overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))) }
    private func referenceTile(_ index: Int) -> some View { RoundedRectangle(cornerRadius: 18).fill(TailorColor.mist).frame(width: 100, height: 134).overlay { if index < thumbnails.count { Image(uiImage: thumbnails[index]).resizable().scaledToFill().frame(width: 100, height: 134).clipped() } else { Image(systemName: "photo").font(.title).foregroundStyle(TailorColor.ink) } }.clipShape(RoundedRectangle(cornerRadius: 18)).overlay(alignment: .topTrailing) { Button { remove(index) } label: { Image(systemName: "xmark").font(.headline.weight(.bold)).foregroundStyle(.white).frame(width: 32, height: 32).background(Circle().fill(TailorColor.ink.opacity(0.85))) }.padding(6).accessibilityLabel("Remove reference photo \(index + 1)") } }
    private func remove(_ index: Int) { guard referenceAssetIdentifiers.indices.contains(index) else { return }; referenceAssetIdentifiers.remove(at: index); if thumbnails.indices.contains(index) { thumbnails.remove(at: index) } }
}

struct ScanFeatureView: View {
    @Binding var progress: Double; let completedAssets: Int; let totalAssets: Int; let matchCount: Int; let previewAssetIdentifiers: [String]; let displayState: String; @Binding var paused: Bool; let isScanning: Bool; let errorMessage: String?; let start: () -> Void; let pause: () -> Void; let next: () -> Void; let back: () -> Void
    private var isResourceConstrained: Bool { displayState == "lowBattery" || displayState == "thermal" }
    private var isFailed: Bool { displayState == "failed" }
    private var isInterrupted: Bool { displayState == "interrupted" }
    private var needsReferencePhotos: Bool { displayState == "insufficientReferences" }
    var body: some View { ZStack { TailorColor.ink.ignoresSafeArea(); VStack(alignment: .leading, spacing: 24) { HStack { Button(action: back) { Image(systemName: "chevron.left") }.frame(width: 48, height: 48); Spacer(); Text("ON-DEVICE SCAN").font(.caption.weight(.bold)).tracking(1.2) }.foregroundStyle(.white)
        Text("Looking through\nthe moments.").font(TailorFont.display(36)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true).accessibilityLabel("Looking through the moments.")
        Spacer(); TailorProgressRing(progress: progress, label: paused ? "Paused" : "Checking").foregroundStyle(.white).frame(maxWidth: .infinity)
        Text(stateMessage)
            .foregroundStyle(.white.opacity(0.82))
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                if previewAssetIdentifiers.indices.contains(index) {
                    PhotoAssetThumbnail(identifier: previewAssetIdentifiers[index]).frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(index == 1 ? TailorColor.clay.opacity(0.8) : TailorColor.mist).frame(width: 38, height: 38)
                }
            }
        }.frame(maxWidth: .infinity)
        ScanStatusCard(completedAssets: completedAssets, matchCount: matchCount)
        Spacer()
        Text("Processed on this iPhone. Your photos are not uploaded.").font(.footnote).foregroundStyle(.white.opacity(0.72)).frame(maxWidth: .infinity)
    }.padding(24) }.safeAreaInset(edge: .bottom) {
        VStack(spacing: 8) {
            Button {
                if needsReferencePhotos { back() }
                else if displayState == "lowBattery" { pause() }
                else if isScanning { pause() }
                else if progress >= 1 { next() }
                else { start() }
            } label: {
                HStack { Text(primaryActionTitle); Spacer(); Image(systemName: isScanning ? "pause.fill" : "arrow.right") }
                    .font(.callout.weight(.bold)).padding(.horizontal, 18).frame(height: 56).background(TailorColor.paper).foregroundStyle(TailorColor.ink).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if isFailed {
                Button("Review matches so far") { next() }.font(.footnote.weight(.bold)).foregroundStyle(TailorColor.paper)
            } else if isResourceConstrained {
                Button(displayState == "lowBattery" ? "Continue later" : "Save and go back", action: back).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.paper)
            }
        }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.ink)
    } }

    private var primaryActionTitle: String {
        if needsReferencePhotos { return "Choose reference photos" }
        if displayState == "lowBattery" { return "Pause now" }
        if isResourceConstrained { return "Resume scan" }
        if isFailed { return "Try again" }
        if isScanning { return "Pause scan" }
        if progress >= 1 { return "Review photos" }
        return paused || isInterrupted ? "Resume scan" : "Start on-device scan"
    }

    private var stateMessage: String {
        if needsReferencePhotos { return "We need at least 3 available reference photos to recognize your pet. Choose them again, then restart the scan." }
        if displayState == "lowBattery" { return "Your scan is paused.\n\(matchCount) likely matches are saved. Turn off Low Power Mode, then resume." }
        if displayState == "thermal" { return "Your scan is paused.\n\(matchCount) likely matches are saved. Let your iPhone cool down, then resume." }
        if isFailed { return errorMessage ?? "We couldn’t finish this scan. Your references and reviewed photos are still here." }
        if isInterrupted { return "Ready to continue where you left off. Your progress is saved." }
        if paused { return "Scan paused at \(Int(progress * 100))%. Your progress is saved." }
        if progress >= 1 { return "Matches ready for your review." }
        if totalAssets > 0 && completedAssets == 0 { return "Preparing your reference photos on this iPhone." }
        return errorMessage ?? "Checking \(totalAssets) photos safely on this device."
    }
}

private struct ScanStatusCard: View {
    let completedAssets: Int
    let matchCount: Int
    var body: some View {
        HStack(alignment: .top, spacing: TailorSpacing.s) {
            Image(systemName: "photo.on.rectangle").foregroundStyle(TailorColor.clay).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(completedAssets) photos checked").font(.callout.weight(.semibold)).foregroundStyle(.white)
                Text("\(matchCount) likely matches so far").font(.footnote).foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
        .padding(TailorSpacing.m)
        .background(Color(red: 36 / 255, green: 71 / 255, blue: 60 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.2)))
    }
}

struct ReviewFeatureView: View {
    let name: String
    @Binding var photos: [ArchivePhoto]
    let next: () -> Void
    let back: () -> Void
    /// UI automation can open the pending-review decision directly, keeping this
    /// presentation state deterministic without changing production behavior.
    var showsPendingTimelinePromptOnAppear = false
    @State private var segment = 0
    @State private var selectedYear: Int?
    @State private var actionPhoto: ArchivePhoto?
    @State private var showPendingTimelinePrompt = false
    @State private var isQuickSelecting = false
    @State private var quickSelection = Set<UUID>()

    init(
        name: String,
        photos: Binding<[ArchivePhoto]>,
        next: @escaping () -> Void,
        back: @escaping () -> Void,
        showsPendingTimelinePromptOnAppear: Bool = false
    ) {
        self.name = name
        self._photos = photos
        self.next = next
        self.back = back
        self.showsPendingTimelinePromptOnAppear = showsPendingTimelinePromptOnAppear
        self._showPendingTimelinePrompt = State(initialValue: false)
    }

    private var years: [Int] { Array(Set(photos.compactMap { $0.createdAt.map { Calendar.current.component(.year, from: $0) } })).sorted(by: >) }
    private var pendingReviewCount: Int { photos.filter { $0.decision == .needsReview && $0.sensitivityState == .normal }.count }
    private var eligibleCount: Int { photos.filter(\.isEligibleForArchive).count }

    private var filtered: [ArchivePhoto] {
        photos.filter {
            let inSegment: Bool
            switch segment {
            case 0: inSegment = $0.isEligibleForArchive
            case 1: inSegment = $0.decision == .needsReview && $0.sensitivityState == .normal
            case 2: inSegment = $0.sensitivityState == .needsSensitiveReview || $0.sensitivityState == .hiddenUntilUserDecides
            default: inSegment = $0.decision == .excluded || $0.sensitivityState == .neverUse
            }
            guard let selectedYear else { return inSegment }
            return inSegment && $0.createdAt.map { Calendar.current.component(.year, from: $0) } == selectedYear
        }
    }

    var body: some View {
        TailorScreen(eyebrow: "REVIEW", title: "We found \(photos.count) moments.", back: back) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    reviewTab("HIGH · \(eligibleCount)", index: 0)
                    reviewTab("NEEDS REVIEW · \(pendingReviewCount)", index: 1)
                    reviewTab("SENSITIVE · \(sensitiveCount)", index: 2)
                    reviewTab("EXCLUDED · \(excludedCount)", index: 3)
                }
            }
            Divider()
            Menu { Button("All years") { selectedYear = nil }; ForEach(years, id: \.self) { year in Button(String(year)) { selectedYear = year } } } label: { Label(selectedYear.map(String.init) ?? "All years", systemImage: "line.3.horizontal.decrease.circle").font(.footnote.weight(.semibold)) }.foregroundStyle(TailorColor.ink)

            if pendingReviewCount > 0 && segment != 1 {
                Button { segment = 1 } label: {
                    HStack { Image(systemName: "questionmark.circle.fill"); Text("Review \(pendingReviewCount) photos waiting for your choice").font(.callout.weight(.semibold)); Spacer(); Image(systemName: "arrow.right") }
                        .padding(14).foregroundStyle(TailorColor.ink).background(TailorColor.mist.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).accessibilityLabel("Review \(pendingReviewCount) photos waiting for your choice")
            }

            if segment == 1, !filtered.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isQuickSelecting ? "Select the photos that are \(name)." : "Approve several photos at once.").font(.callout.weight(.semibold))
                            Text(isQuickSelecting ? "Tap a photo to select it, then add only those you recognize." : "Open a photo to exclude it or review it in detail.").font(.footnote).foregroundStyle(TailorColor.ink.opacity(0.7))
                        }
                        Spacer(minLength: 8)
                        Button(isQuickSelecting ? "Done" : "Select") {
                            isQuickSelecting.toggle()
                            if !isQuickSelecting { quickSelection.removeAll() }
                        }.font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay)
                    }
                    if isQuickSelecting {
                        HStack(spacing: 10) {
                            Button("Select all shown") { quickSelection = Set(filtered.map(\.id)) }
                                .font(.footnote.weight(.bold)).foregroundStyle(TailorColor.ink)
                            Spacer()
                            Button("Add \(quickSelection.count) to archive") { includeQuickSelection() }
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(quickSelection.isEmpty ? TailorColor.secondaryInk : TailorColor.ink)
                                .disabled(quickSelection.isEmpty)
                        }
                    }
                }
                .padding(14).background(TailorColor.mist.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if filtered.isEmpty {
                TailorInfoCard(symbol: "photo", title: "No photos in this group", message: segment == 1 ? "All currently visible candidates have been decided." : "Choose another confidence group to review more photos.")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(filtered) { photo in
                    Button {
                        if isQuickSelecting && segment == 1 {
                            toggleQuickSelection(photo.id)
                        } else {
                            actionPhoto = photo
                        }
                    } label: { photoTile(photo, isQuickSelected: quickSelection.contains(photo.id)) }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contextMenu { photoActions(photo) }
                        .accessibilityIdentifier("review.photo.\(photo.id.uuidString)")
                        .accessibilityLabel(photoAccessibilityLabel(photo))
                }
            }
            .accessibilityIdentifier("review.photoGrid")
            TailorInfoCard(symbol: "checkmark.circle", title: segment == 2 ? "Sensitive photos stay out of your archive" : "Choose each photo", message: segment == 2 ? "Choose Include only when you are ready. Tailor never adds these photos automatically." : "Tap a photo to choose This is \(name) or Not \(name).")
            // Keep the primary action in the same vertical scroll view as a
            // large review grid. A bottom safe-area overlay can win the pan
            // gesture after the grid reaches its end, leaving people unable to
            // scroll back to the photos they still need to review.
            TailorPrimaryButton(title: "Create timeline", disabled: eligibleCount == 0, action: continueToTimeline)
                .padding(.top, 4)
                .accessibilityIdentifier("review.createTimeline")
        }
        .confirmationDialog("Is this \(name)?", isPresented: Binding(get: { actionPhoto != nil }, set: { if !$0 { actionPhoto = nil } }), presenting: actionPhoto) { photo in
            Button("This is \(name)", systemImage: "checkmark.circle") { setIncluded(photo); actionPhoto = nil }
            Button("Not \(name)", systemImage: "xmark.circle", role: .destructive) { setExcluded(photo, reason: .userMarkedNotPet); actionPhoto = nil }
            Button("Set aside as sensitive", systemImage: "hand.raised") { setSensitive(photo, state: .hiddenUntilUserDecides); actionPhoto = nil }
            Button("Never use in this archive", systemImage: "nosign", role: .destructive) { setNeverUse(photo); actionPhoto = nil }
            Button("Decide later") { actionPhoto = nil }
        } message: { _ in Text("You can change this later. Only photos you include can appear in the timeline and PDF.") }
        .confirmationDialog(
            pendingReviewCount == 1 ? "1 photo still needs your confirmation" : "\(pendingReviewCount) photos still need your confirmation",
            isPresented: $showPendingTimelinePrompt,
            titleVisibility: .visible
        ) {
            Button("Continue confirming photos") { segment = 1 }
            Button("Create timeline with \(eligibleCount) selected \(eligibleCount == 1 ? "photo" : "photos")") { next() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unconfirmed photos will not be included. You can return later without losing your choices.")
        }
        .task(id: showsPendingTimelinePromptOnAppear) {
            guard showsPendingTimelinePromptOnAppear, pendingReviewCount > 0 else { return }
            await presentPendingTimelinePrompt()
        }
    }

    private var sensitiveCount: Int { photos.filter { $0.sensitivityState == .needsSensitiveReview || $0.sensitivityState == .hiddenUntilUserDecides }.count }
    private var excludedCount: Int { photos.filter { $0.decision == .excluded || $0.sensitivityState == .neverUse }.count }
    private func reviewTab(_ title: String, index: Int) -> some View {
        let marker = ["✓", "?", "✋", "⊖"][index]
        return Button { segment = index } label: {
            Text("\(marker) \(title)")
                .font(.caption.weight(.bold))
                .foregroundStyle(segment == index ? TailorColor.clay : TailorColor.ink)
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(segment == index ? TailorColor.ink : .clear).frame(height: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(segment == index ? .isSelected : [])
    }
    private func photoTile(_ photo: ArchivePhoto, isQuickSelected: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            PhotoAssetThumbnail(identifier: photo.assetLocalIdentifier)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            LinearGradient(colors: [.clear, .black.opacity(0.48)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .trailing, spacing: 3) {
                Image(systemName: isQuickSelected ? "checkmark.circle.fill" : statusIcon(for: photo)).font(.title3)
                Text(isQuickSelected ? "SELECTED" : "\(Int(photo.confidence * 100))%").font(.caption2.weight(.bold))
            }.padding(7).foregroundStyle(.white)
            if isQuickSelected { RoundedRectangle(cornerRadius: 12).stroke(TailorColor.clay, lineWidth: 3) }
        }
        // Keep the grid's measured height independent of PhotoKit's degraded
        // and full-quality callbacks. This prevents scroll-position oscillation
        // while thumbnails arrive asynchronously.
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }
    private func continueToTimeline() {
        guard pendingReviewCount > 0 else { next(); return }
        Task { await presentPendingTimelinePrompt() }
    }

    @MainActor private func presentPendingTimelinePrompt() async {
        // Both the bottom inset and the dialog need a completed presentation
        // cycle on iOS 26. A short yield makes the state transition observable
        // rather than asking UIKit to present during view installation.
        try? await Task.sleep(for: .milliseconds(150))
        showPendingTimelinePrompt = true
    }

    private func statusIcon(for photo: ArchivePhoto) -> String {
        switch photo.sensitivityState {
        case .needsSensitiveReview: "exclamationmark.shield.fill"
        case .hiddenUntilUserDecides: "clock.badge.exclamationmark"
        case .neverUse: "nosign"
        case .normal: photo.decision == .selected ? "checkmark.circle.fill" : (photo.decision == .needsReview ? "questionmark.circle.fill" : "xmark.circle.fill")
        }
    }

    private func photoAccessibilityLabel(_ photo: ArchivePhoto) -> String {
        if isQuickSelecting && segment == 1 {
            let state = quickSelection.contains(photo.id) ? "Selected for quick approval" : "Double tap to select for quick approval"
            return "Photo confidence \(Int(photo.confidence * 100)) percent. \(state)."
        }
        return "Photo confidence \(Int(photo.confidence * 100)) percent. Tap to decide whether this is \(name)."
    }

    @ViewBuilder private func photoActions(_ photo: ArchivePhoto) -> some View {
        Button("Include in archive", systemImage: "checkmark.circle") { setIncluded(photo) }
        Button("Keep for review", systemImage: "questionmark.circle") { setNeedsReview(photo) }
        Button("Sensitive — review now", systemImage: "exclamationmark.shield") { setSensitive(photo, state: .needsSensitiveReview) }
        Button("Sensitive — decide later", systemImage: "clock") { setSensitive(photo, state: .hiddenUntilUserDecides) }
        Button("Never use in this archive", systemImage: "nosign", role: .destructive) { setNeverUse(photo) }
        Button("Not this pet", systemImage: "xmark.circle", role: .destructive) { setExcluded(photo, reason: .userMarkedNotPet) }
    }

    private func setIncluded(_ photo: ArchivePhoto) { update(photo) { $0.decision = .selected; $0.sensitivityState = .normal; $0.excludedReason = nil } }
    private func setNeedsReview(_ photo: ArchivePhoto) { update(photo) { $0.decision = .needsReview; $0.sensitivityState = .normal; $0.excludedReason = nil } }
    private func setSensitive(_ photo: ArchivePhoto, state: PhotoSensitivityState) { update(photo) { $0.decision = .needsReview; $0.sensitivityState = state; $0.excludedReason = nil } }
    private func setNeverUse(_ photo: ArchivePhoto) { update(photo) { $0.decision = .excluded; $0.sensitivityState = .neverUse; $0.excludedReason = .neverUse } }
    private func setExcluded(_ photo: ArchivePhoto, reason: PhotoExcludedReason) { update(photo) { $0.decision = .excluded; $0.sensitivityState = .normal; $0.excludedReason = reason } }
    private func update(_ photo: ArchivePhoto, _ mutation: (inout ArchivePhoto) -> Void) { guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }; mutation(&photos[index]) }
    private func toggleQuickSelection(_ id: UUID) { if quickSelection.contains(id) { quickSelection.remove(id) } else { quickSelection.insert(id) } }
    private func includeQuickSelection() {
        let visibleIDs = Set(filtered.map(\.id))
        let approvedIDs = quickSelection.intersection(visibleIDs)
        guard !approvedIDs.isEmpty else { return }
        for index in photos.indices where approvedIDs.contains(photos[index].id) {
            photos[index].decision = .selected
            photos[index].sensitivityState = .normal
            photos[index].excludedReason = nil
        }
        quickSelection.removeAll()
        isQuickSelecting = false
    }
}

struct TimelineFeatureView: View {
    let name: String; @Binding var chapters: [Chapter]; let photos: [ArchivePhoto]; let edit: (UUID) -> Void; let next: () -> Void; let back: () -> Void
    private var photoLookup: [UUID: ArchivePhoto] { Dictionary(uniqueKeysWithValues: photos.filter(\.isEligibleForArchive).map { ($0.id, $0) }) }
    var body: some View { TailorScreen(eyebrow: "TIMELINE", title: "\(name)’s life, in moments.", back: back) {
        Text("Made from the photos you chose. Change every chapter.").foregroundStyle(TailorColor.ink.opacity(0.72))
        VStack(alignment: .leading, spacing: 0) { ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
            HStack(alignment: .top, spacing: 14) { VStack(spacing: 0) { Circle().fill(TailorColor.clay).frame(width: 10, height: 10); Rectangle().fill(TailorColor.mist).frame(width: 2).frame(maxHeight: .infinity).padding(.top, 4) }.frame(width: 20)
                VStack(alignment: .leading, spacing: 6) { Text(chapter.dateLabel).font(.caption.weight(.bold)).foregroundStyle(TailorColor.clay); Button(action: { edit(chapter.id) }) { HStack(spacing: 12) { Group { if !chapter.isHidden, let cover = chapter.photoIDs.first.flatMap({ photoLookup[$0] }) { PhotoAssetThumbnail(identifier: cover.assetLocalIdentifier) } else { Image(systemName: chapter.isHidden ? "eye.slash" : "photo").frame(maxWidth: .infinity, maxHeight: .infinity).foregroundStyle(TailorColor.ink.opacity(0.65)) } }.frame(width: 72, height: 72).background(TailorColor.mist).clipShape(RoundedRectangle(cornerRadius: 20)); VStack(alignment: .leading, spacing: 3) { Text(chapter.title).font(.callout.weight(.bold)).foregroundStyle(TailorColor.ink); Text(chapter.isHidden ? "Hidden from album" : "\(chapter.photoIDs.filter { photoLookup[$0] != nil }.count) selected photos").font(.footnote).foregroundStyle(TailorColor.ink.opacity(0.68)) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(TailorColor.ink) }.padding(14).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.mist, lineWidth: 1)) }.buttonStyle(.plain).opacity(chapter.isHidden ? 0.5 : 1).contextMenu { Button(chapter.isHidden ? "Show in album" : "Hide from album", systemImage: chapter.isHidden ? "eye" : "eye.slash") { toggleVisibility(chapter.id) }; Button("Edit chapter", systemImage: "pencil") { edit(chapter.id) } } }.padding(.bottom, index == chapters.count - 1 ? 0 : 18) }
        } }
        Text("When dates do not establish a story, use neutral titles such as “2018–2020” or “Days together.”").font(.caption).foregroundStyle(TailorColor.ink.opacity(0.65)).padding(.top, 6)
    }.safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Edit album", action: next).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }
    private func toggleVisibility(_ id: UUID) { guard let index = chapters.firstIndex(where: { $0.id == id }) else { return }; chapters[index].isHidden.toggle() }
}
struct ChapterEditorFeatureView: View {
    @Binding var chapters: [Chapter]
    let photos: [ArchivePhoto]
    let selectedChapterID: UUID?
    let next: () -> Void
    let back: () -> Void
    private var selectedPhotos: [ArchivePhoto] { photos.filter(\.isEligibleForArchive) }
    var body: some View {
        TailorScreen(eyebrow: chapterIndex.map { chapters[$0].dateLabel } ?? "CHAPTER", title: "Edit this chapter.", back: back) {
            if let index = chapterIndex {
                VStack(alignment: .leading, spacing: 16) {
                    Text("CHAPTER TITLE").font(.caption.weight(.bold)).tracking(1).foregroundStyle(TailorColor.ink.opacity(0.7))
                    TextField("Chapter title", text: $chapters[index].title)
                        .padding(14).background(TailorColor.mist.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 12))
                    TextField("Add a note in your own words (optional)", text: $chapters[index].note, axis: .vertical)
                        .lineLimit(3...6).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(TailorColor.mist, lineWidth: 1))
                    Text("PHOTOS IN THIS CHAPTER · TAP TO SET COVER").font(.caption.weight(.bold)).tracking(1).foregroundStyle(TailorColor.ink.opacity(0.7))
                    chapterPhotoGrid(index: index)
                    if !availablePhotos(index: index).isEmpty {
                        Text("ADD SELECTED PHOTOS").font(.caption.weight(.bold)).tracking(1).foregroundStyle(TailorColor.ink.opacity(0.7))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(availablePhotos(index: index)) { photo in
                                    Button { chapters[index].photoIDs.append(photo.id) } label: {
                                        PhotoAssetThumbnail(identifier: photo.assetLocalIdentifier).frame(width: 84, height: 84)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(alignment: .bottomTrailing) { Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(TailorColor.clay).background(Circle().fill(.white)) }
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    TailorInfoCard(symbol: "photo", title: "Cover photo", message: "The first photo is the cover. Tap another photo to make it the cover; use Remove to take it out of this chapter.")
                }
            } else {
                TailorInfoCard(symbol: "exclamationmark.triangle", title: "This chapter is unavailable", message: "Return to the timeline and choose a chapter to edit.")
            }
        }
        .safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Save chapter", action: next).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) }
    }
    private var chapterIndex: Int? { guard let selectedChapterID else { return nil }; return chapters.firstIndex { $0.id == selectedChapterID } }
    @ViewBuilder private func chapterPhotoGrid(index: Int) -> some View {
        if chapters[index].photoIDs.isEmpty {
            TailorInfoCard(symbol: "photo", title: "No photos in this chapter", message: "Choose from your confirmed photos below.")
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(chapters[index].photoIDs, id: \.self) { photoID in
                    if let photo = photos.first(where: { $0.id == photoID && $0.isEligibleForArchive }) {
                        Button { makeCover(photoID, at: index) } label: {
                            ZStack(alignment: .topTrailing) {
                                PhotoAssetThumbnail(identifier: photo.assetLocalIdentifier).frame(height: 104)
                                if chapters[index].photoIDs.first == photoID {
                                    Text("COVER").font(.caption2.weight(.bold)).padding(6).background(TailorColor.ink).foregroundStyle(.white).clipShape(Capsule()).padding(6)
                                }
                            }.clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .draggable(photoID.uuidString)
                        .dropDestination(for: String.self) { identifiers, _ in
                            guard let sourceID = identifiers.first.flatMap(UUID.init(uuidString:)), sourceID != photoID else { return false }
                            move(sourceID, before: photoID, at: index)
                            return true
                        }
                        .contextMenu {
                            Button("Make cover", systemImage: "photo.on.rectangle") { makeCover(photoID, at: index) }
                            Button("Remove from chapter", systemImage: "trash", role: .destructive) { chapters[index].photoIDs.removeAll { $0 == photoID } }
                        }
                    }
                }
            }
        }
    }
    private func availablePhotos(index: Int) -> [ArchivePhoto] { selectedPhotos.filter { !chapters[index].photoIDs.contains($0.id) } }
    private func makeCover(_ photoID: UUID, at index: Int) { chapters[index].photoIDs.removeAll { $0 == photoID }; chapters[index].photoIDs.insert(photoID, at: 0) }
    private func move(_ sourceID: UUID, before destinationID: UUID, at index: Int) {
        guard let sourceIndex = chapters[index].photoIDs.firstIndex(of: sourceID), let destinationIndex = chapters[index].photoIDs.firstIndex(of: destinationID) else { return }
        chapters[index].photoIDs.remove(at: sourceIndex)
        chapters[index].photoIDs.insert(sourceID, at: sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex)
    }
}
