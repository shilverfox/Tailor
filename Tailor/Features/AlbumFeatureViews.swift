import SwiftUI
import UIKit

private struct TextDraftHighlight: Equatable {
    let pageID: UUID
    let elementID: UUID
    let isInvalid: Bool
}

/// The product editor. This is intentionally distinct from reading preview: its
/// canvas edits the persisted MemoryBookDocument rather than a temporary view model.
struct AlbumEditorFeatureView: View {
    @Binding var memoryBook: MemoryBookDocument?
    let purchased: Bool
    let back: () -> Void
    let preview: () -> Void
    let export: () -> Void
    let persist: () -> Void

    @State private var selectedPageID: UUID?
    @State private var selectedElementID: UUID?
    @State private var textEditorTarget: TextEditorTarget?
    @State private var panel: EditorPanel = .pages
    @State private var showPageManager = false
    @State private var showPhotoPicker = false
    @State private var showStylePicker = false
    @State private var showLayoutPicker = false
    @State private var cropTarget: CropTarget?
    @State private var layoutChange: LayoutChangeTarget?
    @State private var layoutUnavailableMessage: String?
    @State private var showIssues = false
    @State private var pendingBookCheckIssue: MemoryBookIssue?
    @State private var autoArrangeScope: AutoArrangeScope?
    @State private var undoStack: [MemoryBookDocument] = []
    @State private var redoStack: [MemoryBookDocument] = []
    @State private var textDraftHighlight: TextDraftHighlight?
    @StateObject private var photoAvailability = PhotoAssetAvailabilityMonitor()

    init(memoryBook: Binding<MemoryBookDocument?>, purchased: Bool, back: @escaping () -> Void, preview: @escaping () -> Void, export: @escaping () -> Void, persist: @escaping () -> Void) {
        self._memoryBook = memoryBook
        self.purchased = purchased
        self.back = back
        self.preview = preview
        self.export = export
        self.persist = persist
        // Establish the selected page before the first body pass whenever the
        // document is already restored. This removes the visible unselected
        // first-frame flash in the thumbnail rail.
        self._selectedPageID = State(initialValue: memoryBook.wrappedValue?.pages.first?.id)
    }

    private enum EditorPanel { case pages, layout, photo, text, style }
    private struct CropTarget: Identifiable { let id = UUID(); let pageID: UUID; let elementID: UUID }
    private struct TextEditorTarget: Identifiable { let id = UUID(); let pageID: UUID?; let elementID: UUID?; let field: MemoryBookTextField? }
    private struct LayoutChangeTarget: Identifiable { let id = UUID(); let pageID: UUID; let layout: MemoryBookLayout }
    private enum AutoArrangeScope: String, Identifiable {
        case page, chapter, book
        var id: String { rawValue }
        var title: String {
            switch self {
            case .page: "This page"
            case .chapter: "This chapter"
            case .book: "Entire book"
            }
        }
    }

    var body: some View {
        // Redraw immediately when an asset is deleted or Photos access changes.
        let _ = photoAvailability.revision
        Group {
            if let book = memoryBook, let pageID = selectedPageID ?? book.pages.first?.id, let index = book.pages.firstIndex(where: { $0.id == pageID }) {
                editor(book: book, pageIndex: index)
            } else {
                TailorScreen(eyebrow: "EDITOR", title: "Opening your book…", back: back) { ProgressView().frame(maxWidth: .infinity, minHeight: 240) }
            }
        }
        // A Crop session is modal.  Keeping the editor underneath visible in
        // the accessibility tree lets VoiceOver/XCTest reach page controls
        // that are visually covered by the full-screen stage.  Hide only the
        // presenting editor (the cover is attached by the modifiers below),
        // so Crop owns the sole actionable surface until it is finished or
        // discarded.
        .accessibilityHidden(cropTarget != nil)
        .onAppear {
            // Documents created before the proportional-fit migration may
            // still carry template-sized image boxes. Repair them once when
            // the editor opens, then persist the corrected composition.
            if var book = memoryBook, book.normalizeFitImageFramesToAssetAspect() {
                memoryBook = book
                persist()
            }
            if selectedPageID == nil {
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "-uiFixturePage"), arguments.indices.contains(index + 1), let requested = UUID(uuidString: arguments[index + 1]), memoryBook?.pages.contains(where: { $0.id == requested }) == true { selectedPageID = requested }
                else { selectedPageID = memoryBook?.pages.first?.id }
            }
        }
        .sheet(isPresented: $showPageManager) { PageManagerSheet(book: documentBinding, selectedPageID: $selectedPageID, recordHistory: recordHistory, commit: commit) }
        .sheet(isPresented: $showPhotoPicker) { PhotoPickerSheet(book: documentBinding, selectedPageID: selectedPageID, selectedElementID: selectedElementID, requestCrop: { pageID, elementID in cropTarget = CropTarget(pageID: pageID, elementID: elementID) }, recordHistory: recordHistory, commit: commit) }
        .sheet(item: $textEditorTarget, onDismiss: { textDraftHighlight = nil }) { target in TextEditorSheet(book: documentBinding, selectedPageID: target.pageID, selectedElementID: target.elementID, initialField: target.field, draftHighlight: $textDraftHighlight, recordHistory: recordHistory, commit: commit) }
        .sheet(isPresented: $showStylePicker) { StylePickerSheet(book: documentBinding, selectedPageID: selectedPageID, recordHistory: recordHistory, commit: commit) }
        .sheet(isPresented: $showLayoutPicker) { LayoutPickerSheet(book: documentBinding, selectedPageID: selectedPageID, choose: { layout in layoutChange = LayoutChangeTarget(pageID: selectedPageID ?? UUID(), layout: layout) }) }
        // Read through the live binding when the sheet appears. Capturing the
        // value from the header can otherwise show an old Book Check result
        // after an editor mutation and before SwiftUI has rebuilt that header.
        .sheet(isPresented: $showIssues, onDismiss: presentPendingBookCheckIssue) { BookCheckSheet(book: documentBinding, assetIsAvailable: PhotoAssetAvailability.isAvailable, selectIssue: openBookCheckIssue) }
        .confirmationDialog("Auto arrange", isPresented: Binding(get: { autoArrangeScope != nil }, set: { if !$0 { autoArrangeScope = nil } })) {
            Button("Arrange unlocked pages") { performAutoArrange() }
            Button("Cancel", role: .cancel) { autoArrangeScope = nil }
        } message: {
            Text(autoArrangeMessage)
        }
        .confirmationDialog("Change layout", isPresented: Binding(get: { layoutChange != nil }, set: { if !$0 { layoutChange = nil } })) {
            Button("Apply layout") { applyLayoutChange() }
            Button("Keep current layout") { layoutChange = nil }
        } message: {
            Text(layoutChangeMessage)
        }
        .alert("Layout", isPresented: Binding(get: { layoutUnavailableMessage != nil }, set: { if !$0 { layoutUnavailableMessage = nil } })) {
            Button("OK") { layoutUnavailableMessage = nil }
        } message: {
            Text(layoutUnavailableMessage ?? "")
        }
        .fullScreenCover(item: $cropTarget, onDismiss: { cropTarget = nil }) { target in
            CropEditorSheet(book: documentBinding, pageID: target.pageID, elementID: target.elementID, recordHistory: recordHistory, commit: commit)
        }
    }

    private func editor(book: MemoryBookDocument, pageIndex: Int) -> some View {
        let page = book.pages[pageIndex]
        let usesSafetyFixtureWatermark = ProcessInfo.processInfo.arguments.contains("-uiTesting")
            && ProcessInfo.processInfo.arguments.contains("text-safe-drag")
        return ZStack {
            Color(red: 0.07, green: 0.16, blue: 0.13).ignoresSafeArea()
            VStack(spacing: 0) {
                editorHeader(book: book, page: page)
                Spacer(minLength: 12)
                EditorBookPageCanvas(page: pageBinding(pageIndex), document: book, selectedElementID: $selectedElementID, textDraftHighlight: $textDraftHighlight, editing: true, watermarked: usesSafetyFixtureWatermark, isPhotoAvailable: PhotoAssetAvailability.isAvailable, replaceMissingPhoto: { elementID in
                    selectedElementID = elementID
                    showPhotoPicker = true
                }, beginEdit: recordHistory, endEdit: commit)
                    .aspectRatio(book.pageSize == .a4 ? 595 / 842 : 612 / 792, contentMode: .fit)
                    .padding(.horizontal, 28)
                Spacer(minLength: 12)
                ThumbnailRail(pages: book.pages, selectedPageID: $selectedPageID)
                editorToolbar(page: page)
            }
        }
    }

    private func editorHeader(book: MemoryBookDocument, page: MemoryBookPage) -> some View {
        HStack(spacing: 14) {
            Button(action: back) { Image(systemName: "chevron.left") }
            Spacer()
            Text("\(page.pageNumber) of \(book.pages.count)").font(.footnote.weight(.semibold)).foregroundStyle(.white)
            Spacer()
            Button(action: undo) { Image(systemName: "arrow.uturn.backward") }.disabled(undoStack.isEmpty).accessibilityIdentifier("Editor undo").accessibilityLabel("Undo")
            Button(action: redo) { Image(systemName: "arrow.uturn.forward") }.disabled(redoStack.isEmpty).accessibilityIdentifier("Editor redo").accessibilityLabel("Redo")
            Menu {
                Menu("Auto arrange") {
                    Button("This page") { autoArrangeScope = .page }
                    Button("This chapter") { autoArrangeScope = .chapter }
                    Button("Entire book") { autoArrangeScope = .book }
                }
                Button("Check book") { showIssues = true }
                Button("Reading preview", action: preview)
                Button("Export PDF") {
                    let blockers = book.checkBook(assetIsAvailable: PhotoAssetAvailability.isAvailable).filter { $0.severity == .blocking }
                    if blockers.isEmpty { export() } else { showIssues = true }
                }
            } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("More editor actions")
        }
        .font(.title3.weight(.semibold)).foregroundStyle(.white).padding(.horizontal, 20).padding(.vertical, 14)
    }

    private func editorToolbar(page: MemoryBookPage) -> some View {
        HStack(spacing: 0) {
            tool("square.on.square", "Pages") { showPageManager = true }
            tool("rectangle.3.group", "Layout") {
                if canChangeLayout(page) { showLayoutPicker = true }
                else { layoutUnavailableMessage = "Layouts can be changed on a photo page. Select a photo collection page to arrange its images." }
            }
            tool("photo", "Photo") {
                // Opening Photo without a canvas selection should still offer
                // a deterministic edit target instead of an empty tool sheet.
                // A deliberate canvas selection always wins.
                if selectedElementID == nil {
                    selectedElementID = page.elements.first(where: { $0.kind == .image })?.id
                    // Present on the next run-loop turn so the sheet receives
                    // the newly selected binding instead of the old nil value.
                    DispatchQueue.main.async { showPhotoPicker = true }
                } else {
                    showPhotoPicker = true
                }
            }
            tool("textformat", "Text") { textEditorTarget = TextEditorTarget(pageID: selectedPageID, elementID: selectedElementID, field: nil) }
            tool("paintpalette", "Style") { showStylePicker = true }
        }
        .padding(.top, 8).padding(.bottom, 20).background(.ultraThinMaterial)
    }

    private func canChangeLayout(_ page: MemoryBookPage) -> Bool {
        !page.isLocked && page.kind == .photoSelection && page.layout.canonical != .note && page.elements.contains(where: { $0.kind == .image })
    }

    private func tool(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 5) { Image(systemName: icon); Text(title).font(.caption2) }.frame(maxWidth: .infinity, minHeight: 54) }
            .foregroundStyle(.white)
            .accessibilityLabel(title)
    }

    private var documentBinding: Binding<MemoryBookDocument> { Binding(get: { memoryBook! }, set: { memoryBook = $0; persist() }) }
    private func pageBinding(_ index: Int) -> Binding<MemoryBookPage> { Binding(get: { documentBinding.wrappedValue.pages[index] }, set: { value in var document = documentBinding.wrappedValue; document.pages[index] = value; document.updatedAt = .now; documentBinding.wrappedValue = document }) }

    private func recordHistory() {
        guard let memoryBook else { return }
        if undoStack.last != memoryBook { undoStack.append(memoryBook); if undoStack.count > 50 { undoStack.removeFirst() } }
        redoStack.removeAll()
    }
    private func commit() { if var book = memoryBook { book.updatedAt = .now; memoryBook = book; persist() } }
    private func mutate(_ change: (inout MemoryBookDocument) -> Void) { guard var book = memoryBook else { return }; change(&book); memoryBook = book; persist() }
    private func undo() {
        guard let previous = undoStack.popLast(), let current = memoryBook else { return }
        let activePageID = selectedPageID
        redoStack.append(current)
        memoryBook = previous
        // History changes the document, not the reader's place in it. This
        // matters especially for Crop: switching to cover page after Undo
        // makes Redo appear to have lost the committed transform.
        selectedPageID = previous.pages.contains(where: { $0.id == activePageID }) ? activePageID : previous.pages.first?.id
        persist()
    }

    private func redo() {
        guard let next = redoStack.popLast(), let current = memoryBook else { return }
        let activePageID = selectedPageID
        undoStack.append(current)
        memoryBook = next
        selectedPageID = next.pages.contains(where: { $0.id == activePageID }) ? activePageID : next.pages.first?.id
        persist()
    }

    private func openBookCheckIssue(_ issue: MemoryBookIssue) {
        if let pageID = issue.pageID { selectedPageID = pageID }
        selectedElementID = issue.elementID
        pendingBookCheckIssue = issue
        showIssues = false
    }

    private func presentPendingBookCheckIssue() {
        guard let issue = pendingBookCheckIssue else { return }
        pendingBookCheckIssue = nil
        // A text blocker must land in its actual semantic field, not merely on
        // the page that contains it.  Waiting for Book Check's dismissal also
        // lets SwiftUI propagate the new page/element binding before the text
        // sheet reads it; one run-loop hop was not sufficient on device.
        guard issue.field != nil, issue.elementID != nil else { return }
        DispatchQueue.main.async { textEditorTarget = TextEditorTarget(pageID: issue.pageID, elementID: issue.elementID, field: issue.field) }
    }

    private var autoArrangeMessage: String {
        guard let scope = autoArrangeScope, let book = memoryBook else { return "" }
        let selectedIDs = autoArrangePageIDs(scope, book: book)
        let editable = book.pages.filter { selectedIDs.contains($0.id) && !$0.isLocked }
        let locked = selectedIDs.count - editable.count
        let pageWord = editable.count == 1 ? "page" : "pages"
        let lockedNote = locked == 0 ? "" : " \(locked) locked page\(locked == 1 ? "" : "s") will stay unchanged."
        return "This will arrange \(editable.count) unlocked \(pageWord) in \(scope.title.lowercased()). Your moved, cropped, replaced, and text elements stay unchanged.\(lockedNote)"
    }

    private func autoArrangePageIDs(_ scope: AutoArrangeScope, book: MemoryBookDocument) -> Set<UUID> {
        guard let currentID = selectedPageID ?? book.pages.first?.id,
              let page = book.pages.first(where: { $0.id == currentID }) else { return [] }
        switch scope {
        case .page: return [page.id]
        case .chapter:
            return Set(book.pages.filter { $0.chapterID == page.chapterID }.map(\.id))
        case .book: return Set(book.pages.map(\.id))
        }
    }

    private func performAutoArrange() {
        guard let scope = autoArrangeScope, let book = memoryBook else { return }
        let ids = autoArrangePageIDs(scope, book: book)
        autoArrangeScope = nil
        guard !ids.isEmpty else { return }
        recordHistory()
        mutate { $0.autoArrange(pageIDs: ids) }
    }

    private var layoutChangeMessage: String {
        guard let target = layoutChange, let summary = memoryBook?.layoutChangeSummary(pageID: target.pageID, layout: target.layout) else { return "" }
        return summary.message
    }

    private func applyLayoutChange() {
        guard let target = layoutChange else { return }
        layoutChange = nil
        recordHistory()
        mutate { _ = $0.applyLayoutChange(pageID: target.pageID, layout: target.layout) }
    }
}

private struct EditorBookPageCanvas: View {
    @Binding var page: MemoryBookPage
    let document: MemoryBookDocument
    @Binding var selectedElementID: UUID?
    @Binding var textDraftHighlight: TextDraftHighlight?
    let editing: Bool
    let watermarked: Bool
    var isPhotoAvailable: (ArchivePhoto) -> Bool = PhotoAssetAvailability.isAvailable
    var replaceMissingPhoto: ((UUID) -> Void)? = nil
    let beginEdit: () -> Void
    let endEdit: () -> Void
    @State private var startFrame: CGRect?
    @State private var startImageFrame: CGRect?
    @State private var startRotation: Double?
    @State private var textRotationStartAngle: Double?

    private var canvasCoordinateSpace: String { "MemoryBookPageCanvas-\(page.id.uuidString)" }
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                let plan = MemoryBookPageRenderPlan(page: page, document: document, pageSize: proxy.size, watermarked: watermarked)
                RoundedRectangle(cornerRadius: 5).fill(color(plan.style.backdrop))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color(plan.style.paper))
                    .frame(width: plan.paperRect.width, height: plan.paperRect.height)
                    .position(x: plan.paperRect.midX, y: plan.paperRect.midY)
                // Texture is a PageStyle contract, not an editor-only
                // embellishment.  The reader uses this same canvas and the
                // PDF renderer reads the same descriptor below.
                if let texture = plan.style.texture {
                    Image(texture.assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: plan.paperRect.width, height: plan.paperRect.height)
                        .opacity(texture.opacity)
                        .clipped()
                        .position(x: plan.paperRect.midX, y: plan.paperRect.midY)
                        .allowsHitTesting(false)
                }
                ForEach(plan.orderedElements) { element in
                    elementView(element, plan: plan)
                }
                if let frame = plan.filmFrameRect(),
                   let lineWidth = plan.filmFrameLineWidth(),
                   let dash = plan.filmFrameDash(),
                   let cornerRadius = plan.filmFrameCornerRadius() {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(color(plan.style.accent), style: StrokeStyle(lineWidth: lineWidth, dash: dash))
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .allowsHitTesting(false)
                }
                watermarkView(plan)
                // Preserve the existing canvas diagnostic as its own element.
                // Attaching this identifier to the full GeometryReader makes
                // UIKit merge and overwrite child identifiers on iOS 26.
                TailorColor.paper.opacity(0.01)
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("Editor page canvas")
                    .accessibilityLabel("Editor page canvas")
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .coordinateSpace(name: canvasCoordinateSpace)
            .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
        }
    }

    @ViewBuilder private func watermarkView(_ plan: MemoryBookPageRenderPlan) -> some View {
        if let watermark = plan.watermark,
           let fontSize = plan.watermarkFontSize(),
           let letterSpacing = plan.watermarkLetterSpacing() {
            ForEach(Array(plan.watermarkCenters().enumerated()), id: \.offset) { _, center in
                Text(watermark.text)
                    .font(.system(size: fontSize, weight: .bold))
                    .tracking(letterSpacing)
                    .foregroundStyle(color(plan.style.accent).opacity(watermark.opacity))
                    .rotationEffect(.degrees(watermark.rotationDegrees))
                    .position(center)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder private func elementView(_ element: MemoryBookElement, plan: MemoryBookPageRenderPlan) -> some View {
        let frame = plan.rect(for: element.normalizedFrame)
        switch element.kind {
        case .text:
            if let textLayout = plan.textLayout(for: element) {
                MemoryBookAttributedTextPreview(
                    snapshot: textLayout,
                    color: uiColor(element.textCustomColor ?? element.textColor.rgb(fallback: plan.fontToken(for: element) == .display ? plan.style.ink : plan.style.secondary))
                )
                .frame(width: frame.width, height: frame.height, alignment: .leading)
                // UIKit only paints the shared B1 attributed paragraph. The
                // editor interaction lives on this SwiftUI overlay so it has
                // a stable, real accessibility frame for VoiceOver/XCTest.
                .allowsHitTesting(false)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(textDraftHighlight?.pageID == page.id && textDraftHighlight?.elementID == element.id && textDraftHighlight?.isInvalid == true ? .red : (selectedElementID == element.id && editing ? TailorColor.clay : .clear), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                .overlay {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(dragGesture(element, size: plan.pageSize, plan: plan))
                        .onTapGesture { if editing { selectedElementID = element.id } }
                        .allowsHitTesting(editing)
                        // This document-derived marker is intentionally
                        // attached to the interaction surface, not UIKit.
                        .accessibilityIdentifier("Text element \(element.textField?.rawValue ?? "unassigned")")
                        .accessibilityLabel(selectedElementID == element.id ? "Selected text element" : "Text element")
                        .accessibilityValue(memoryBookTextFrameMarker(element, layout: textLayout, paperRect: plan.paperRect))
                }
                .overlay(alignment: .bottomTrailing) {
                    if selectedElementID == element.id && editing {
                        TextRotationHandle()
                            .offset(x: 12, y: 12)
                            .gesture(textRotationHandleGesture(element, frame: frame))
                            .accessibilityLabel("Rotate selected text")
                            .accessibilityHint("Drag around the text to rotate it.")
                    }
                }
                .rotationEffect(.degrees(element.rotationDegrees))
                .position(x: frame.midX, y: frame.midY)
            } else {
                Text(element.text ?? "")
                    .foregroundStyle(plan.fontToken(for: element) == .display ? color(plan.style.ink) : color(plan.style.secondary))
                    .frame(width: frame.width, height: frame.height, alignment: .leading)
                    .position(x: frame.midX, y: frame.midY)
            }
        case .image:
            if let assetID = element.assetID, let photo = document.photos.first(where: { $0.id == assetID && $0.isEligibleForArchive && isPhotoAvailable($0) }) {
                // Rotation belongs to the image element, not to the pixels
                // inside an axis-aligned template box. The content geometry
                // therefore stays unrotated while the whole element (image,
                // border, and selection chrome) rotates together below.
                let geometry = MemoryBookImageTransformGeometry(container: frame, sourceAspect: photo.aspectRatio, element: unrotatedImageContent(element))
                MemoryBookImageTransform(geometry: geometry) {
                    PhotoAssetThumbnail(
                        identifier: photo.assetLocalIdentifier,
                        contentMode: element.imageContentMode == .fit ? .fit : .fill,
                        treatment: plan.style.imageTreatment,
                        background: .clear
                    )
                }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(selectedElementID == element.id && editing ? TailorColor.clay : .clear, lineWidth: 2))
                    .overlay {
                        if selectedElementID == element.id && editing {
                            SelectedPhotoChrome()
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay {
                        if let borderRect = plan.filmImageBorderRect(in: frame),
                           let lineWidth = plan.filmImageBorderLineWidth(),
                           let cornerRadius = plan.filmImageBorderCornerRadius() {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(color(plan.style.accent), lineWidth: lineWidth)
                                .frame(width: borderRect.width, height: borderRect.height)
                                .position(x: borderRect.midX - frame.minX, y: borderRect.midY - frame.minY)
                        }
                    }
                    .gesture(dragGesture(element, size: plan.pageSize, plan: plan))
                    .simultaneousGesture(magnifyGesture(element))
                    .simultaneousGesture(rotationGesture(element))
                    .onTapGesture { if editing { selectedElementID = element.id } }
                    .accessibilityAction { if editing { selectedElementID = element.id } }
                    .allowsHitTesting(editing)
                    .accessibilityLabel(selectedElementID == element.id ? "Selected photo. Drag to reposition, pinch to resize, or rotate with two fingers." : "Photo element")
                    .accessibilityIdentifier("Photo element")
                    // This is intentionally exposed in UI-test builds as a
                    // document readback marker. It lets the crop tests prove
                    // that Cancel leaves the document untouched and that
                    // Done/Undo/Redo restore the exact persisted transform.
                    .accessibilityValue(memoryBookTransformMarker(element))
                    .overlay(alignment: .topLeading) {
                        if selectedElementID == element.id {
                            // Separate from the tappable image so XCTest can
                            // read the selected document element deterministically
                            // when a page contains several photos.
                            Color.clear.frame(width: 1, height: 1)
                                .accessibilityElement()
                                .accessibilityIdentifier("Selected photo transform")
                                .accessibilityValue(memoryBookTransformMarker(element))
                        }
                    }
                    .rotationEffect(.degrees(element.rotationDegrees))
                    .position(x: frame.midX, y: frame.midY)
            } else {
                missingPhotoView(element, frame: frame)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
    }

    @ViewBuilder private func missingPhotoView(_ element: MemoryBookElement, frame: CGRect) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title2)
                .accessibilityLabel("Photo unavailable")
            Text("Photo unavailable")
                .font(.caption.weight(.semibold))
            if editing, let replaceMissingPhoto {
                Button("Replace photo") { replaceMissingPhoto(element.id) }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .tint(TailorColor.clay)
                    .accessibilityLabel("Replace photo")
                    .accessibilityValue("Photo unavailable. Replace it before export.")
                    .accessibilityHint("Choose another selected photo before export.")
            }
        }
        .foregroundStyle(TailorColor.ink)
        .frame(width: frame.width, height: frame.height)
        .background(TailorColor.mist)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(TailorColor.clay, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func color(_ rgb: MemoryBookRGB) -> Color { Color(red: rgb.red, green: rgb.green, blue: rgb.blue) }
    private func uiColor(_ rgb: MemoryBookRGB) -> UIColor { UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1) }

    private func unrotatedImageContent(_ element: MemoryBookElement) -> MemoryBookElement {
        var content = element
        content.rotationDegrees = 0
        return content
    }

    private func dragGesture(_ element: MemoryBookElement, size: CGSize, plan: MemoryBookPageRenderPlan) -> some Gesture {
        DragGesture().onChanged { value in
            guard selectedElementID == element.id,
                  let index = page.elements.firstIndex(where: { $0.id == element.id }) else { return }
            if startFrame == nil { beginEdit(); startFrame = page.elements[index].normalizedFrame }
            var frame = startFrame ?? page.elements[index].normalizedFrame
            if element.kind == .text, plan.textLayout(for: element) != nil {
                let attempted = CGRect(x: frame.origin.x + value.translation.width / size.width, y: frame.origin.y + value.translation.height / size.height, width: frame.width, height: frame.height)
                frame = plan.clampedTextFrame(attempted, for: element)
            } else {
                let safeInset: CGFloat = element.kind == .image ? 0 : MemoryBookPageRenderPlan.safeInsetRatio
                frame.origin.x = min(max(safeInset, frame.origin.x + value.translation.width / size.width), 1 - safeInset - frame.width)
                frame.origin.y = min(max(safeInset, frame.origin.y + value.translation.height / size.height), 1 - safeInset - frame.height)
            }
            page.elements[index].normalizedFrame = frame; page.elements[index].isLayoutLocked = true; page.elements[index].origin = .user
        }.onEnded { _ in
            guard startFrame != nil else { return }
            startFrame = nil; endEdit()
        }
    }

    private func magnifyGesture(_ element: MemoryBookElement) -> some Gesture {
        MagnifyGesture().onChanged { value in
            guard selectedElementID == element.id,
                  let index = page.elements.firstIndex(where: { $0.id == element.id }) else { return }
            if startImageFrame == nil { beginEdit(); startImageFrame = page.elements[index].normalizedFrame }
            page.elements[index].normalizedFrame = resizedImageFrame(startImageFrame ?? page.elements[index].normalizedFrame, magnification: value.magnification)
            page.elements[index].isLayoutLocked = true; page.elements[index].origin = .user
        }.onEnded { _ in
            guard startImageFrame != nil else { return }
            startImageFrame = nil; endEdit()
        }
    }

    /// Image scaling changes the image element itself. Crop scale stays in the
    /// crop editor, so a resize cannot silently become a fixed-slot crop.
    private func resizedImageFrame(_ original: CGRect, magnification: CGFloat) -> CGRect {
        // Photos may cover the complete page. Text retains the editorial
        // safe area, but image elements use the full printable canvas.
        let safeInset: CGFloat = 0
        let aspect = original.height / max(0.01, original.width)
        let maximumWidth = 1 - 2 * safeInset
        let maximumHeight = 1 - 2 * safeInset
        var width = min(maximumWidth, max(0.10, original.width * magnification))
        if width * aspect > maximumHeight { width = maximumHeight / aspect }
        let height = width * aspect
        var frame = CGRect(x: original.midX - width / 2, y: original.midY - height / 2, width: width, height: height)
        frame.origin.x = min(max(safeInset, frame.origin.x), 1 - safeInset - width)
        frame.origin.y = min(max(safeInset, frame.origin.y), 1 - safeInset - height)
        return frame
    }


    private func rotationGesture(_ element: MemoryBookElement) -> some Gesture {
        RotateGesture().onChanged { value in
            guard selectedElementID == element.id,
                  let index = page.elements.firstIndex(where: { $0.id == element.id }) else { return }
            if startRotation == nil { beginEdit(); startRotation = page.elements[index].rotationDegrees }
            let degrees = (startRotation ?? 0) + value.rotation.degrees
            // A small snap zone gives a satisfying straight result without
            // preventing intentional angles in a scrapbook composition.
            page.elements[index].rotationDegrees = abs(degrees) < 2.5 ? 0 : min(180, max(-180, degrees))
            page.elements[index].isLayoutLocked = true; page.elements[index].origin = .user
        }.onEnded { _ in
            guard startRotation != nil else { return }
            startRotation = nil; endEdit()
        }
    }

    private func textRotationHandleGesture(_ element: MemoryBookElement, frame: CGRect) -> some Gesture {
        DragGesture(coordinateSpace: .named(canvasCoordinateSpace)).onChanged { value in
            guard selectedElementID == element.id,
                  let index = page.elements.firstIndex(where: { $0.id == element.id }) else { return }
            if startRotation == nil {
                beginEdit()
                startRotation = page.elements[index].rotationDegrees
                textRotationStartAngle = angle(from: CGPoint(x: frame.midX, y: frame.midY), to: value.startLocation)
            }
            guard let initialAngle = textRotationStartAngle else { return }
            var delta = angle(from: CGPoint(x: frame.midX, y: frame.midY), to: value.location) - initialAngle
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            let degrees = (startRotation ?? 0) + delta
            page.elements[index].rotationDegrees = abs(degrees) < 2.5 ? 0 : min(180, max(-180, degrees))
            page.elements[index].isLayoutLocked = true; page.elements[index].origin = .user
        }.onEnded { _ in
            guard startRotation != nil else { return }
            startRotation = nil
            textRotationStartAngle = nil
            endEdit()
        }
    }

    private func angle(from centre: CGPoint, to point: CGPoint) -> Double {
        atan2(Double(point.y - centre.y), Double(point.x - centre.x)) * 180 / .pi
    }
}

/// Visual chrome for the canvas' existing drag/pinch gestures. The handles
/// make the current selection discoverable without adding a second transform
/// implementation beside the shared crop geometry.
private struct SelectedPhotoChrome: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(TailorColor.clay, lineWidth: 3)
                .padding(2)
            Rectangle().stroke(TailorColor.clay.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .padding(8)
            HStack {
                handle
                Spacer()
                handle
            }
            VStack {
                handle
                Spacer()
                handle
            }
            VStack {
                HStack {
                    Text("PHOTO SELECTED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .foregroundStyle(.white)
                        .background(TailorColor.clay)
                        .clipShape(Capsule())
                    Spacer()
                }
                Spacer()
            }
            .padding(8)
        }
        .padding(-4)
    }

    private var handle: some View {
        Circle()
            .fill(TailorColor.paper)
            .frame(width: 11, height: 11)
            .overlay(Circle().stroke(TailorColor.clay, lineWidth: 2))
            .shadow(color: .black.opacity(0.12), radius: 2)
    }
}

private struct TextRotationHandle: View {
    var body: some View {
        Image(systemName: "rotate.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(Circle().fill(TailorColor.clay))
            .overlay(Circle().stroke(TailorColor.paper, lineWidth: 2))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
    }
}

/// Preview's UIKit bridge deliberately receives the renderer factory's full
/// attributed paragraph rather than reconstructing a subset with SwiftUI
/// modifiers. PDF calls the same `MemoryBookTextRenderer` factory.
private struct MemoryBookAttributedTextPreview: UIViewRepresentable {
    let snapshot: MemoryBookTextLayoutSnapshot
    let color: UIColor

    func makeUIView(context: Context) -> MemoryBookPreviewLabel {
        let label = MemoryBookPreviewLabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.contentMode = .topLeft
        label.backgroundColor = .clear
        label.isOpaque = false
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    /// SwiftUI may ask a UIKit representable for an unconstrained size before
    /// applying the outer element frame. UILabel answers that question with
    /// `CGFloat.greatestFiniteMagnitude`, which then becomes its actual text
    /// width and leaves the glyphs off-canvas. The render-plan snapshot already
    /// contains the exact editor/PDF text rectangle, so use it as the bounded
    /// fallback while retaining the shared attributed paragraph.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MemoryBookPreviewLabel, context: Context) -> CGSize? {
        let fallback = snapshot.spec.textRect.size
        let width = resolvedDimension(proposal.width, fallback: fallback.width)
        let height = resolvedDimension(proposal.height, fallback: fallback.height)
        return CGSize(width: width, height: height)
    }

    private func resolvedDimension(_ proposed: CGFloat?, fallback: CGFloat) -> CGFloat {
        guard let proposed, proposed.isFinite, proposed > 0, proposed < 10_000 else {
            return max(1, fallback)
        }
        return proposed
    }

    func updateUIView(_ label: MemoryBookPreviewLabel, context: Context) {
        let attributed = MemoryBookPreviewTextAdapter.attributedString(for: snapshot, color: color)
        label.attributedText = attributed
        label.textColor = color
        label.textAlignment = snapshot.spec.alignment.nsTextAlignment
        label.semanticContentAttribute = switch snapshot.spec.writingDirection {
        case .rightToLeft: .forceRightToLeft
        case .leftToRight: .forceLeftToRight
        case .natural: .unspecified
        }
        // UIKit does not always invalidate its intrinsic text layout when a
        // SwiftUI frame changes after the attributed value arrives. Explicit
        // invalidation keeps the bridge's B1 paragraph visible without
        // reconstructing it as a separate SwiftUI Text implementation.
        label.invalidateIntrinsicContentSize()
        label.setNeedsLayout()
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            label.isAccessibilityElement = true
            label.accessibilityIdentifier = "Text renderer diagnostic"
            label.accessibilityLabel = snapshot.value
            // `updateUIView` can run before SwiftUI resolves the representable
            // frame, when UIKit temporarily reports an infinite dimension.
            // Keep the diagnostic, but let the UILabel publish bounds only
            // after layout and never coerce an unresolved CGFloat to Int.
            label.configureDiagnostic(
                prefix: "snapshot=\(snapshot.value.count);attributed=\(attributed.length);color=\(color.description)"
            )
        }
    }
}

private final class MemoryBookPreviewLabel: UILabel {
    private var diagnosticPrefix: String?

    func configureDiagnostic(prefix: String) {
        diagnosticPrefix = prefix
        refreshDiagnostic()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshDiagnostic()
    }

    private func refreshDiagnostic() {
        guard let diagnosticPrefix else { return }
        let width = diagnosticDimension(bounds.width)
        let height = diagnosticDimension(bounds.height)
        accessibilityValue = "\(diagnosticPrefix);bounds=\(width)x\(height);alpha=\(diagnosticDimension(alpha));hidden=\(isHidden)"
    }

    private func diagnosticDimension(_ value: CGFloat) -> String {
        guard value.isFinite else { return "unresolved" }
        // Bounds can be a finite but deliberately enormous transitional
        // layout value. Do not narrow it to Int merely for UI-test logging.
        return String(describing: value)
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let measured = super.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: min(bounds.height, measured.height))
    }
}

private struct ThumbnailRail: View {
    let pages: [MemoryBookPage]
    @Binding var selectedPageID: UUID?
    var body: some View { ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { ForEach(pages) { page in Button { selectedPageID = page.id } label: { VStack(spacing: 2) { RoundedRectangle(cornerRadius: 4).fill(page.id == selectedPageID ? TailorColor.clay : TailorColor.paper).frame(width: 42, height: 56).overlay(Text("\(page.pageNumber)").font(.caption2).foregroundStyle(page.id == selectedPageID ? .white : TailorColor.ink)); Text(page.kind == .photoSelection ? "Photos" : page.kind.rawValue).font(.system(size: 8)).lineLimit(1).truncationMode(.tail).frame(width: 52) }.frame(width: 52) }.buttonStyle(.plain).accessibilityIdentifier("MemoryBook page \(page.id.uuidString)").accessibilityLabel("Page \(page.pageNumber)") } }.padding(.horizontal, 16) }.frame(height: 82) }
}

private struct PageManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    @Binding var selectedPageID: UUID?
    let recordHistory: () -> Void
    let commit: () -> Void
    @State private var confirmDelete: MemoryBookPage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("PAGES").font(.caption.weight(.bold)).tracking(1).foregroundStyle(TailorColor.secondaryInk)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
                        ForEach(book.pages) { page in
                            pageCard(page)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Pages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Menu { Button("Add photo page") { addPage(.photoSelection) }; Button("Add note page") { addPage(.photoSelection, layout: .note) } } label: { Image(systemName: "plus") }
                        Button("Done") { dismiss() }
                    }
                }
            }
            .alert("Delete this page?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) { Button("Delete", role: .destructive) { deletePage() }; Button("Cancel", role: .cancel) {} } message: { Text("This removes the page layout only. Your original photos remain in Tailor and Photos.") }
        }
    }

    private func pageCard(_ page: MemoryBookPage) -> some View {
        Button {
            selectedPageID = page.id
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    PageManagerCanvasThumbnail(page: page, document: book)
                        .frame(height: 142)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(page.id == selectedPageID ? TailorColor.clay : TailorColor.line, lineWidth: page.id == selectedPageID ? 2 : 1))
                    if page.id == selectedPageID {
                        Text("CURRENT").font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 4).background(TailorColor.ink).clipShape(Capsule()).padding(8)
                    }
                    if isModified(page) {
                        Image(systemName: "pencil.circle.fill").foregroundStyle(TailorColor.clay).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(7)
                    }
                }
                Text(page.title.isEmpty ? "Untitled page" : page.title).font(.caption.weight(.semibold)).foregroundStyle(TailorColor.ink).lineLimit(1)
                HStack {
                    Text(page.isLocked ? "Structured page" : "Editable page").font(.caption2).foregroundStyle(TailorColor.secondaryInk)
                    Spacer()
                    pageMenu(page)
                }
            }
            .padding(10)
            .background(TailorColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Page \(page.pageNumber) card")
        .accessibilityLabel("Page \(page.pageNumber), \(page.title), \(page.id == selectedPageID ? "current" : ""), \(isModified(page) ? "modified" : "")")
    }

    @ViewBuilder private func pageMenu(_ page: MemoryBookPage) -> some View {
        Menu {
            if !page.isLocked {
                Button("Duplicate") { duplicate(page) }
                if canMove(page, by: -1) { Button("Move earlier") { move(page, by: -1) } }
                if canMove(page, by: 1) { Button("Move later") { move(page, by: 1) } }
                Button("Delete page", role: .destructive) { confirmDelete = page }
            } else {
                Text("This structural page stays in the book.")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(TailorColor.ink)
                .frame(width: 30, height: 26)
        }
        .accessibilityLabel("Page \(page.pageNumber) actions")
    }

    private func isModified(_ page: MemoryBookPage) -> Bool {
        page.elements.contains { $0.origin == .user || $0.isLayoutLocked }
    }

    private func addPage(_ kind: MemoryBookPageKind, layout: MemoryBookLayout = .mosaic) {
        recordHistory()
        let chapter = book.chapters.first { !$0.isHidden }
        let ids = Array(chapter?.photoIDs.prefix(layout == .note ? 0 : 6) ?? [])
        let title = layout == .note ? "A note" : (chapter?.title ?? "Selected moments")
        let subtitle = layout == .note ? "A few words you want to keep." : (chapter?.note ?? "")
        let page = MemoryBookPage(kind: kind, title: title, subtitle: subtitle, chapterID: chapter?.id, photoIDs: ids, layout: layout, pageNumber: book.pages.count + 1, elements: MemoryBookBuilder.elements(kind: kind, title: title, subtitle: subtitle, photos: ids, layout: layout))
        let insertion = max(0, min(book.pages.count - 1, (book.pages.firstIndex { $0.id == selectedPageID } ?? book.pages.count - 1) + 1))
        book.pages.insert(page, at: insertion); book.renumberPages(); selectedPageID = page.id; commit()
    }
    private func deletePage() { guard let page = confirmDelete, let index = book.pages.firstIndex(where: { $0.id == page.id }), !page.isLocked else { return }; recordHistory(); book.pages.remove(at: index); book.renumberPages(); selectedPageID = book.pages[max(0, min(index, book.pages.count - 1))].id; confirmDelete = nil; commit() }
    private func duplicate(_ page: MemoryBookPage) { recordHistory(); if let id = book.duplicatePage(id: page.id) { selectedPageID = id; commit() } }
    private func move(_ page: MemoryBookPage, by offset: Int) {
        guard let index = book.pages.firstIndex(where: { $0.id == page.id }), canMove(page, by: offset) else { return }
        recordHistory(); book.movePage(from: index, to: index + offset); commit()
    }

    /// Structural pages are immovable. Photo pages remain within their chapter
    /// run so a drag cannot put them before the chapter opener or mix periods.
    private func canMove(_ page: MemoryBookPage, by offset: Int) -> Bool {
        guard !page.isLocked,
              let index = book.pages.firstIndex(where: { $0.id == page.id }) else { return false }
        let destination = index + offset
        guard book.pages.indices.contains(destination) else { return false }
        let target = book.pages[destination]
        guard !target.isLocked else { return false }
        if page.kind == .photoSelection {
            return target.kind == .photoSelection && target.chapterID == page.chapterID
        }
        return page.kind == .milestone && target.kind == .milestone
    }

    private func reorder(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first, book.pages.indices.contains(sourceIndex) else { return }
        let page = book.pages[sourceIndex]
        // `destination` is calculated before removal by List; normalize it to
        // the page that will sit adjacent to the dragged page after insertion.
        let normalizedDestination = destination > sourceIndex ? destination - 1 : destination
        guard normalizedDestination != sourceIndex,
              book.pages.indices.contains(normalizedDestination),
              canMove(page, by: normalizedDestination - sourceIndex) else { return }
        recordHistory()
        book.movePage(from: sourceIndex, to: normalizedDestination)
        commit()
    }
}

/// Page management deliberately renders the same document page model as the
/// editor, Reader and PDF. A thumbnail can therefore never drift into a
/// generic title/line card when a user changes template, text or photo state.
private struct PageManagerCanvasThumbnail: View {
    let page: MemoryBookPage
    let document: MemoryBookDocument

    var body: some View {
        EditorBookPageCanvas(
            page: .constant(page),
            document: document,
            selectedElementID: .constant(nil),
            textDraftHighlight: .constant(nil),
            editing: false,
            watermarked: false,
            isPhotoAvailable: PhotoAssetAvailability.isAvailable,
            beginEdit: {},
            endEdit: {}
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("Page \(page.pageNumber) canvas thumbnail")
        .accessibilityLabel("Page \(page.pageNumber) preview")
    }
}

private struct PhotoPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    let selectedPageID: UUID?
    let selectedElementID: UUID?
    let requestCrop: (UUID, UUID) -> Void
    let recordHistory: () -> Void
    let commit: () -> Void
    @State private var resetTarget: ResetTarget?

    private struct ResetTarget: Identifiable {
        let id = UUID()
        let pageIndex: Int
        let elementIndex: Int
    }

    var body: some View {
        NavigationStack {
            List {
                if let pageIndex = book.pages.firstIndex(where: { $0.id == selectedPageID }),
                   let elementID = selectedElementID ?? book.pages[pageIndex].elements.first(where: { $0.kind == .image })?.id,
                   let elementIndex = book.pages[pageIndex].elements.firstIndex(where: { $0.id == elementID && $0.kind == .image }) {
                    Section("Selected photo") {
                        Button("Crop") { requestCrop(book.pages[pageIndex].id, book.pages[pageIndex].elements[elementIndex].id); dismiss() }
                            .accessibilityIdentifier("Photo tool crop")
                        Picker("Photo fit", selection: Binding(
                            get: { book.pages[pageIndex].elements[elementIndex].imageContentMode },
                            set: { mode in
                                recordHistory()
                                book.pages[pageIndex].elements[elementIndex].imageContentMode = mode
                                book.pages[pageIndex].elements[elementIndex].cropOffset = .zero
                                if mode == .fit {
                                    book.pages[pageIndex].elements[elementIndex].cropScale = 1
                                }
                                book.pages[pageIndex].elements[elementIndex].origin = .user
                                _ = book.normalizeFitImageFramesToAssetAspect()
                                commit()
                            }
                        )) {
                            Text("Show full photo").tag(MemoryBookImageContentMode.fit)
                            Text("Fill frame").tag(MemoryBookImageContentMode.fill)
                        }
                        .accessibilityIdentifier("Photo content mode")
                        Button("Bring forward") { recordHistory(); book.pages[pageIndex].elements[elementIndex].zIndex += 1; commit() }
                        Button("Send backward") { recordHistory(); book.pages[pageIndex].elements[elementIndex].zIndex -= 1; commit() }
                        Button("Bring to front") { recordHistory(); book.pages[pageIndex].elements[elementIndex].zIndex = (book.pages[pageIndex].elements.map(\.zIndex).max() ?? 0) + 1; commit() }
                        Button("Send to back") { recordHistory(); book.pages[pageIndex].elements[elementIndex].zIndex = (book.pages[pageIndex].elements.map(\.zIndex).min() ?? 0) - 1; commit() }
                        Button("Rotate left") { recordHistory(); book.pages[pageIndex].elements[elementIndex].rotationDegrees = max(-15, book.pages[pageIndex].elements[elementIndex].rotationDegrees - 1); commit() }
                        Button("Rotate right") { recordHistory(); book.pages[pageIndex].elements[elementIndex].rotationDegrees = min(15, book.pages[pageIndex].elements[elementIndex].rotationDegrees + 1); commit() }
                        Button("Reset photo") { resetTarget = ResetTarget(pageIndex: pageIndex, elementIndex: elementIndex) }
                        HStack {
                            Button { nudgeCrop(pageIndex, elementIndex, x: -0.05, y: 0) } label: { Image(systemName: "arrow.left") }.accessibilityIdentifier("Photo crop nudge left")
                            Button { nudgeCrop(pageIndex, elementIndex, x: 0.05, y: 0) } label: { Image(systemName: "arrow.right") }.accessibilityIdentifier("Photo crop nudge right")
                            Button { nudgeCrop(pageIndex, elementIndex, x: 0, y: -0.05) } label: { Image(systemName: "arrow.up") }.accessibilityIdentifier("Photo crop nudge up")
                            Button { nudgeCrop(pageIndex, elementIndex, x: 0, y: 0.05) } label: { Image(systemName: "arrow.down") }.accessibilityIdentifier("Photo crop nudge down")
                            Spacer()
                            Button { zoom(pageIndex, elementIndex, by: -0.1) } label: { Image(systemName: "minus.magnifyingglass") }.accessibilityIdentifier("Photo crop zoom out")
                            Button { zoom(pageIndex, elementIndex, by: 0.1) } label: { Image(systemName: "plus.magnifyingglass") }.accessibilityIdentifier("Photo crop zoom in")
                        }.accessibilityLabel("Adjust photo crop")
                        HStack {
                            Text("Photo frame").foregroundStyle(TailorColor.secondaryInk)
                            Spacer()
                            Button("Smaller") { resizeFrame(pageIndex, elementIndex, by: 0.9) }
                            Button("Larger") { resizeFrame(pageIndex, elementIndex, by: 1.1) }
                        }
                        Button("Remove from page", role: .destructive) { recordHistory(); let assetID = book.pages[pageIndex].elements[elementIndex].assetID; book.pages[pageIndex].elements.remove(at: elementIndex); if let assetID { book.pages[pageIndex].photoIDs.removeAll { $0 == assetID } }; commit(); dismiss() }
                    }
                }
                Section("Choose from selected photos") {
                    ForEach(book.eligiblePhotos) { photo in Button { insert(photo.id) } label: { HStack { PhotoAssetThumbnail(identifier: photo.assetLocalIdentifier).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 6)); VStack(alignment: .leading) { Text(photo.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "No date"); Text("Use this photo").font(.caption).foregroundStyle(TailorColor.secondaryInk) }; Spacer(); Image(systemName: "plus.circle") } }
                        .accessibilityIdentifier("Replace photo \(photo.assetLocalIdentifier)")
                    }
                }
            }
            .navigationTitle("Photos")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("Reset this photo?", isPresented: Binding(get: { resetTarget != nil }, set: { if !$0 { resetTarget = nil } })) {
                Button("Reset", role: .destructive) {
                    if let target = resetTarget { resetPhoto(target.pageIndex, target.elementIndex) }
                    resetTarget = nil
                }
                Button("Cancel", role: .cancel) { resetTarget = nil }
            } message: {
                Text("This restores the template frame, crop, rotation, and layer order. You can still undo it.")
            }
        }
    }
    private func insert(_ photoID: UUID) {
        guard let pageIndex = book.pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        recordHistory()
        if let elementID = selectedElementID, let index = book.pages[pageIndex].elements.firstIndex(where: { $0.id == elementID }) {
            // Route every replacement through the document operation used by
            // production UI and tests, rather than duplicating its crop math
            // in this sheet.
            _ = book.replacePhoto(pageID: book.pages[pageIndex].id, elementID: book.pages[pageIndex].elements[index].id, with: photoID)
        } else { let existing = book.pages[pageIndex].elements.filter { $0.kind == .image }.compactMap(\.assetID) + [photoID]; book.pages[pageIndex].photoIDs = existing; book.pages[pageIndex].elements = MemoryBookBuilder.elements(kind: book.pages[pageIndex].kind, title: book.pages[pageIndex].title, subtitle: book.pages[pageIndex].subtitle, photos: existing, layout: book.pages[pageIndex].layout) }
        _ = book.normalizeFitImageFramesToAssetAspect()
        commit(); dismiss()
    }
    private func nudgeCrop(_ pageIndex: Int, _ elementIndex: Int, x: CGFloat, y: CGFloat) {
        recordHistory()
        let element = book.pages[pageIndex].elements[elementIndex]
        _ = book.applyCrop(pageID: book.pages[pageIndex].id, elementID: element.id, scale: element.cropScale, offset: CGSize(width: element.cropOffset.width + x, height: element.cropOffset.height + y))
        book.pages[pageIndex].elements[elementIndex].origin = .user
        commit()
    }
    private func zoom(_ pageIndex: Int, _ elementIndex: Int, by amount: CGFloat) {
        recordHistory()
        let element = book.pages[pageIndex].elements[elementIndex]
        _ = book.applyCrop(pageID: book.pages[pageIndex].id, elementID: element.id, scale: element.cropScale + amount, offset: element.cropOffset)
        book.pages[pageIndex].elements[elementIndex].origin = .user
        commit()
    }
    private func resizeFrame(_ pageIndex: Int, _ elementIndex: Int, by scale: CGFloat) {
        recordHistory()
        var frame = book.pages[pageIndex].elements[elementIndex].normalizedFrame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        frame.size.width = min(0.86, max(0.12, frame.width * scale))
        frame.size.height = min(0.70, max(0.10, frame.height * scale))
        frame.origin.x = min(0.93 - frame.width, max(0.07, center.x - frame.width / 2))
        frame.origin.y = min(0.93 - frame.height, max(0.07, center.y - frame.height / 2))
        book.pages[pageIndex].elements[elementIndex].normalizedFrame = frame
        book.pages[pageIndex].elements[elementIndex].isLayoutLocked = true
        book.pages[pageIndex].elements[elementIndex].origin = .user
        commit()
    }

    private func resetPhoto(_ pageIndex: Int, _ elementIndex: Int) {
        guard let assetID = book.pages[pageIndex].elements[elementIndex].assetID else { return }
        recordHistory()
        let page = book.pages[pageIndex]
        if let template = MemoryBookBuilder.elements(
            kind: page.kind,
            title: page.title,
            subtitle: page.subtitle,
            photos: page.photoIDs,
            layout: page.layout
        ).first(where: { $0.kind == .image && $0.assetID == assetID }) {
            let originalID = book.pages[pageIndex].elements[elementIndex].id
            book.pages[pageIndex].elements[elementIndex] = MemoryBookElement(
                id: originalID,
                kind: .image,
                assetID: assetID,
                normalizedFrame: template.normalizedFrame,
                cropScale: 1,
                cropOffset: .zero,
                rotationDegrees: 0,
                zIndex: template.zIndex,
                isLayoutLocked: false,
                origin: .automatic
            )
        } else {
            book.pages[pageIndex].elements[elementIndex].cropScale = 1
            book.pages[pageIndex].elements[elementIndex].cropOffset = .zero
            book.pages[pageIndex].elements[elementIndex].rotationDegrees = 0
            book.pages[pageIndex].elements[elementIndex].isLayoutLocked = false
            book.pages[pageIndex].elements[elementIndex].origin = .automatic
        }
        commit()
    }
}

private struct LayoutPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    let selectedPageID: UUID?
    let choose: (MemoryBookLayout) -> Void

    // An editable photo page may be converted to a Note. Existing Note and
    // structural pages remain gated by the editor toolbar/model.
    private let options: [MemoryBookLayout] = [.single, .diptych, .grid2x2, .grid3x2, .note]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Changing layout keeps the first photos on this page. Any extra photos move into new pages in this chapter after you confirm.")
                        .font(.footnote).foregroundStyle(TailorColor.secondaryInk)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(options, id: \.self) { layout in
                            Button { choose(layout); dismiss() } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    layoutGlyph(layout)
                                    Text(layout.displayName).font(.callout.weight(.semibold))
                                    Text("Up to \(layout.photoCapacity) photo\(layout.photoCapacity == 1 ? "" : "s")").font(.caption).foregroundStyle(TailorColor.secondaryInk)
                                }
                                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                                .padding(12).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain).accessibilityLabel(layout.displayName)
                        }
                    }
                }.padding(20)
            }
            .navigationTitle("Layout")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    @ViewBuilder private func layoutGlyph(_ layout: MemoryBookLayout) -> some View {
        let columns = layout == .single || layout == .note ? 1 : (layout == .diptych || layout == .grid2x2 ? 2 : 3)
        let rows = layout == .grid2x2 ? 2 : (layout == .grid3x2 ? 2 : 1)
        if layout == .note {
            RoundedRectangle(cornerRadius: 4).stroke(TailorColor.secondaryInk, style: StrokeStyle(lineWidth: 1, dash: [4, 3])).frame(height: 52)
        } else {
            VStack(spacing: 3) { ForEach(0..<rows, id: \.self) { _ in HStack(spacing: 3) { ForEach(0..<columns, id: \.self) { _ in RoundedRectangle(cornerRadius: 3).fill(TailorColor.mist) } } } }.frame(height: 52)
        }
    }
}

/// A stable, deliberately rounded transform marker for UI-test document
/// readback. It is derived from the same `MemoryBookElement` that the editor
/// and PDF renderer consume; it is not a second draft model.
private func memoryBookTransformMarker(_ element: MemoryBookElement) -> String {
    return String(
        format: "scale=%.3f;offsetX=%.3f;offsetY=%.3f;rotation=%.1f;z=%d",
        Double(element.cropScale),
        Double(element.cropOffset.width),
        Double(element.cropOffset.height),
        Double(element.rotationDegrees),
        element.zIndex
    )
}

/// Stable document readback for the text editor's no-commit Fit failure gate.
/// It deliberately reports the persisted normalized geometry, rather than a
/// presentation-layer frame, so the test covers the model used by PDF export.
private func memoryBookTextFrameMarker(_ element: MemoryBookElement, layout: MemoryBookTextLayoutSnapshot, paperRect: CGRect) -> String {
    func normalized(_ rect: CGRect) -> String {
        String(format: "%.3f,%.3f,%.3f,%.3f", Double((rect.minX - paperRect.minX) / paperRect.width), Double((rect.minY - paperRect.minY) / paperRect.height), Double(rect.width / paperRect.width), Double(rect.height / paperRect.height))
    }
    return String(
        format: "x=%.3f;y=%.3f;width=%.3f;height=%.3f;z=%d;editable=%@;protected=%@",
        Double(element.normalizedFrame.origin.x),
        Double(element.normalizedFrame.origin.y),
        Double(element.normalizedFrame.width),
        Double(element.normalizedFrame.height),
        element.zIndex,
        normalized(layout.spec.editableRect),
        layout.spec.protectedRects.map(normalized).joined(separator: "|")
    )
}

private struct CropEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Binding var book: MemoryBookDocument
    let pageID: UUID
    let elementID: UUID
    let recordHistory: () -> Void
    let commit: () -> Void
    @State private var session: MemoryBookCropSession?
    @State private var startScale: CGFloat?
    @State private var startOffset: CGSize?
    @State private var confirmLeave = false
    @State private var confirmReset = false
    @State private var sceneExitPending = false
    @State private var exitState: MemoryBookCropExitState = .editing

    /// The stage must be bounded independently of the caption and the bottom
    /// action bar. A free GeometryReader inside the surrounding VStack made
    /// very tall/rotated apertures push the fixed frame beneath those controls.
    private var stageHeight: CGFloat { min(480, UIScreen.main.bounds.height * 0.50) }

    private var target: (pageIndex: Int, elementIndex: Int, element: MemoryBookElement, photo: ArchivePhoto)? {
        guard let pageIndex = book.pages.firstIndex(where: { $0.id == pageID }),
              let elementIndex = book.pages[pageIndex].elements.firstIndex(where: { $0.id == elementID }),
              let assetID = book.pages[pageIndex].elements[elementIndex].assetID,
              let photo = book.photos.first(where: { $0.id == assetID && $0.isEligibleForArchive }) else { return nil }
        return (pageIndex, elementIndex, book.pages[pageIndex].elements[elementIndex], photo)
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.16, blue: 0.13).ignoresSafeArea()
            VStack(spacing: 18) {
                HStack { Button("Cancel", action: leave).accessibilityIdentifier("Crop cancel"); Spacer(); Text("CROP PHOTO").font(.caption.weight(.bold)).tracking(1.5); Spacer(); Button("Done", action: apply).fontWeight(.bold).accessibilityIdentifier("Crop done navigation") }.foregroundStyle(.white).padding(.horizontal, 20).padding(.top, 56)
                GeometryReader { proxy in
                    if let target, let session {
                        let frame = cropFrame(for: proxy.size, aspect: target.element.normalizedFrame.width / max(0.01, target.element.normalizedFrame.height))
                        ZStack {
                            // The dimmed stage remains visible outside the
                            // fixed original-element aperture. The 72% mask is
                            // a true overlay rather than a replacement black
                            // background, making landscape/portrait focus and
                            // the final rotation understandable.
                            PhotoAssetThumbnail(identifier: target.photo.assetLocalIdentifier, treatment: MemoryBookPageStyle.resolve(book.pages[target.pageIndex].styleOverride ?? book.style).imageTreatment)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                            Color.black.opacity(0.72).ignoresSafeArea().allowsHitTesting(false)
                            let draftElement = MemoryBookElement(
                                id: target.element.id, kind: .image, assetID: target.element.assetID,
                                normalizedFrame: target.element.normalizedFrame,
                                cropScale: session.draftTransform.scale, cropOffset: session.draftTransform.offset,
                                rotationDegrees: target.element.rotationDegrees, zIndex: target.element.zIndex,
                                textStyle: target.element.textStyle, imageContentMode: target.element.imageContentMode,
                                textFont: target.element.textFont, textColor: target.element.textColor, isLayoutLocked: target.element.isLayoutLocked,
                                origin: target.element.origin
                            )
                            let geometry = MemoryBookImageTransformGeometry(container: frame, sourceAspect: target.photo.aspectRatio, element: draftElement)
                            MemoryBookImageTransform(geometry: geometry) {
                                PhotoAssetThumbnail(identifier: target.photo.assetLocalIdentifier, treatment: MemoryBookPageStyle.resolve(book.pages[target.pageIndex].styleOverride ?? book.style).imageTreatment)
                            }
                                .position(x: frame.midX, y: frame.midY)
                                .accessibilityIdentifier("Crop image")
                                .accessibilityLabel("Crop fixed frame with 72 percent outside mask")
                            // A transparent SwiftUI surface keeps the crop
                            // gesture above PhotoKit's UIKit image subtree.
                            // `Color.clear` can be elided from the UIKit hit
                            // test tree. Keep an imperceptible rendered layer
                            // so real pinch/drag gestures always reach this
                            // SwiftUI surface above PhotoKit.
                            // Use a real (no-op) Button rather than a bare
                            // transparent Color. UIKit otherwise exposes the
                            // latter to accessibility but reports it as not
                            // hittable, which makes the pinch/drag surface
                            // neither reliably operable nor testable.
                            Button(action: {}) {
                                // Keep a rendered, near-invisible label so
                                // UIKit gives this full-size gesture target a
                                // real accessibility/hit-test frame.
                                Text(" ")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.white.opacity(0.01))
                            }
                                .buttonStyle(.plain)
                                .frame(width: frame.width, height: frame.height)
                                .contentShape(Rectangle())
                                .position(x: frame.midX, y: frame.midY)
                                .zIndex(10)
                                .accessibilityElement(children: .ignore)
                                .accessibilityRespondsToUserInteraction(true)
                                .accessibilityIdentifier("Crop canvas")
                                .accessibilityLabel("Crop canvas")
                                .accessibilityValue(memoryBookTransformMarker(draftElement))
                                .gesture(DragGesture().onChanged { value in
                                    if startOffset == nil { startOffset = session.draftTransform.offset }
                                    updateDraft(
                                        scale: session.draftTransform.scale,
                                        offset: CGSize(
                                            width: (startOffset?.width ?? 0) + value.translation.width / frame.width,
                                            height: (startOffset?.height ?? 0) + value.translation.height / frame.height
                                        )
                                    )
                                }.onEnded { _ in startOffset = nil })
                                .simultaneousGesture(MagnifyGesture().onChanged { value in
                                    if startScale == nil { startScale = session.draftTransform.scale }
                                    updateDraft(scale: (startScale ?? 1) * value.magnification, offset: session.draftTransform.offset)
                                }.onEnded { _ in startScale = nil })
                            Rectangle().stroke(TailorColor.clay, lineWidth: 2).frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY).zIndex(11).allowsHitTesting(false).accessibilityIdentifier("Crop fixed frame")
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: stageHeight)
                Text("Drag to reposition · pinch to zoom\nYour photo will always fill this frame.\nFinish or discard this crop before changing pages.").multilineTextAlignment(.center).font(.footnote).foregroundStyle(.white.opacity(0.78))
                HStack {
                    Button("Reset") { confirmReset = true }.buttonStyle(.bordered).accessibilityIdentifier("Crop reset")
                    Spacer()
                    Button("Cancel", action: leave).buttonStyle(.bordered).accessibilityIdentifier("Crop cancel bottom")
                    Button("Done", action: apply).buttonStyle(.borderedProminent).tint(TailorColor.clay).accessibilityIdentifier("Crop done primary")
                }.padding(.horizontal, 24).padding(.bottom, 22)
            }
        }
        .onAppear {
            guard let target else { return }
            session = MemoryBookCropSession(pageID: pageID, element: target.element, sourceAspect: target.photo.aspectRatio)
        }
        .confirmationDialog("Save crop changes?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Keep editing") { exitState.keepEditing() }.accessibilityIdentifier("Crop keep editing")
            Button("Save and leave") { apply() }.accessibilityIdentifier("Crop save and leave")
            Button("Discard this edit", role: .destructive) { exitState = .dismissed; dismiss() }.accessibilityIdentifier("Crop discard")
        } message: { Text("Your crop has not been applied to the book yet.") }
        .confirmationDialog("Reset crop?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset crop", role: .destructive) { resetDraft() }.accessibilityIdentifier("Crop reset confirm")
            Button("Keep current crop", role: .cancel) {}.accessibilityIdentifier("Crop reset cancel")
        } message: { Text("This resets the crop in this editor. It will not change your book until you tap Done.") }
        .interactiveDismissDisabled(session?.hasUncommittedChanges == true)
        .onChange(of: scenePhase) { _, phase in
            // Scene transitions are exit sources too. Preserve the draft and
            // request a deliberate choice when the editor comes back active.
            if phase != .active, session?.hasUncommittedChanges == true {
                exitState.requestExit(.sceneInactive, hasDraft: true)
                sceneExitPending = true
            }
            if phase == .active, sceneExitPending, session?.hasUncommittedChanges == true {
                sceneExitPending = false
                confirmLeave = true
            }
        }
        .accessibilityLabel("Crop photo")
    }

    private func cropFrame(for size: CGSize, aspect: CGFloat) -> CGRect {
        let width = min(size.width - 40, (size.height - 80) * aspect)
        let height = width / aspect
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private func updateDraft(scale: CGFloat, offset: CGSize) {
        guard var session else { return }
        session.update(scale: scale, offset: offset)
        self.session = session
    }

    private func resetDraft() {
        guard var session else { return }
        session.reset()
        self.session = session
    }

    private func leave() {
        // Unchanged sessions are a plain Cancel; every actual draft exit gets
        // the same three choices used for back/page/background exits.
        requestLeave(.cancel)
    }

    private func requestLeave(_ source: MemoryBookCropExitSource) {
        exitState.requestExit(source, hasDraft: session?.hasUncommittedChanges == true)
        if case .awaitingDecision = exitState {
            confirmLeave = true
        } else {
            dismiss()
        }
    }

    private func apply() {
        guard let target, let session, session.hasUncommittedChanges else { dismiss(); return }
        recordHistory()
        if book.applyCrop(pageID: pageID, elementID: elementID, scale: session.draftTransform.scale, offset: session.draftTransform.offset, sourceAspect: target.photo.aspectRatio) {
            commit()
        }
        exitState = .dismissed
        dismiss()
    }
}

private struct TextEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    let selectedPageID: UUID?
    let selectedElementID: UUID?
    let initialField: MemoryBookTextField?
    @Binding var draftHighlight: TextDraftHighlight?
    let recordHistory: () -> Void
    let commit: () -> Void
    @State private var text = ""
    @State private var textStyle: MemoryBookTextStyle = .standard
    @State private var textFontScale: CGFloat = 1
    @State private var textFont: MemoryBookTextFont = .editorial
    @State private var textColor: MemoryBookTextColor = .ink
    @State private var textCustomColor: MemoryBookRGB?
    @State private var field: MemoryBookTextField?
    @State private var baselineText = ""
    @State private var baselineStyle: MemoryBookTextStyle = .standard
    @State private var baselineFontScale: CGFloat = 1
    @State private var baselineFont: MemoryBookTextFont = .editorial
    @State private var baselineColor: MemoryBookTextColor = .ink
    @State private var baselineCustomColor: MemoryBookRGB?
    @State private var forceCreateFreeText = false
    @State private var confirmExit = false

    var body: some View {
        NavigationStack { Form {
            Section("This page") {
                Text("\(existingFields.count) editable fields")
                    .accessibilityIdentifier("Text whitelist count")
                    .accessibilityValue(existingFields.map(\.rawValue).joined(separator: ","))
                ForEach(existingFields, id: \.self) { role in
                    Button(roleLabel(role)) { choose(role) }
                        .accessibilityIdentifier("Text field \(role.rawValue)")
                        .accessibilityLabel("Text field \(role.rawValue)")
                }
                ForEach(addableFields, id: \.self) { role in
                    Button("Add \(roleLabel(role))") { create(role) }
                        .accessibilityIdentifier("Add text field \(role.rawValue)")
                        .accessibilityLabel("Add text field \(role.rawValue)")
                }
                Button("Add free text") { createFreeText() }
                    .accessibilityIdentifier("Add free text")
                if existingFields.isEmpty && addableFields.isEmpty { Text("No editable text on this page") }
            }
            if let field {
                Section(roleLabel(field)) {
                TextEditor(text: $text).frame(minHeight: 150).accessibilityIdentifier("Text draft input")
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Text size"); Spacer(); Text("\(Int((textFontScale * 100).rounded()))%").foregroundStyle(TailorColor.secondaryInk) }
                    Slider(value: $textFontScale, in: 0.5...2.4, step: 0.05)
                        .accessibilityIdentifier("Text font size")
                }
                Picker("Font", selection: $textFont) {
                    ForEach(MemoryBookTextFont.allCases, id: \.self) { font in
                        Text(font.displayName).tag(font)
                    }
                }
                .accessibilityIdentifier("Text font")
                ColorPicker("Color", selection: nativeTextColor, supportsOpacity: false)
                    .accessibilityIdentifier("Text color")
                Text("Use your own words. Tailor will not invent a story for you.").font(.caption).foregroundStyle(TailorColor.secondaryInk)
                }
            }
        }
            .safeAreaInset(edge: .bottom, spacing: 0) { editorStatusBar }
            .navigationTitle("Edit text").onAppear(perform: load).onChange(of: text) { _, _ in updateHighlight() }.onChange(of: textStyle) { _, _ in updateHighlight() }.onChange(of: textFontScale) { _, _ in updateHighlight() }.scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(isDirty)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { if save() { draftHighlight = nil; dismiss() } }.accessibilityIdentifier("Text draft done") }; ToolbarItem(placement: .cancellationAction) { Button("Back") { if isDirty { confirmExit = true } else { dismiss() } }.accessibilityIdentifier("Text draft back") } }
            .confirmationDialog("Keep this text draft?", isPresented: $confirmExit) {
                Button("Keep editing") {}
                    .accessibilityIdentifier("Text draft keep editing")
                Button("Save") { if save() { draftHighlight = nil; dismiss() } }
                    .accessibilityIdentifier("Text draft save")
                Button("Discard", role: .destructive) { text = baselineText; textStyle = baselineStyle; textFontScale = baselineFontScale; textFont = baselineFont; textColor = baselineColor; textCustomColor = baselineCustomColor; draftHighlight = nil; dismiss() }
                    .accessibilityIdentifier("Text draft discard")
            } message: { Text("Invalid text cannot be saved and stays in the editor.") }
        }
    }
    private var selectedTextElement: MemoryBookElement? {
        guard let page, let field else { return nil }
        if let selectedElementID,
           let targeted = page.elements.first(where: { $0.id == selectedElementID && $0.kind == .text && $0.textField == field }) {
            return targeted
        }
        return page.elements.first(where: { $0.kind == .text && $0.textField == field })
    }
    /// Opening Text never persists a migration. The sheet reads a temporary
    /// migrated view; a role is written only with an explicit valid Save.
    private var page: MemoryBookPage? {
        let pages = book.migratedLegacyTextFields().pages
        let resolvedID = selectedPageID ?? pages.first?.id
        return pages.first(where: { $0.id == resolvedID })
    }
    private var existingFields: [MemoryBookTextField] { guard let page else { return [] }; return page.elements.compactMap(\.textField).filter { $0.isAllowed(on: page.kind) } }
    private var addableFields: [MemoryBookTextField] { guard let page else { return [] }; return MemoryBookBuilder.optionalTextFields(for: page.kind).filter { !existingFields.contains($0) } }
    private var validation: MemoryBookTextDraftValidation? { guard let page, let field else { return nil }; let e = selectedTextElement; return book.textDraftValidation(text: text, style: textStyle, fontScale: textFontScale, normalizedFrame: e?.normalizedFrame ?? MemoryBookBuilder.defaultTextFrame(for: field), on: page, zIndex: e?.zIndex ?? 9, field: field) }
    private var isDirty: Bool { text != baselineText || textStyle != baselineStyle || textFontScale != baselineFontScale || textFont != baselineFont || textColor != baselineColor || textCustomColor != baselineCustomColor }
    private var nativeTextColor: Binding<Color> {
        Binding(
            get: {
                let rgb = textCustomColor ?? textColor.rgb(fallback: .init(red: 0.10, green: 0.20, blue: 0.16))
                return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
            },
            set: { value in
                let color = UIColor(value)
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1
                guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }
                textCustomColor = .init(red: Double(red), green: Double(green), blue: Double(blue))
            }
        )
    }
    private func roleLabel(_ role: MemoryBookTextField) -> String { role.rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized }
    private func load() {
        guard let page else { return }
        let resolvedField = initialField ?? page.elements.first(where: { $0.id == selectedElementID && $0.kind == .text })?.textField ?? existingFields.first
        if let resolvedField { choose(resolvedField) }
    }
    private func choose(_ role: MemoryBookTextField) {
        forceCreateFreeText = false
        let target: MemoryBookElement?
        if let page, let selectedElementID,
           let selected = page.elements.first(where: { $0.id == selectedElementID && $0.kind == .text && $0.textField == role }) {
            target = selected
        } else {
            target = page?.elements.first(where: { $0.kind == .text && $0.textField == role })
        }
        field = role
        text = target?.text ?? ""
        textStyle = target?.textStyle ?? .standard
        textFontScale = target?.textFontScale ?? 1
        textFont = target?.textFont ?? .editorial
        textColor = target?.textColor ?? .ink
        textCustomColor = target?.textCustomColor
        baselineText = text; baselineStyle = textStyle; baselineFontScale = textFontScale; baselineFont = textFont; baselineColor = textColor; baselineCustomColor = textCustomColor
        updateHighlight()
    }
    private func create(_ role: MemoryBookTextField) { forceCreateFreeText = false; field = role; text = ""; textStyle = .standard; textFontScale = 1; textFont = .editorial; textColor = .ink; textCustomColor = nil; baselineText = ""; baselineStyle = .standard; baselineFontScale = 1; baselineFont = .editorial; baselineColor = .ink; baselineCustomColor = nil; updateHighlight() }
    private func createFreeText() {
        // A free note is not tied to an existing semantic field.  Deferring
        // insertion until Save means Back/Discard leaves no empty ghost layer.
        forceCreateFreeText = true
        field = .legacyUserNote; text = ""; textStyle = .standard; textFontScale = 1; textFont = .editorial; textColor = .ink; textCustomColor = nil
        baselineText = ""; baselineStyle = .standard; baselineFontScale = 1; baselineFont = .editorial; baselineColor = .ink; baselineCustomColor = nil
        draftHighlight = nil
    }
    private func save() -> Bool {
        guard let page, let field, let validation, validation.isValid, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let pageIndex = book.pages.firstIndex(where: { $0.id == page.id }) else { updateHighlight(); return false }
        recordHistory()
        if !forceCreateFreeText, let index = book.pages[pageIndex].elements.firstIndex(where: { ($0.id == selectedElementID && $0.kind == .text) || ($0.kind == .text && $0.textField == field) }) {
            book.pages[pageIndex].elements[index].text = text
            book.pages[pageIndex].elements[index].textStyle = textStyle
            book.pages[pageIndex].elements[index].textFontScale = textFontScale
            book.pages[pageIndex].elements[index].textFont = textFont
            book.pages[pageIndex].elements[index].textColor = textColor
            book.pages[pageIndex].elements[index].textCustomColor = textCustomColor
            book.pages[pageIndex].elements[index].textField = field
            book.pages[pageIndex].elements[index].origin = .user
        } else {
            let topLayer = (book.pages[pageIndex].elements.map(\.zIndex).max() ?? 9) + 1
            book.pages[pageIndex].elements.append(MemoryBookElement(kind: .text, text: text, normalizedFrame: MemoryBookBuilder.defaultTextFrame(for: field), zIndex: topLayer, textStyle: textStyle, textFontScale: textFontScale, textFont: textFont, textColor: textColor, textCustomColor: textCustomColor, textField: field, isLayoutLocked: true, origin: .user))
        }
        forceCreateFreeText = false
        commit(); baselineText = text; baselineStyle = textStyle; baselineFontScale = textFontScale; baselineFont = textFont; baselineColor = textColor; baselineCustomColor = textCustomColor; updateHighlight(); return true
    }
    private func fitText() {
        guard let page, let field, let element = selectedTextElement else { return }
        let candidates: [MemoryBookTextStyle] = textStyle == .large ? [.standard, .small] : (textStyle == .standard ? [.small] : [])
        guard let style = candidates.first(where: { book.textDraftValidation(text: text, style: $0, fontScale: textFontScale, normalizedFrame: element.normalizedFrame, on: page, zIndex: element.zIndex, field: field).isValid }) else { updateHighlight(); return }
        textStyle = style; _ = save()
    }
    private func updateHighlight() { guard let page, let e = selectedTextElement, let validation else { draftHighlight = nil; return }; draftHighlight = .init(pageID: page.id, elementID: e.id, isInvalid: !validation.isValid) }

    /// A permanent keyboard-aware status surface. SwiftUI places a
    /// `safeAreaInset` above the software keyboard, so count, validation and
    /// repair actions stay visible instead of depending on Form row creation
    /// or a transient scroll position.
    @ViewBuilder private var editorStatusBar: some View {
        if let field, let validation {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(validation.characterCount) / \(validation.characterLimit) characters")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(validation.exceedsCharacterLimit ? .red : TailorColor.secondaryInk)
                        .accessibilityIdentifier("Text character count")
                        .accessibilityValue("\(validation.characterCount)/\(validation.characterLimit)")
                    Spacer()
                }
                if !validation.isValid {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(validation.exceedsCharacterLimit ? "Shorten this text" : "Text overflows this frame (\(validation.measurement.requiredLines) lines needed, \(validation.measurement.availableLines) fit).")
                            .accessibilityIdentifier(validation.exceedsCharacterLimit ? "Text draft character limit error" : "Text draft error")
                            .accessibilityValue("invalid")
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                    if selectedTextElement == nil {
                        RoundedRectangle(cornerRadius: 4).stroke(.red, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            .frame(height: 36)
                            .overlay(Text("New field frame preview needs attention").font(.caption).foregroundStyle(.red))
                            .accessibilityIdentifier("New text draft frame preview")
                            .accessibilityValue("invalid default frame")
                    }
                    Button("Fit text") { fitText() }
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(TailorColor.clay)
                        .accessibilityIdentifier("Fit text")
                        .accessibilityLabel("Fit text")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider() }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Text draft status for \(roleLabel(field))")
        }
    }
}

private struct StylePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    let selectedPageID: UUID?
    let recordHistory: () -> Void
    let commit: () -> Void
    var body: some View { NavigationStack { List { Section("Apply to entire book") { ForEach(AlbumStyle.allCases, id: \.self) { style in Button { recordHistory(); book.style = style; book.profile.albumStyle = style; commit(); dismiss() } label: { HStack { Text(style.label); Spacer(); if book.style == style { Image(systemName: "checkmark") } }.foregroundStyle(TailorColor.ink) } } }; Section("This page") { Button("Use book style") { override(nil) }; ForEach(AlbumStyle.allCases, id: \.self) { style in Button(style.label) { override(style) } } } }.navigationTitle("Style") } }
    private func override(_ style: AlbumStyle?) { guard let index = book.pages.firstIndex(where: { $0.id == selectedPageID }) else { return }; recordHistory(); book.pages[index].styleOverride = style; commit(); dismiss() }
}

private struct BookCheckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    let assetIsAvailable: (ArchivePhoto) -> Bool
    let selectIssue: (MemoryBookIssue) -> Void
    private var issues: [MemoryBookIssue] { book.checkBook(assetIsAvailable: assetIsAvailable) }
    var body: some View { NavigationStack { List { if issues.isEmpty { ContentUnavailableView("Your book is ready to preview", systemImage: "checkmark.seal") } else { ForEach(issues) { issue in HStack(alignment: .top) { Image(systemName: issue.severity == .blocking ? "exclamationmark.triangle.fill" : "lightbulb").foregroundStyle(issue.severity == .blocking ? .red : TailorColor.clay); VStack(alignment: .leading) { Text(issue.severity == .blocking ? "Needs attention" : "Suggestion").font(.caption.weight(.bold)); Text(issue.message) }; Spacer(); if issue.pageID != nil { Button(issue.field == nil ? "Go" : "Go to text field") { selectIssue(issue) }.accessibilityIdentifier("Book check go \(issue.field?.rawValue ?? "page")").accessibilityLabel(issue.field.map { "Go to \($0.rawValue) text field" } ?? "Go") } } } } }.navigationTitle("Book check").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } } } }
}

private extension AlbumStyle {
    var label: String { switch self { case .warmPaper: "Warm Paper"; case .quietNight: "Quiet Night"; case .fieldNotes: "Field Notes"; case .cinema: "Cinema"; case .filmAlbum: "Film Album" } }
}

struct PreviewFeatureView: View {
    let name: String
    @Binding var style: AlbumStyle
    @Binding var pageSize: PDFPageSize
    let chapters: [Chapter]
    let photos: [ArchivePhoto]
    @Binding var memoryBook: MemoryBookDocument?
    let purchased: Bool
    let next: () -> Void
    let back: () -> Void
    @State private var readerPage = 0
    /// This is the source of truth for reading position. A tab index describes
    /// a presentation group, which changes from one page to a two-page spread
    /// after rotation; a MemoryBookPage identity does not.
    @State private var readerLogicalPageID: UUID?
    @State private var showCustomization = false
    @State private var showContents = false
    @StateObject private var photoAvailability = PhotoAssetAvailabilityMonitor()

    var body: some View {
        // Reader intentionally does not use TailorScreen: the book is the
        // surface, while controls stay as restrained overlays around it.
        let _ = photoAvailability.revision
        ZStack {
            TailorColor.paper.ignoresSafeArea()
            if memoryBook != nil {
                AlbumPagesPreview(
                    document: documentBinding,
                    watermarked: !purchased,
                    selectedPage: $readerPage,
                    selectedLogicalPageID: $readerLogicalPageID,
                    assetIsAvailable: PhotoAssetAvailability.isAvailable,
                    immersive: true
                )
                    .padding(.horizontal, 18)
                    .padding(.top, 62)
                    .padding(.bottom, 112)
            }
            VStack(spacing: 0) {
                HStack {
                    Button(action: back) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Back to editor")
                        .foregroundStyle(TailorColor.ink)
                    Spacer()
                    Text("A book to keep.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(TailorColor.ink)
                        .accessibilityLabel("A book to keep.")
                    Spacer()
                    Button("Edit") { back() }
                        .font(.footnote.weight(.bold))
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Edit book")
                        .foregroundStyle(TailorColor.clay)
                    Button("Contents") { showContents = true }
                        .font(.footnote.weight(.bold))
                        .accessibilityLabel("Contents")
                        .foregroundStyle(TailorColor.ink)
                }
                .padding(.horizontal, 18)
                .background(.ultraThinMaterial)
                Spacer()
                HStack(spacing: 14) {
                    Button("Customize book") { showCustomization = true }
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(TailorColor.clay)
                    Spacer()
                    Label("Swipe left or right", systemImage: "hand.draw")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TailorColor.secondaryInk)
                        .accessibilityIdentifier("Reader navigation hint")
                    Text("PAGE \(readerLogicalPageNumber) OF \(visiblePageCount)")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(TailorColor.secondaryInk)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showCustomization) {
            PreviewCustomizationSheet(style: $style, pageSize: $pageSize)
        }
        .sheet(isPresented: $showContents) {
            ReaderContentsSheet(
                document: documentBinding.wrappedValue,
                visiblePageIDs: Set(documentBinding.wrappedValue.readerVisiblePages(watermarked: !purchased).map(\.id))
            ) { pageID in
                // The reader maps this identity into its current portrait or
                // landscape group. Never treat a logical page as a tab index.
                readerLogicalPageID = pageID
                showContents = false
            }
        }
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-uiFixturePage"), arguments.indices.contains(index + 1), let requested = UUID(uuidString: arguments[index + 1]), memoryBook?.pages.contains(where: { $0.id == requested }) == true { readerLogicalPageID = requested }
        }
        .safeAreaInset(edge: .bottom) {
            TailorPrimaryButton(title: purchased ? "Generate full PDF" : "Unlock complete album · $19.99", action: next)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(TailorColor.paper)
        }
    }
    private var documentBinding: Binding<MemoryBookDocument> { Binding(get: { memoryBook ?? MemoryBookBuilder.build(profile: PetProfile(name: name, species: .dog, departureYear: Calendar.current.component(.year, from: .now), albumStyle: style), photos: photos, chapters: chapters, style: style, pageSize: pageSize) }, set: { memoryBook = $0 }) }
    private var visiblePageCount: Int {
        guard let memoryBook else { return 1 }
        return max(memoryBook.readerVisiblePages(watermarked: !purchased).count, 1)
    }
    private var readerLogicalPageNumber: Int {
        guard
            let pageID = readerLogicalPageID,
            let page = memoryBook?.pages.first(where: { $0.id == pageID })
        else {
            return max(1, readerPage + 1)
        }
        return page.pageNumber
    }
}

private struct AlbumPagesPreview: View {
    @Binding var document: MemoryBookDocument
    let watermarked: Bool
    @Binding var selectedPage: Int
    @Binding var selectedLogicalPageID: UUID?
    let assetIsAvailable: (ArchivePhoto) -> Bool
    let immersive: Bool
    @State private var interfaceIsLandscape = false

    init(document: Binding<MemoryBookDocument>, watermarked: Bool, selectedPage: Binding<Int>, selectedLogicalPageID: Binding<UUID?>, assetIsAvailable: @escaping (ArchivePhoto) -> Bool = PhotoAssetAvailability.isAvailable, immersive: Bool = false) {
        self._document = document
        self.watermarked = watermarked
        self._selectedPage = selectedPage
        self._selectedLogicalPageID = selectedLogicalPageID
        self.assetIsAvailable = assetIsAvailable
        self.immersive = immersive
    }

    var body: some View {
        GeometryReader { proxy in
            // Geometry can remain portrait during an iPhone orientation
            // transition on iOS 26. Combine it with the window-scene signal
            // so a real landscape scene always rebuilds into a spread.
            let landscape = interfaceIsLandscape || proxy.size.width > proxy.size.height
            let groups = pageGroups(landscape: landscape)
            TabView(selection: $selectedPage) {
                ForEach(Array(groups.enumerated()), id: \.offset) { offset, pages in
                    ZStack(alignment: .bottom) {
                        ReaderPageSpread(
                            pages: pages,
                            document: document,
                            watermarked: watermarked,
                            assetIsAvailable: assetIsAvailable,
                            isSpread: landscape
                        )
                        if pages.contains(where: { $0.kind == .contents }) {
                            ReaderContentsOverlay(
                                entries: contentsEntries,
                                visiblePageIDs: Set(visiblePages.map(\.id))
                            ) { pageID in
                                selectedLogicalPageID = pageID
                            }
                        }
                    }
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: landscape) { _, _ in
                synchronizeSelection(in: groups)
            }
            .onChange(of: selectedPage) { _, _ in
                // A user turning a spread selects its first logical page. Do
                // not overwrite a page selected by Contents when it is the
                // right-hand page of that same spread.
                guard let pages = groups[safe: selectedPage] else { return }
                if selectedLogicalPageID == nil || !pages.contains(where: { $0.id == selectedLogicalPageID }) {
                    selectedLogicalPageID = pages.first?.id
                }
            }
            .onChange(of: selectedLogicalPageID) { _, _ in
                synchronizeSelection(in: groups)
            }
        }
        .aspectRatio(immersive ? nil : (document.pageSize == .a4 ? 595 / 842 : 612 / 792), contentMode: .fit)
        .frame(maxHeight: immersive ? .infinity : 430)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Album page preview")
        .onAppear {
            refreshInterfaceOrientation()
            synchronizeSelection(in: pageGroups(landscape: interfaceIsLandscape))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            refreshInterfaceOrientation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // State is intentionally identity-based, so returning from the
            // background only needs to re-map it for the current scene shape.
            refreshInterfaceOrientation()
            synchronizeSelection(in: pageGroups(landscape: interfaceIsLandscape))
        }
    }

    private func refreshInterfaceOrientation() {
        let sceneOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .interfaceOrientation
        interfaceIsLandscape = sceneOrientation?.isLandscape == true || UIDevice.current.orientation.isLandscape
    }

    private func pageGroups(landscape: Bool) -> [[MemoryBookPage]] {
        guard landscape else { return visiblePages.map { [$0] } }
        return stride(from: 0, to: visiblePages.count, by: 2).map {
            Array(visiblePages[$0..<min($0 + 2, visiblePages.count)])
        }
    }

    private func synchronizeSelection(in groups: [[MemoryBookPage]]) {
        guard let firstPage = groups.first?.first else {
            selectedPage = 0
            selectedLogicalPageID = nil
            return
        }
        let logicalPageID = selectedLogicalPageID ?? groups[safe: selectedPage]?.first?.id ?? firstPage.id
        guard let targetIndex = groups.firstIndex(where: { group in
            group.contains(where: { $0.id == logicalPageID })
        }) else {
            // A locked sample can omit an entry from the full contents list.
            // Keep navigation truthful by landing on the current visible page.
            selectedPage = min(selectedPage, max(0, groups.count - 1))
            selectedLogicalPageID = groups[safe: selectedPage]?.first?.id ?? firstPage.id
            return
        }
        if selectedPage != targetIndex {
            withAnimation(.easeInOut(duration: 0.24)) { selectedPage = targetIndex }
        }
    }

    private var contentsEntries: [(id: UUID, title: String, subtitle: String)] {
        document.pages
            .filter { $0.kind == .chapterOpener }
            .map { page in (page.id, page.title, page.subtitle) }
    }

    /// The unpaid reader is a truthful sample rather than an arbitrary prefix:
    /// it keeps the book's beginning and ending and, when available, shows two
    /// different periods. The complete document remains editable upstream.
    private var visiblePages: [MemoryBookPage] {
        document.readerVisiblePages(watermarked: watermarked)
    }
}

/// The reader, its top Contents tool, and its printed contents page must agree
/// about which pages are present in a free sample. Keeping this selection in
/// the document layer prevents navigation from resolving to a hidden page.
private extension MemoryBookDocument {
    func readerVisiblePages(watermarked: Bool) -> [MemoryBookPage] {
        guard watermarked, pages.count > 8 else { return pages }
        var selected: [MemoryBookPage] = []
        func include(_ page: MemoryBookPage?) {
            guard let page, !selected.contains(where: { $0.id == page.id }), selected.count < 8 else { return }
            selected.append(page)
        }
        include(pages.first(where: { $0.kind == .cover }))
        include(pages.first(where: { $0.kind == .contents }))
        let chapterOpeners = pages.filter { $0.kind == .chapterOpener }
        include(chapterOpeners.first)
        include(chapterOpeners.dropFirst().first)
        let photoPages = pages.filter { $0.kind == .photoSelection || $0.kind == .milestone }
        include(photoPages.first)
        include(photoPages.dropFirst().last)
        include(pages.last(where: { $0.kind == .closing }))
        for page in pages where selected.count < 6 { include(page) }
        return selected.sorted { $0.pageNumber < $1.pageNumber }
    }
}

private struct ReaderPageSpread: View {
    let pages: [MemoryBookPage]
    let document: MemoryBookDocument
    let watermarked: Bool
    let assetIsAvailable: (ArchivePhoto) -> Bool
    let isSpread: Bool

    var body: some View {
        HStack(spacing: isSpread ? 8 : 0) {
            ForEach(pages) { page in
                if let index = document.pages.firstIndex(where: { $0.id == page.id }) {
                    EditorBookPageCanvas(
                        page: .constant(document.pages[index]),
                        document: document,
                        selectedElementID: .constant(nil),
                        textDraftHighlight: .constant(nil),
                        editing: false,
                        watermarked: watermarked,
                        isPhotoAvailable: assetIsAvailable,
                        beginEdit: {},
                        endEdit: {}
                    )
                    .aspectRatio(document.pageSize == .a4 ? 595 / 842 : 612 / 792, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(isSpread ? 8 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            isSpread
                ? (pages.count == 2 ? "Reader double-page spread" : "Reader landscape single page")
                : "Reader single page"
        )
    }
}

private struct ReaderContentsOverlay: View {
    let entries: [(id: UUID, title: String, subtitle: String)]
    let visiblePageIDs: Set<UUID>
    let jump: (UUID) -> Void
    @State private var unavailableTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CONTENTS").font(.caption2.weight(.bold)).tracking(1)
            if entries.isEmpty {
                Text("Chapters will appear here as you add them.").font(.caption2)
            } else {
                ForEach(entries, id: \.id) { entry in
                    Button {
                        if visiblePageIDs.contains(entry.id) {
                            jump(entry.id)
                        } else {
                            unavailableTitle = entry.title
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.title).lineLimit(1)
                                if !entry.subtitle.isEmpty { Text(entry.subtitle).font(.caption2).lineLimit(1) }
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Contents jump \(entry.id.uuidString)")
                    .accessibilityLabel("Jump to \(entry.title)")
                }
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(TailorColor.ink)
        .padding(10)
        .frame(maxWidth: 250, alignment: .leading)
        .background(TailorColor.elevated.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
        .padding(16)
        .accessibilityIdentifier("Reader contents")
        .alert("This chapter is not in the free sample.", isPresented: Binding(
            get: { unavailableTitle != nil },
            set: { if !$0 { unavailableTitle = nil } }
        )) {
            Button("Keep reading", role: .cancel) {}
        } message: {
            Text("\(unavailableTitle ?? "This chapter") is available after you unlock the complete album.")
        }
    }
}

/// An explicit Reader tool keeps the printed contents page discoverable even
/// when the free sample omits intermediate pages. Its entries are derived from
/// the same chapter opener pages, not a separate navigation data store.
private struct ReaderContentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let document: MemoryBookDocument
    let visiblePageIDs: Set<UUID>
    let jump: (UUID) -> Void
    @State private var unavailableTitle: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(document.pages.filter { $0.kind == .chapterOpener }) { page in
                    Button {
                        if visiblePageIDs.contains(page.id) {
                            jump(page.id)
                            dismiss()
                        } else {
                            unavailableTitle = page.title
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(page.title)
                            if !page.subtitle.isEmpty { Text(page.subtitle).font(.footnote).foregroundStyle(TailorColor.secondaryInk) }
                        }
                    }
                    .accessibilityIdentifier("Contents jump \(page.id.uuidString)")
                    .accessibilityLabel("Jump to \(page.title)")
                }
            }
            .navigationTitle("Contents")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .alert("This chapter is not in the free sample.", isPresented: Binding(
            get: { unavailableTitle != nil },
            set: { if !$0 { unavailableTitle = nil } }
        )) {
            Button("Keep reading", role: .cancel) {}
        } message: {
            Text("\(unavailableTitle ?? "This chapter") is available after you unlock the complete album.")
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct PreviewCustomizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var style: AlbumStyle
    @Binding var pageSize: PDFPageSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Choose a visual voice for every page. Your photos and page edits stay unchanged.")
                        .font(.footnote)
                        .foregroundStyle(TailorColor.secondaryInk)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(AlbumStyle.allCases, id: \.self) { choice in
                            styleCard(choice)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PRINT SIZE").font(.caption.weight(.bold)).tracking(1)
                        Picker("Paper size", selection: $pageSize) {
                            Text("US Letter").tag(PDFPageSize.letter)
                            Text("A4").tag(PDFPageSize.a4)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Customize book")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func styleCard(_ choice: AlbumStyle) -> some View {
        let palette = MemoryBookPageStyle.resolve(choice)
        return Button {
            style = choice
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(red: palette.paper.red, green: palette.paper.green, blue: palette.paper.blue))
                styleTexture(choice, accent: Color(red: palette.accent.red, green: palette.accent.green, blue: palette.accent.blue))
                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.label.uppercased()).font(.caption.weight(.bold)).tracking(0.8)
                    Text(styleDescription(choice)).font(.caption2).lineLimit(1)
                }
                .foregroundStyle(Color(red: palette.ink.red, green: palette.ink.green, blue: palette.ink.blue))
                .padding(12)
            }
            .frame(height: 116)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(style == choice ? TailorColor.clay : TailorColor.line, lineWidth: style == choice ? 3 : 1))
            .overlay(alignment: .topTrailing) {
                if style == choice {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(TailorColor.clay).padding(10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.label)
        .accessibilityAddTraits(style == choice ? .isSelected : [])
    }

    @ViewBuilder private func styleTexture(_ choice: AlbumStyle, accent: Color) -> some View {
        switch choice {
        case .warmPaper:
            Circle().fill(accent.opacity(0.16)).frame(width: 92).offset(x: 38, y: -28)
        case .quietNight:
            LinearGradient(colors: [accent.opacity(0.30), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fieldNotes:
            VStack(spacing: 8) { ForEach(0..<5, id: \.self) { _ in Rectangle().fill(accent.opacity(0.25)).frame(height: 1) } }.padding(12)
        case .cinema:
            LinearGradient(colors: [.black.opacity(0.82), accent.opacity(0.20)], startPoint: .top, endPoint: .bottom)
        case .filmAlbum:
            HStack(spacing: 6) { ForEach(0..<5, id: \.self) { _ in RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.36)).frame(width: 12) } }.padding(12)
        }
    }

    private func styleDescription(_ style: AlbumStyle) -> String {
        switch style {
        case .warmPaper: "Soft and timeless"
        case .quietNight: "Deep and quiet"
        case .fieldNotes: "Observational notes"
        case .cinema: "A dramatic frame"
        case .filmAlbum: "A tactile contact sheet"
        }
    }
}

struct PurchaseFeatureView: View {
    let purchase: () -> Void; let restore: () -> Void; let errorMessage: String?; let noticeMessage: String?; let isPurchasing: Bool; let next: () -> Void; let back: () -> Void
    var body: some View { TailorScreen(eyebrow: "ONE-TIME UNLOCK", title: "Keep every page.", back: back) {
        Text("$19.99 · One-time purchase").font(.title2.weight(.semibold))
        ForEach(["Full, watermark-free PDF", "Every chapter and selected photo", "Print-ready A4 and US Letter", "Stays private on your device"], id: \.self) { Label($0, systemImage: "checkmark.circle.fill").foregroundStyle(TailorColor.ink) }
        TailorInfoCard(symbol: "person.crop.circle.badge.checkmark", title: "No subscription. No account.", message: "Your full album remains editable on this iPhone.").frame(maxWidth: .infinity)
        if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
        if let noticeMessage { Text(noticeMessage).font(.footnote).foregroundStyle(TailorColor.secondaryInk) }
        Text("Payment is charged to your Apple Account after confirmation.")
            .font(.caption)
            .foregroundStyle(TailorColor.secondaryInk)
            .padding(.top, TailorSpacing.s)
        Spacer(minLength: 80)
    }.safeAreaInset(edge: .bottom) {
        VStack(spacing: 10) {
            TailorPrimaryButton(title: isPurchasing ? "Contacting App Store…" : "Unlock complete album", disabled: isPurchasing, action: purchase)
            Button("Restore purchase", action: restore).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay).disabled(isPurchasing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(TailorColor.paper)
    } }
}

/// Completion uses the same page and image geometry as Reader and PDF, not a
/// separate initials-based approximation of the exported book.
private struct MemoryBookExportCover: View {
    let document: MemoryBookDocument
    let page: MemoryBookPage

    var body: some View {
        GeometryReader { proxy in
            EditorBookPageCanvas(
                page: .constant(page),
                document: document,
                selectedElementID: .constant(nil),
                textDraftHighlight: .constant(nil),
                editing: false,
                watermarked: false,
                isPhotoAvailable: PhotoAssetAvailability.isAvailable,
                beginEdit: {},
                endEdit: {}
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }
}

struct ExportFeatureView: View {
    let name: String; let exportURL: URL?; let exportRecord: MemoryBookExportRecord?; let memoryBook: MemoryBookDocument?; let videoURL: URL?; let errorMessage: String?; let isExporting: Bool; let completedPages: Int; let totalPages: Int; let createPDF: () -> Void; let cancelPDF: () -> Void; let createVideo: () -> Void; let done: () -> Void; let back: () -> Void
    var body: some View { TailorScreen(eyebrow: "EXPORT", title: isExporting ? "Making your archive." : (exportURL == nil ? "Ready when you are." : "Your archive is ready."), back: isExporting ? nil : back) {
        VStack(spacing: 18) {
            Group {
                if isExporting { ProgressView(value: totalPages > 0 ? Double(completedPages) / Double(totalPages) : nil).controlSize(.large) }
                else { Image(systemName: exportURL == nil ? "doc.badge.plus" : "checkmark").font(.system(size: 38, weight: .semibold)).foregroundStyle(TailorColor.ink) }
            }
                .frame(width: 82, height: 82)
                .background(TailorColor.mist)
                .clipShape(Circle())
            Text(isExporting ? "Rendering page \(min(completedPages + 1, max(totalPages, 1))) of \(max(totalPages, 1)) on this iPhone. Your edits are safely saved." : (exportURL == nil ? "Review your book, then create a print-ready PDF when you are ready." : "Saved privately on this iPhone. Share a copy whenever you’re ready."))
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(TailorColor.ink.opacity(0.75))
            if let memoryBook, let cover = memoryBook.pages.first(where: { $0.kind == .cover }) ?? memoryBook.pages.first {
                // This is the identical page model and canvas used by Reader
                // and PDF rendering, scaled down only for the completion card.
                MemoryBookExportCover(document: memoryBook, page: cover)
                    .frame(width: 150, height: 210)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("Export book cover")
                    .accessibilityLabel("Exported book cover for \(memoryBook.profile.name)")
            } else {
                VStack(spacing: 6) {
                    Text(name).font(TailorFont.display(28)).foregroundStyle(TailorColor.ink)
                    Text("Life Archive").font(.system(size: 14, weight: .regular, design: .rounded)).foregroundStyle(TailorColor.ink.opacity(0.72))
                }
                .frame(width: 150, height: 210)
                .background(TailorColor.paper)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(TailorColor.ink.opacity(0.14)))
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 22)
        if let exportRecord, exportURL != nil {
            let paper = exportRecord.pageSize == .letter ? "US Letter" : "A4"
            ZStack {
                TailorInfoCard(
                    symbol: "doc.richtext",
                    title: "\(exportRecord.pageCount) pages · \(paper)",
                    message: "Created \(exportRecord.exportedAt.formatted(date: .abbreviated, time: .shortened)). \(exportRecord.fileName)"
                )
                // A real, non-zero accessibility surface is required here:
                // modifiers on a composed custom view can be absorbed by its
                // child HStack on iOS 26 and disappear from XCTest.
                TailorColor.elevated.opacity(0.01)
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("Export details")
                    .accessibilityLabel("\(exportRecord.pageCount) pages, \(paper), \(exportRecord.fileName)")
            }
        } else {
            TailorInfoCard(symbol: "lock.shield", title: "Processed on this iPhone", message: "Your photos are not uploaded. Keep a backup somewhere you trust.")
        }
        if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
    }.safeAreaInset(edge: .bottom) {
        VStack(spacing: 8) {
            if let exportURL, !isExporting {
                ShareLink(item: exportURL) {
                    TailorPrimaryActionLabel(title: "Save and share PDF", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Save and share PDF")
                Button("Open archive", action: done).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay)
            } else {
                TailorPrimaryButton(title: isExporting ? "Rendering PDF…" : (errorMessage == nil ? "Generate PDF" : "Try again"), disabled: isExporting, action: createPDF)
            }
            if isExporting { Button("Cancel rendering", action: cancelPDF).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }
            if !isExporting {
                if let videoURL { ShareLink(item: videoURL) { Text("Share 30-second video") }.font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }
                else { Button("Create 30-second memory video", action: createVideo).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }
                Button("Return to timeline", action: back).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 10).background(TailorColor.paper)
    }
}
}

struct ArchivesFeatureView: View {
    let name: String; let pdfURL: URL?; let exportRecord: MemoryBookExportRecord?; let openArchive: () -> Void; let rescan: () -> Void; let restart: () -> Void; let delete: () -> Void
    @State private var confirmDeletion = false
    var body: some View { TailorScreen(eyebrow: "TAILOR     SETTINGS", title: "Your\narchives.", back: nil) {
        Button(action: openArchive) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10).fill(TailorColor.mist).frame(width: 72, height: 72).overlay(Text(String(name.prefix(1))).font(TailorFont.display(28)).foregroundStyle(TailorColor.ink))
                VStack(alignment: .leading) {
                    Text("\(name)’s Life Archive").font(.callout.weight(.bold))
                    Text(archiveSubtitle).font(.footnote).foregroundStyle(TailorColor.ink.opacity(0.7)).accessibilityIdentifier("Archive metadata")
                }
                Spacer(); Image(systemName: "chevron.right")
            }
        }.buttonStyle(.plain).padding(16).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.mist, lineWidth: 1)).accessibilityLabel("Open \(name)’s Life Archive")
        if let pdfURL {
            VStack(alignment: .leading, spacing: 8) {
                Text("RECENT EXPORT").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(TailorColor.secondaryInk)
                ShareLink(item: pdfURL) {
                    HStack { Image(systemName: "doc.richtext"); Text("Share latest PDF").font(.callout.weight(.semibold)); Spacer(); Image(systemName: "square.and.arrow.up") }
                        .frame(maxWidth: .infinity, minHeight: 48).foregroundStyle(TailorColor.ink)
                }.accessibilityLabel("Share latest PDF")
            }
        }
        VStack(spacing: 0) {
            Button(action: rescan) {
                HStack { Text("Rescan for new photos"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                    .frame(minHeight: 48).overlay(Divider(), alignment: .bottom)
            }.buttonStyle(.plain).accessibilityIdentifier("Rescan for new photos")
            ForEach(["Manage photo access", "About Tailor"], id: \.self) { item in Button(action: {}) { HStack { Text(item); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 48).overlay(Divider(), alignment: .bottom) }.buttonStyle(.plain) }
            Button(role: .destructive) { confirmDeletion = true } label: { HStack { Text("Delete all local Tailor data"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 48) }
        }.foregroundStyle(TailorColor.ink)
        TailorInfoCard(symbol: "lock.shield", title: "Your system photos stay untouched.", message: "Deletion removes Tailor’s local matches, edits, and generated PDFs after its confirmation.")
    }.safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Create another archive", action: restart).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) }.alert("Delete all local Tailor data?", isPresented: $confirmDeletion) { Button("Delete local data", role: .destructive, action: delete); Button("Cancel", role: .cancel) {} } message: { Text("This removes Tailor’s local pet profiles, photo matches, decisions, edits, and generated PDFs from this iPhone. Your original Photos library will not be changed. This cannot be undone.") } }

    private var archiveSubtitle: String {
        guard let exportRecord else { return "Saved locally · Ready to continue" }
        let paper = exportRecord.pageSize == .letter ? "US Letter" : "A4"
        return "\(exportRecord.pageCount) pages · \(paper) · \(exportRecord.exportedAt.formatted(date: .abbreviated, time: .omitted))"
    }
}
