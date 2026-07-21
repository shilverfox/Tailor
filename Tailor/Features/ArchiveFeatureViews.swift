import SwiftUI
import PhotosUI
import UIKit

struct ReferencesFeatureView: View {
    @Binding var referenceAssetIdentifiers: [String]
    let next: () -> Void
    let selectionChanged: () -> Void
    let continueLater: () -> Void
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
    .safeAreaInset(edge: .bottom) { VStack(spacing: 8) { TailorPrimaryButton(title: "Start looking", disabled: count < 3, action: next); Button("Save for later", action: continueLater).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }

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
        selectionChanged()
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
    private func remove(_ index: Int) { guard referenceAssetIdentifiers.indices.contains(index) else { return }; referenceAssetIdentifiers.remove(at: index); if thumbnails.indices.contains(index) { thumbnails.remove(at: index) }; selectionChanged() }
}

struct ManualImportFeatureView: View {
    let manualAssets: [ManualAssetReference]
    let importItems: ([PhotosPickerItem]) async throws -> Int
    let removeAsset: (UUID) -> Void
    let next: () -> Void
    let continueLater: () -> Void
    let back: () -> Void
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var errorMessage: String?
    private var importedCount: Int { manualAssets.count }

    var body: some View {
        TailorScreen(eyebrow: "MANUAL IMPORT", title: "Choose the moments\nyou want to review.", back: back) {
            Text("Choose 3–500 photos. Tailor copies only these selections into its private storage and will not scan your library.")
                .foregroundStyle(TailorColor.secondaryInk)
            TailorInfoCard(symbol: "lock.shield", title: "Only your explicit choices", message: "Private copies stay on this iPhone and are removed when you delete this archive.")
            TailorInfoCard(symbol: "arrow.triangle.2.circlepath", title: "Ready for Needs review", message: "These photos go directly to review as pending choices. Tailor does not run a library scan. If you later grant access, matching fingerprints replace private copies with PhotoKit references.")
            PhotosPicker(selection: $pickerItems, maxSelectionCount: max(1, 500 - importedCount), matching: .images) {
                Label(importedCount >= 500 ? "500-photo limit reached" : (importedCount == 0 ? "Choose photos" : "Add more photos"), systemImage: "photo.on.rectangle.angled")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 58)
                    .background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(importedCount >= 500)
            Text("\(importedCount) / 500 selected · \(max(0, 3 - importedCount)) more needed")
                .font(.footnote.weight(.semibold)).foregroundStyle(TailorColor.secondaryInk)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(manualAssets) { asset in
                    ZStack(alignment: .topTrailing) {
                        PhotoAssetThumbnail(identifier: ManualAssetStore.identifier(for: asset.relativePath))
                            .aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                        Button { removeAsset(asset.id) } label: {
                            Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.white).shadow(radius: 2)
                        }.padding(5).accessibilityLabel("Remove imported photo")
                    }
                }
            }
            if isImporting { ProgressView("Saving selected photos privately…") }
            if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
            Spacer(minLength: 80)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { @MainActor in
                isImporting = true; errorMessage = nil
                do { _ = try await importItems(items); pickerItems = [] }
                catch { errorMessage = "Some photos could not be saved. Remove them and try again." }
                isImporting = false
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                TailorPrimaryButton(title: "Review selected photos", disabled: !ManualImportPolicy.canContinue(count: importedCount) || isImporting, action: next)
                Button("Save for later", action: continueLater).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay)
            }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper)
        }
    }
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
        Text("Processed on this iPhone. Your photos are not uploaded.").font(.footnote).foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.center).lineLimit(nil).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
    }.padding(24) }.safeAreaInset(edge: .bottom, spacing: 0) {
        VStack(spacing: 8) {
            Button {
                if needsReferencePhotos { back() }
                else if displayState == "lowBattery" { pause() }
                else if isScanning { pause() }
                else if progress >= 1 { next() }
                else { start() }
            } label: {
                HStack { Text(primaryActionTitle); Spacer(); Image(systemName: isScanning ? "pause.fill" : "arrow.right") }
                    .font(.callout.weight(.bold))
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(TailorColor.paper)
                    .foregroundStyle(TailorColor.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            if isFailed {
                Button("Review matches so far") { next() }.font(.footnote.weight(.bold)).foregroundStyle(TailorColor.paper)
            } else if isResourceConstrained {
                Button(displayState == "lowBattery" ? "Continue later" : "Save and go back", action: back).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.paper)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(TailorColor.ink)
        .frame(maxWidth: .infinity)
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
    let activeGenerationID: String?
    @Binding var photos: [ArchivePhoto]
    let next: () -> Void
    let back: () -> Void
    let continueLater: () -> Void
    let appendManualItems: (([PhotosPickerItem]) async throws -> Int)?
    /// UI automation can open the pending-review decision directly, keeping this
    /// presentation state deterministic without changing production behavior.
    var showsPendingTimelinePromptOnAppear = false
    @State private var segment = 0
    @State private var selectedYear: Int?
    @State private var actionPhoto: ArchivePhoto?
    @State private var sensitiveApprovalPhoto: ArchivePhoto?
    @State private var showPendingTimelinePrompt = false
    @State private var isQuickSelecting = false
    @State private var quickSelection = Set<UUID>()
    @State private var manualPickerItems: [PhotosPickerItem] = []
    @State private var manualImportError: String?
    /// The photo grid's cell height is derived once from the measured content
    /// width and then held constant. A LazyVGrid inside a ScrollView otherwise
    /// re-derives row heights from `aspectRatio` as cells recycle at the scroll
    /// boundary, and that estimate/actual mismatch oscillates contentSize —
    /// the visible "jitter" when overscrolling at the bottom of a long list.
    @State private var gridCellHeight: CGFloat = 108

    init(
        name: String,
        activeGenerationID: String? = nil,
        photos: Binding<[ArchivePhoto]>,
        next: @escaping () -> Void,
        back: @escaping () -> Void,
        continueLater: @escaping () -> Void = {},
        appendManualItems: (([PhotosPickerItem]) async throws -> Int)? = nil,
        showsPendingTimelinePromptOnAppear: Bool = false
    ) {
        self.name = name
        self.activeGenerationID = activeGenerationID
        self._photos = photos
        self.next = next
        self.back = back
        self.continueLater = continueLater
        self.appendManualItems = appendManualItems
        self.showsPendingTimelinePromptOnAppear = showsPendingTimelinePromptOnAppear
        self._showPendingTimelinePrompt = State(initialValue: false)
    }

    private var years: [Int] { Array(Set(photos.compactMap { $0.createdAt.map { Calendar.current.component(.year, from: $0) } })).sorted(by: >) }
    private var pendingReviewCount: Int { photos.filter { $0.decision == .pending && $0.sensitivityState == .normal && $0.staleDecision == nil }.count }
    private var staleCount: Int { photos.filter { $0.staleDecision != nil }.count }
    private var eligibleCount: Int { photos.filter(\.isEligibleForArchive).count }

    private var filtered: [ArchivePhoto] {
        photos.filter {
            let inSegment: Bool
            switch segment {
            case 0: inSegment = $0.isEligibleForArchive
            case 1: inSegment = $0.decision == .pending && $0.sensitivityState == .normal && $0.staleDecision == nil
            case 2: inSegment = $0.sensitivityState == .sensitive
            case 3: inSegment = $0.decision == .excluded || $0.sensitivityState == .neverUse
            default: inSegment = $0.staleDecision != nil
            }
            guard let selectedYear else { return inSegment }
            return inSegment && $0.createdAt.map { Calendar.current.component(.year, from: $0) } == selectedYear
        }
    }

    var body: some View {
        TailorScreen(eyebrow: "REVIEW", title: "We found \(photos.count) moments.", back: back) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    reviewTab("HIGH · \(eligibleCount)", index: 0)
                    reviewTab("NEEDS REVIEW · \(pendingReviewCount)", index: 1)
                    reviewTab("SENSITIVE · \(sensitiveCount)", index: 2)
                    reviewTab("EXCLUDED · \(excludedCount)", index: 3)
                    reviewTab("STALE · \(staleCount)", index: 4)
            }
            Divider()
            Menu { Button("All years") { selectedYear = nil }; ForEach(years, id: \.self) { year in Button(String(year)) { selectedYear = year } } } label: { Label(selectedYear.map(String.init) ?? "All years", systemImage: "line.3.horizontal.decrease.circle").font(.footnote.weight(.semibold)) }.foregroundStyle(TailorColor.ink)

            if appendManualItems != nil {
                PhotosPicker(selection: $manualPickerItems, maxSelectionCount: max(1, 500 - photos.count), matching: .images) {
                    Label("Add more selected photos", systemImage: "plus.circle")
                        .font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay)
                }
                if let manualImportError { Text(manualImportError).font(.caption).foregroundStyle(.red) }
            }

            if pendingReviewCount > 0 && segment != 1 {
                Button { segment = 1 } label: {
                    HStack { Image(systemName: "questionmark.circle.fill"); Text("Review \(pendingReviewCount) photos waiting for your choice").font(.callout.weight(.semibold)); Spacer(); Image(systemName: "arrow.right") }
                        .padding(14).foregroundStyle(TailorColor.ink).background(TailorColor.mist.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).accessibilityLabel("Review \(pendingReviewCount) photos waiting for your choice")
            }

            if staleCount > 0 && segment != 4 {
                Button { segment = 4 } label: {
                    HStack { Image(systemName: "clock.arrow.circlepath"); VStack(alignment: .leading) { Text("Review \(staleCount) stale choices").font(.callout.weight(.semibold)); Text("References, pet type, or matcher changed. Old choices stay visible but cannot enter the book until reviewed again.").font(.caption) }; Spacer(); Image(systemName: "arrow.right") }
                        .padding(14).foregroundStyle(TailorColor.ink).background(TailorColor.mist.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
            }

            if (segment == 1 || segment == 4), !filtered.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isQuickSelecting ? "Select the photos that are \(name)." : (segment == 4 ? "Review old choices again." : "Approve several photos at once.")).font(.callout.weight(.semibold))
                            Text(isQuickSelecting ? "Tap a photo to select it, then add only those you recognize." : (segment == 4 ? "The old choice is reference-only until you approve or exclude it in this generation." : "Open a photo to exclude it or review it in detail.")).font(.footnote).foregroundStyle(TailorColor.ink.opacity(0.7))
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
                        if isQuickSelecting && (segment == 1 || segment == 4) {
                            toggleQuickSelection(photo.id)
                        } else if photo.sensitivityState == .sensitive {
                            sensitiveApprovalPhoto = photo
                        } else {
                            actionPhoto = photo
                        }
                    } label: { photoTile(photo, isQuickSelected: quickSelection.contains(photo.id)) }
                        .frame(height: gridCellHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contextMenu { photoActions(photo) }
                        .accessibilityIdentifier("review.photo.\(photo.id.uuidString)")
                        .accessibilityLabel(photoAccessibilityLabel(photo))
                }
            }
            .accessibilityIdentifier("review.photoGrid")
            // Measure the grid's content width once and hold a constant cell
            // height. Three flexible columns with 8pt gutters → cell edge =
            // (width - 2*8) / 3. Feeding this back as a fixed height keeps the
            // LazyVGrid's contentSize stable while cells recycle, which removes
            // the overscroll jitter at the bottom of a long review list.
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateGridCellHeight(width: proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, newWidth in updateGridCellHeight(width: newWidth) }
                }
            }
            TailorInfoCard(symbol: "checkmark.circle", title: segment == 2 ? "Sensitive photos stay out of your archive" : "Choose each photo", message: segment == 2 ? "Choose Include only when you are ready. Tailor never adds these photos automatically." : "Tap a photo to choose This is \(name) or Not \(name).")
            // Keep the primary action in the same vertical scroll view as a
            // large review grid. A bottom safe-area overlay can win the pan
            // gesture after the grid reaches its end, leaving people unable to
            // scroll back to the photos they still need to review.
            TailorPrimaryButton(title: "Create memory book", disabled: eligibleCount < 3, action: continueToTimeline)
                .padding(.top, 4)
                .accessibilityIdentifier("review.createTimeline")
            Button("Save for later", action: continueLater).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay).frame(maxWidth: .infinity)
        }
        .confirmationDialog("Is this \(name)?", isPresented: Binding(get: { actionPhoto != nil }, set: { if !$0 { actionPhoto = nil } }), presenting: actionPhoto) { photo in
            Button("This is \(name)", systemImage: "checkmark.circle") { setIncluded(photo); actionPhoto = nil }
            Button("Not \(name)", systemImage: "xmark.circle", role: .destructive) { setExcluded(photo, reason: .userMarkedNotPet); actionPhoto = nil }
            Button("Set aside as sensitive", systemImage: "hand.raised") { setSensitive(photo); actionPhoto = nil }
            Button("Never use in this archive", systemImage: "nosign", role: .destructive) { setNeverUse(photo); actionPhoto = nil }
            Button("Decide later") { actionPhoto = nil }
        } message: { _ in Text("You can change this later. Only photos you include can appear in the timeline and PDF.") }
        .sheet(item: $sensitiveApprovalPhoto) { photo in
            SensitivePhotoApprovalSheet(
                name: name,
                photo: photo,
                include: { approveSensitive(photo); sensitiveApprovalPhoto = nil },
                exclude: { setExcluded(photo, reason: .userExcluded); sensitiveApprovalPhoto = nil },
                cancel: { sensitiveApprovalPhoto = nil }
            )
        }
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
        .onChange(of: manualPickerItems) { _, items in
            guard let appendManualItems, !items.isEmpty else { return }
            Task { @MainActor in
                do { _ = try await appendManualItems(items); manualPickerItems = []; manualImportError = nil }
                catch { manualImportError = "Those photos could not be added. Try choosing them again." }
            }
        }
    }

    private var sensitiveCount: Int { photos.filter { $0.sensitivityState == .sensitive }.count }
    private var excludedCount: Int { photos.filter { $0.decision == .excluded || $0.sensitivityState == .neverUse }.count }
    private func reviewTab(_ title: String, index: Int) -> some View {
        let marker = ["✓", "?", "✋", "⊖", "↻"][index]
        return Button { segment = index } label: {
            Text("\(marker) \(title)")
                .font(.caption.weight(.bold))
                .foregroundStyle(segment == index ? TailorColor.clay : TailorColor.ink)
                .frame(maxWidth: .infinity, minHeight: 42)
                .multilineTextAlignment(.center)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(colors: [.clear, .black.opacity(0.48)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .trailing, spacing: 3) {
                Image(systemName: isQuickSelected ? "checkmark.circle.fill" : statusIcon(for: photo)).font(.title3)
                Text(isQuickSelected ? "SELECTED" : "\(Int(photo.confidence * 100))%").font(.caption2.weight(.bold))
            }.padding(7).foregroundStyle(.white)
            if isQuickSelected { RoundedRectangle(cornerRadius: 12).stroke(TailorColor.clay, lineWidth: 3) }
        }
        // The enclosing grid pins each cell to a constant `gridCellHeight`, so
        // the tile fills that fixed box instead of deriving its own height from
        // an aspect ratio. Keeping height independent of PhotoKit's degraded and
        // full-quality callbacks is what prevents scroll-position oscillation
        // while thumbnails arrive asynchronously.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
    private func updateGridCellHeight(width: CGFloat) {
        guard width > 0 else { return }
        // Three flexible columns separated by two 8pt gutters. The tiles are
        // square, so the derived edge length is also the row height.
        let edge = ((width - 16) / 3).rounded(.down)
        guard edge > 0, abs(edge - gridCellHeight) > 0.5 else { return }
        gridCellHeight = edge
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
        case .sensitive: "exclamationmark.shield.fill"
        case .neverUse: "nosign"
        case .normal: photo.decision == .selected ? "checkmark.circle.fill" : (photo.decision == .pending ? "questionmark.circle.fill" : "xmark.circle.fill")
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
        Button("Keep for review", systemImage: "questionmark.circle") { setPending(photo) }
        Button("Set aside as sensitive", systemImage: "exclamationmark.shield") { setSensitive(photo) }
        Button("Never use in this archive", systemImage: "nosign", role: .destructive) { setNeverUse(photo) }
        Button("Not this pet", systemImage: "xmark.circle", role: .destructive) { setExcluded(photo, reason: .userMarkedNotPet) }
    }

    private func setIncluded(_ photo: ArchivePhoto) { update(photo) { value in if let generation = activeGenerationID, value.decisionSource != .manualImport { value.reconfirm(.selected, generationID: generation) } else { value.decision = .selected; value.decisionSource = value.decisionSource == .manualImport ? .manualImport : .human; value.staleDecision = nil }; value.sensitivityState = .normal; value.excludedReason = nil } }
    private func approveSensitive(_ photo: ArchivePhoto) { update(photo) { value in guard value.sensitivityState == .sensitive else { return }; if let generation = activeGenerationID, value.decisionSource != .manualImport { value.reconfirm(.selected, generationID: generation, approvedSensitiveAt: .now) } else { value.decision = .selected; value.staleDecision = nil; value.sensitiveApprovedAt = .now }; value.excludedReason = nil } }
    private func setPending(_ photo: ArchivePhoto) { update(photo) { $0.decision = .pending; $0.sensitivityState = .normal; $0.sensitiveApprovedAt = nil; $0.excludedReason = nil } }
    private func setSensitive(_ photo: ArchivePhoto) { update(photo) { $0.decision = .pending; $0.sensitivityState = .sensitive; $0.sensitiveApprovedAt = nil; $0.excludedReason = nil } }
    private func setNeverUse(_ photo: ArchivePhoto) { update(photo) { $0.decision = .excluded; $0.decisionSource = .human; $0.staleDecision = nil; $0.sensitivityState = .neverUse; $0.sensitiveApprovedAt = nil; $0.excludedReason = .neverUse } }
    private func setExcluded(_ photo: ArchivePhoto, reason: PhotoExcludedReason) { update(photo) { value in if let generation = activeGenerationID, value.decisionSource != .manualImport { value.reconfirm(.excluded, generationID: generation) } else { value.decision = .excluded; value.staleDecision = nil }; value.sensitivityState = .normal; value.sensitiveApprovedAt = nil; value.excludedReason = reason } }
    private func update(_ photo: ArchivePhoto, _ mutation: (inout ArchivePhoto) -> Void) { guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }; mutation(&photos[index]) }
    private func toggleQuickSelection(_ id: UUID) { if quickSelection.contains(id) { quickSelection.remove(id) } else { quickSelection.insert(id) } }
    private func includeQuickSelection() {
        let visibleIDs = Set(filtered.map(\.id))
        let approvedIDs = quickSelection.intersection(visibleIDs)
        guard !approvedIDs.isEmpty else { return }
        for index in photos.indices where approvedIDs.contains(photos[index].id) {
            if let generation = activeGenerationID, photos[index].decisionSource != .manualImport {
                photos[index].reconfirm(.selected, generationID: generation)
            } else {
                photos[index].decision = .selected
                photos[index].staleDecision = nil
            }
            photos[index].sensitivityState = .normal
            photos[index].excludedReason = nil
        }
        quickSelection.removeAll()
        isQuickSelecting = false
    }
}

private struct SensitivePhotoApprovalSheet: View {
    let name: String
    let photo: ArchivePhoto
    let include: () -> Void
    let exclude: () -> Void
    let cancel: () -> Void
    @State private var acknowledged = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                PhotoAssetThumbnail(identifier: photo.assetLocalIdentifier)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Label("Sensitive · not included", systemImage: "hand.raised.fill")
                    .font(.headline).foregroundStyle(TailorColor.clay)
                Text("Tailor keeps this photo out unless you explicitly include it. Review it at your own pace; no sensitive photo is added automatically.")
                    .foregroundStyle(TailorColor.secondaryInk)
                Toggle("I want this photo of \(name) included in the archive.", isOn: $acknowledged)
                    .tint(TailorColor.ink)
                TailorPrimaryButton(title: "Include this photo", disabled: !acknowledged, action: include)
                Button("Keep it out", role: .destructive, action: exclude).frame(maxWidth: .infinity)
                Spacer()
            }
            .padding(24)
            .background(TailorColor.paper.ignoresSafeArea())
            .navigationTitle("Review sensitive photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel) } }
        }
    }
}

struct SmartDraftFeatureView: View {
    let summary: MemoryBookDraftSummary
    let isPreparing: Bool
    let errorMessage: String?
    let continueToStory: () -> Void
    let retry: () -> Void
    let useSimpleTimeline: () -> Void
    let continueLater: () -> Void
    let back: () -> Void

    var body: some View {
        TailorScreen(eyebrow: "SMART DRAFT", title: isPreparing ? "Building a first draft." : "A story is ready to shape.", back: back) {
            Text("Tailor is arranging only the photographs you approved. Nothing is uploaded and no memory is invented.")
                .foregroundStyle(TailorColor.secondaryInk)
            VStack(spacing: 10) {
                metric("Selected photos", value: summary.selectedPhotoCount, symbol: "photo.on.rectangle.angled")
                metric("Time-based events", value: summary.eventCount, symbol: "calendar")
                metric("Near-duplicates set aside", value: summary.duplicateCount, symbol: "square.on.square.dashed")
                metric("Estimated pages", value: summary.estimatedPageCount, symbol: "book.pages")
            }
            .padding(.vertical, 8)
            if isPreparing {
                VStack(alignment: .leading, spacing: 12) {
                    ProgressView()
                    Label("Choosing hero moments and a balanced page rhythm…", systemImage: "wand.and.stars")
                        .font(.footnote.weight(.semibold))
                }
                .padding(16)
                .background(TailorColor.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                TailorInfoCard(symbol: "checkmark.seal", title: "Story plan ready", message: "This draft saves the proposed chapters and photo assignments. MemoryBook pages are created only after you choose a style, and every page stays editable.")
            }
            if let errorMessage {
                TailorInfoCard(symbol: "exclamationmark.triangle", title: "We couldn’t finish the smart draft", message: errorMessage)
                HStack { Button("Try again", action: retry); Spacer(); Button("Use simple timeline", action: useSimpleTimeline) }
                    .font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                TailorPrimaryButton(title: isPreparing ? "Preparing your story…" : "Continue to story", disabled: isPreparing || errorMessage != nil, action: continueToStory)
                Button("Continue later", action: continueLater).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay)
            }
            .padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper)
        }
    }

    private func metric(_ title: String, value: Int, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).frame(width: 28).foregroundStyle(TailorColor.clay)
            Text(title).font(.callout.weight(.semibold))
            Spacer()
            Text(value.formatted()).font(.title3.weight(.bold)).foregroundStyle(TailorColor.ink)
        }
        .padding(14).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct BookStyleFeatureView: View {
    @Binding var style: AlbumStyle
    @Binding var pageSize: PDFPageSize
    let book: MemoryBookDocument?
    let isApplying: Bool
    let errorMessage: String?
    let apply: (MemoryBookTemplateApplicationMode) -> Void
    let continueLater: () -> Void
    let back: () -> Void
    @State private var mode: MemoryBookTemplateApplicationMode = .rearrangeUnlocked

    var body: some View {
        TailorScreen(eyebrow: "BOOK STYLE", title: "Choose how the story feels.", back: back) {
            Text("Each style changes typography, image density, page recipes and chapter rhythm—not only color.")
                .foregroundStyle(TailorColor.secondaryInk)
            ForEach(AlbumStyle.allCases, id: \.self) { choice in
                Button { style = choice } label: {
                    HStack(spacing: 14) {
                        stylePreview(choice).frame(width: 86, height: 112)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(choice.displayName).font(.headline).foregroundStyle(TailorColor.ink)
                            Text(description(choice)).font(.footnote).foregroundStyle(TailorColor.secondaryInk).multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: style == choice ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(style == choice ? TailorColor.clay : TailorColor.secondaryInk)
                    }
                    .padding(12)
                    .background(style == choice ? TailorColor.mist.opacity(0.65) : TailorColor.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(style == choice ? TailorColor.clay : TailorColor.mist, lineWidth: style == choice ? 2 : 1))
                }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("PAPER SIZE").font(.caption.weight(.bold)).tracking(1).foregroundStyle(TailorColor.secondaryInk)
                Picker("Paper size", selection: $pageSize) {
                    Text("US Letter").tag(PDFPageSize.letter)
                    Text("A4").tag(PDFPageSize.a4)
                }.pickerStyle(.segmented)
                Text(pageSize == .letter ? "Recommended for the United States." : "International A4 print size.")
                    .font(.footnote).foregroundStyle(TailorColor.secondaryInk)
            }
            .padding(16).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 16))
            TailorInfoCard(symbol: "doc.badge.gearshape", title: "One first revision", message: "Your confirmed story, template and paper size are saved together. No document is created until this transaction succeeds.")
            if let errorMessage {
                TailorInfoCard(symbol: "exclamationmark.triangle", title: "The first draft wasn’t created", message: errorMessage)
            }
            if let book {
                VStack(alignment: .leading, spacing: 10) {
                    Text("APPLY SAFELY").font(.caption.weight(.bold)).tracking(1).foregroundStyle(TailorColor.secondaryInk)
                    Picker("Application", selection: $mode) {
                        Text("Visual style only").tag(MemoryBookTemplateApplicationMode.visualOnly)
                        Text("Rearrange unlocked pages").tag(MemoryBookTemplateApplicationMode.rearrangeUnlocked)
                    }.pickerStyle(.segmented)
                    let summary = book.templateApplicationSummary(style: style, mode: mode)
                    Text(mode == .visualOnly
                         ? "Updates the look of all \(summary.affectedPageCount) pages without moving an element."
                         : "Rearranges \(summary.affectedPageCount) untouched pages. \(summary.protectedPageCount) edited pages stay exactly as they are.")
                        .font(.footnote).foregroundStyle(TailorColor.secondaryInk)
                }
                .padding(16).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                TailorPrimaryButton(title: isApplying ? "Creating first draft…" : (errorMessage == nil ? (book == nil ? "Create first draft" : "Apply \(style.displayName)") : "Try creating again"), disabled: isApplying, action: { apply(book == nil ? .rearrangeUnlocked : mode) })
                Button("Save for later", action: continueLater).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay)
            }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper)
        }
    }

    @ViewBuilder private func stylePreview(_ choice: AlbumStyle) -> some View {
        let palette = MemoryBookPageStyle.resolve(choice)
        ZStack {
            Color(red: palette.paper.red, green: palette.paper.green, blue: palette.paper.blue)
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: choice == .filmAlbum ? 1 : 4)
                    .fill(Color(red: palette.accent.red, green: palette.accent.green, blue: palette.accent.blue).opacity(0.72))
                    .frame(height: choice == .cinema ? 62 : 38)
                    .rotationEffect(choice == .filmAlbum ? .degrees(-3) : .zero)
                HStack(spacing: 4) { ForEach(0..<(choice == .fieldNotes ? 3 : 2), id: \.self) { _ in Rectangle().fill(Color(red: palette.ink.red, green: palette.ink.green, blue: palette.ink.blue).opacity(0.28)).frame(height: 13) } }
            }.padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    private func description(_ style: AlbumStyle) -> String {
        switch style {
        case .warmPaper: "Generous cream space, quiet hero images and terracotta dates."
        case .quietNight: "Deep green pages, fewer photographs and a focused night-reading pace."
        case .fieldNotes: "Dates, dividers and denser documentary sequences."
        case .cinema: "Full-frame, low-saturation moments with subtitle-like typography."
        case .filmAlbum: "Photo-print borders, gentle overlap and handwritten details."
        }
    }
}

private extension AlbumStyle {
    var displayName: String {
        switch self {
        case .warmPaper: "Warm Paper"
        case .quietNight: "Quiet Night"
        case .fieldNotes: "Field Notes"
        case .cinema: "Cinema"
        case .filmAlbum: "Film Album"
        }
    }
}

struct TimelineFeatureView: View {
    let name: String; @Binding var chapters: [Chapter]; let photos: [ArchivePhoto]; let edit: (UUID) -> Void; let next: () -> Void; let continueLater: () -> Void; let back: () -> Void
    @State private var pendingMerge: MergeRequest?
    @State private var pendingSplit: SplitRequest?
    @State private var lastImpactMessage: String?
    private struct MergeRequest: Identifiable { let id = UUID(); let firstID: UUID; let secondID: UUID; let firstTitle: String; let secondTitle: String; let photoCount: Int }
    private struct SplitRequest: Identifiable { let id = UUID(); let chapterID: UUID; let title: String; let splitIndex: Int; let firstCount: Int; let secondCount: Int }
    private var photoLookup: [UUID: ArchivePhoto] { Dictionary(uniqueKeysWithValues: photos.filter(\.isEligibleForArchive).map { ($0.id, $0) }) }
    var body: some View { TailorScreen(eyebrow: "STORY PLAN", title: "\(name)’s life, in moments.", back: back) {
        Text("Made from the photos you chose. Shape the chapters before Tailor lays out the pages.").foregroundStyle(TailorColor.ink.opacity(0.72))
        VStack(alignment: .leading, spacing: 0) { ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
            HStack(alignment: .top, spacing: 14) { VStack(spacing: 0) { Circle().fill(TailorColor.clay).frame(width: 10, height: 10); Rectangle().fill(TailorColor.mist).frame(width: 2).frame(maxHeight: .infinity).padding(.top, 4) }.frame(width: 20)
                VStack(alignment: .leading, spacing: 6) { Text(chapter.dateLabel).font(.caption.weight(.bold)).foregroundStyle(TailorColor.clay); Button(action: { edit(chapter.id) }) { HStack(spacing: 12) { Group { if !chapter.isHidden, let cover = chapter.photoIDs.first.flatMap({ photoLookup[$0] }) { PhotoAssetThumbnail(identifier: cover.assetLocalIdentifier) } else { Image(systemName: chapter.isHidden ? "eye.slash" : "photo").frame(maxWidth: .infinity, maxHeight: .infinity).foregroundStyle(TailorColor.ink.opacity(0.65)) } }.frame(width: 72, height: 72).background(TailorColor.mist).clipShape(RoundedRectangle(cornerRadius: 20)); VStack(alignment: .leading, spacing: 3) { Text(chapter.title).font(.callout.weight(.bold)).foregroundStyle(TailorColor.ink); Text(chapter.isHidden ? "Hidden from album" : "\(chapter.photoIDs.filter { photoLookup[$0] != nil }.count) selected photos").font(.footnote).foregroundStyle(TailorColor.ink.opacity(0.68)); if chapter.needsReflow { Label("Pages need review", systemImage: "arrow.triangle.2.circlepath").font(.caption2.weight(.bold)).foregroundStyle(TailorColor.clay) } }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(TailorColor.ink) }.padding(14).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.mist, lineWidth: 1)) }.buttonStyle(.plain).opacity(chapter.isHidden ? 0.5 : 1).contextMenu { Button(chapter.isHidden ? "Show in album" : "Hide from album", systemImage: chapter.isHidden ? "eye" : "eye.slash") { toggleVisibility(chapter.id) }; Button("Edit chapter", systemImage: "pencil") { edit(chapter.id) } }
                    HStack(spacing: 10) {
                        if index > 0 { Button("Earlier", systemImage: "arrow.up") { moveChapter(chapter.id, .earlier) } }
                        if index < chapters.count - 1 { Button("Later", systemImage: "arrow.down") { moveChapter(chapter.id, .later) } }
                        if index < chapters.count - 1 {
                            Button("Merge next", systemImage: "arrow.triangle.merge") { requestMergeWithNext(chapter.id) }
                                .accessibilityIdentifier("Merge chapter \(index + 1) with next")
                        }
                        if chapter.photoIDs.count > 1 {
                            Menu("Split", systemImage: "scissors") {
                                ForEach(1..<chapter.photoIDs.count, id: \.self) { splitIndex in
                                    Button("After photo \(splitIndex) · \(splitIndex) + \(chapter.photoIDs.count - splitIndex)") { requestSplit(chapter.id, at: splitIndex) }
                                }
                            }
                            .accessibilityIdentifier("Split chapter \(index + 1)")
                        }
                    }
                    .font(.caption.weight(.bold)).foregroundStyle(TailorColor.clay)
                }.padding(.bottom, index == chapters.count - 1 ? 0 : 18) }
        } }
        if let lastImpactMessage {
            TailorInfoCard(symbol: "arrow.triangle.2.circlepath", title: "Story updated", message: lastImpactMessage)
                .accessibilityIdentifier("Story plan impact summary")
        }
        Text("When dates do not establish a story, use neutral titles such as “2018–2020” or “Days together.”").font(.caption).foregroundStyle(TailorColor.ink.opacity(0.65)).padding(.top, 6)
    }.safeAreaInset(edge: .bottom) { VStack(spacing: 8) { TailorPrimaryButton(title: "Choose book style", action: next); Button("Save for later", action: continueLater).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) }
        .confirmationDialog("Merge neighboring chapters?", isPresented: Binding(get: { pendingMerge != nil }, set: { if !$0 { pendingMerge = nil } })) {
            Button("Merge as one chapter") { applyPendingMerge() }
            Button("Cancel", role: .cancel) { pendingMerge = nil }
        } message: {
            if let request = pendingMerge { Text("\(request.firstTitle) and \(request.secondTitle) contain \(request.photoCount) photos. Photo order is preserved; affected unlocked pages will be marked for review and locked pages stay unchanged.") }
        }
        .confirmationDialog("Split this chapter?", isPresented: Binding(get: { pendingSplit != nil }, set: { if !$0 { pendingSplit = nil } })) {
            Button("Split into two chapters") { applyPendingSplit() }
            Button("Cancel", role: .cancel) { pendingSplit = nil }
        } message: {
            if let request = pendingSplit { Text("Split \(request.title) after photo \(request.splitIndex): \(request.firstCount) photos stay here and \(request.secondCount) move to a new chapter. Affected unlocked pages will need layout review; locked pages stay unchanged.") }
        }
    }
    private func toggleVisibility(_ id: UUID) { guard let index = chapters.firstIndex(where: { $0.id == id }) else { return }; chapters[index].isHidden.toggle() }
    private func requestMergeWithNext(_ id: UUID) {
        guard let index = chapters.firstIndex(where: { $0.id == id }), chapters.indices.contains(index + 1) else { return }
        let next = chapters[index + 1]
        pendingMerge = MergeRequest(firstID: id, secondID: next.id, firstTitle: chapters[index].title, secondTitle: next.title, photoCount: chapters[index].photoIDs.count + next.photoIDs.count)
    }
    private func requestSplit(_ id: UUID, at splitIndex: Int) {
        guard let chapter = chapters.first(where: { $0.id == id }), splitIndex > 0, splitIndex < chapter.photoIDs.count else { return }
        pendingSplit = SplitRequest(chapterID: id, title: chapter.title, splitIndex: splitIndex, firstCount: splitIndex, secondCount: chapter.photoIDs.count - splitIndex)
    }
    private func applyPendingMerge() {
        guard let request = pendingMerge else { return }
        if StoryPlanMutation.mergeAdjacent(&chapters, firstID: request.firstID, secondID: request.secondID) {
            lastImpactMessage = "The two neighboring chapters were merged without losing or duplicating photos. Affected unlocked pages are marked for review; locked pages remain unchanged."
        }
        pendingMerge = nil
    }
    private func applyPendingSplit() {
        guard let request = pendingSplit else { return }
        if StoryPlanMutation.split(&chapters, chapterID: request.chapterID, atPhotoIndex: request.splitIndex) {
            lastImpactMessage = "The chapter was split at the chosen photo boundary. Both chapters keep their exact photo order; affected unlocked pages are marked for review."
        }
        pendingSplit = nil
    }
    private func moveChapter(_ id: UUID, _ direction: StoryPlanMutation.MoveDirection) {
        if StoryPlanMutation.move(&chapters, chapterID: id, direction: direction) {
            lastImpactMessage = "The chapter order changed. Affected unlocked pages are marked for review; locked pages remain unchanged."
        }
    }
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
