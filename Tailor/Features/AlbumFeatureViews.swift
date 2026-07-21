import SwiftUI
import UIKit

private struct TextDraftHighlight: Equatable {
    let pageID: UUID
    let elementID: UUID
    let isInvalid: Bool
}

private struct ElementAppearanceTarget: Identifiable {
    var id: UUID { elementID }
    let pageID: UUID
    let elementID: UUID
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
    let openStyle: () -> Void
    let initialBookCheckTarget: BookCheckNavigationTarget?
    let initialPageID: UUID?

    @State private var selectedPageID: UUID?
    @State private var selectedElementID: UUID?
    @State private var selectedElementIDs: Set<UUID> = []
    @State private var multiSelectEnabled = false
    @State private var editorClipboard: [MemoryBookElement] = []
    @State private var textEditorTarget: TextEditorTarget?
    @State private var panel: EditorPanel = .pages
    @State private var showPageManager = false
    @State private var showPhotoPicker = false
    @State private var showLayoutPicker = false
    @State private var showLayers = false
    @State private var appearanceTarget: ElementAppearanceTarget?
    @State private var cropTarget: CropTarget?
    @State private var layoutChange: LayoutChangeTarget?
    @State private var layoutUnavailableMessage: String?
    @State private var showIssues = false
    @State private var pendingBookCheckIssue: MemoryBookIssue?
    @State private var autoArrangeScope: AutoArrangeScope?
    @State private var undoStack: [MemoryBookDocument] = []
    @State private var redoStack: [MemoryBookDocument] = []
    @State private var textDraftHighlight: TextDraftHighlight?
    @State private var canvasZoom: CGFloat = 1
    @StateObject private var photoAvailability = PhotoAssetAvailabilityMonitor()

    init(memoryBook: Binding<MemoryBookDocument?>, purchased: Bool, back: @escaping () -> Void, preview: @escaping () -> Void, export: @escaping () -> Void, persist: @escaping () -> Void, openStyle: @escaping () -> Void = {}, initialBookCheckTarget: BookCheckNavigationTarget? = nil, initialPageID: UUID? = nil) {
        self._memoryBook = memoryBook
        self.purchased = purchased
        self.back = back
        self.preview = preview
        self.export = export
        self.persist = persist
        self.openStyle = openStyle
        self.initialBookCheckTarget = initialBookCheckTarget
        self.initialPageID = initialPageID
        // Establish the selected page before the first body pass whenever the
        // document is already restored. This removes the visible unselected
        // first-frame flash in the thumbnail rail.
        let requestedPageID = initialBookCheckTarget?.issue.pageID ?? initialPageID
        self._selectedPageID = State(initialValue: requestedPageID.flatMap { requested in
            memoryBook.wrappedValue?.pages.contains(where: { $0.id == requested }) == true ? requested : nil
        } ?? memoryBook.wrappedValue?.pages.first?.id)
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
            if let target = initialBookCheckTarget {
                pendingBookCheckIssue = target.issue
                DispatchQueue.main.async { presentPendingBookCheckIssue() }
            }
        }
        .onChange(of: selectedPageID) { _, _ in
            // A sheet belongs to the page that created its target. Clear the
            // presentation before changing pages so a late dismissal cannot
            // re-present stale text state or terminate the SwiftUI host.
            textEditorTarget = nil
            canvasZoom = 1
            selectedElementID = nil
            selectedElementIDs.removeAll()
            multiSelectEnabled = false
        }
        .sheet(isPresented: $showPageManager) { PageManagerSheet(book: documentBinding, selectedPageID: $selectedPageID, recordHistory: recordHistory, commit: commit) }
        .sheet(isPresented: $showPhotoPicker) { PhotoPickerSheet(book: documentBinding, selectedPageID: selectedPageID, selectedElementID: selectedElementID, requestCrop: { pageID, elementID in cropTarget = CropTarget(pageID: pageID, elementID: elementID) }, recordHistory: recordHistory, commit: commit) }
        .sheet(isPresented: textEditorPresentation, onDismiss: {
            textEditorTarget = nil
            textDraftHighlight = nil
        }) {
            if let target = textEditorTarget {
                TextEditorSheet(book: documentBinding, selectedPageID: target.pageID, selectedElementID: target.elementID, initialField: target.field, draftHighlight: $textDraftHighlight, recordHistory: recordHistory, commit: commit)
                    .id(target.id)
            }
        }
        .sheet(isPresented: $showLayoutPicker) { LayoutPickerSheet(book: documentBinding, selectedPageID: selectedPageID, choose: { layout in layoutChange = LayoutChangeTarget(pageID: selectedPageID ?? UUID(), layout: layout) }) }
        .sheet(isPresented: $showLayers) {
            ElementLayersSheet(
                book: documentBinding,
                pageID: selectedPageID,
                selectedElementID: $selectedElementID,
                selectedElementIDs: $selectedElementIDs,
                recordHistory: recordHistory,
                commit: commit
            )
        }
        .sheet(item: $appearanceTarget) { target in
            PhotoAppearanceEditorSheet(
                book: documentBinding,
                pageID: target.pageID,
                elementID: target.elementID,
                recordHistory: recordHistory,
                commit: commit
            )
        }
        // Read through the live binding when the sheet appears. Capturing the
        // value from the header can otherwise show an old Book Check result
        // after an editor mutation and before SwiftUI has rebuilt that header.
        .sheet(isPresented: $showIssues, onDismiss: presentPendingBookCheckIssue) {
            BookCheckSheet(
                book: documentBinding,
                assetIsAvailable: PhotoAssetAvailability.isAvailable,
                selectIssue: openBookCheckIssue,
                recordHistory: recordHistory,
                commit: commit
            )
        }
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
                editorCanvasViewport(book: book, pageIndex: pageIndex, watermarked: usesSafetyFixtureWatermark)
                    .padding(.top, 8)
                canvasPrecisionBar(page: page)
                ThumbnailRail(pages: book.pages, selectedPageID: $selectedPageID)
                editorToolbar(page: page)
            }
        }
    }

    private func editorCanvasViewport(book: MemoryBookDocument, pageIndex: Int, watermarked: Bool) -> some View {
        GeometryReader { proxy in
            let aspect: CGFloat = book.pageSize == .a4 ? 595 / 842 : 612 / 792
            let fittedWidth = min(max(1, proxy.size.width - 56), max(1, proxy.size.height - 20) * aspect)
            let fittedHeight = fittedWidth / aspect
            ScrollView([.horizontal, .vertical], showsIndicators: canvasZoom > 1.01) {
                EditorBookPageCanvas(
                    page: pageBinding(pageIndex),
                    document: book,
                    selectedElementID: $selectedElementID,
                    selectedElementIDs: $selectedElementIDs,
                    multiSelectEnabled: multiSelectEnabled,
                    textDraftHighlight: $textDraftHighlight,
                    editing: true,
                    watermarked: watermarked,
                    isPhotoAvailable: PhotoAssetAvailability.isAvailable,
                    replaceMissingPhoto: { elementID in
                        selectedElementID = elementID
                        showPhotoPicker = true
                    },
                    beginEdit: recordHistory,
                    endEdit: commit
                )
                .frame(width: fittedWidth * canvasZoom, height: fittedHeight * canvasZoom)
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityIdentifier("Editor canvas viewport")
    }

    private func canvasPrecisionBar(page: MemoryBookPage) -> some View {
        HStack(spacing: 14) {
            Button { setCanvasZoom(canvasZoom - 0.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .disabled(canvasZoom <= 1)
                .accessibilityLabel("Zoom out canvas")
            Button { setCanvasZoom(1) } label: {
                Text(canvasZoom == 1 ? "FIT" : "\(Int((canvasZoom * 100).rounded()))%")
                    .font(.caption2.weight(.bold))
                    .frame(minWidth: 44)
            }
            .accessibilityLabel("Fit canvas")
            .accessibilityValue("\(Int((canvasZoom * 100).rounded())) percent")
            Button { setCanvasZoom(canvasZoom + 0.25) } label: { Image(systemName: "plus.magnifyingglass") }
                .disabled(canvasZoom >= 3)
                .accessibilityLabel("Zoom in canvas")
            Spacer()
            Label("Snap", systemImage: "ruler")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            Button {
                multiSelectEnabled.toggle()
                if multiSelectEnabled, let selectedElementID { selectedElementIDs.insert(selectedElementID) }
            } label: {
                Image(systemName: multiSelectEnabled ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .accessibilityLabel(multiSelectEnabled ? "Finish multiple selection" : "Select multiple elements")
            if selectedElementIDs.intersection(Set(page.elements.map(\.id))).count > 1 {
                multiSelectionMenu(pageID: page.id, page: page)
            } else if let selectedElementID,
               let element = page.elements.first(where: { $0.id == selectedElementID }) {
                selectedElementMenu(pageID: page.id, element: element)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .frame(height: 38)
    }

    private func multiSelectionMenu(pageID: UUID, page: MemoryBookPage) -> some View {
        let ids = selectedElementIDs.intersection(Set(page.elements.map(\.id)))
        let elements = page.elements.filter { ids.contains($0.id) }
        let grouped = elements.count > 1 && Set(elements.compactMap(\.groupID)).count == 1 && elements.allSatisfy { $0.groupID != nil }
        let containsLocked = elements.contains(where: \.isInteractionLocked)
        return Menu {
            Button(grouped ? "Ungroup selected" : "Group selected") {
                setSelectedElementsGrouped(pageID: pageID, grouped: !grouped)
            }
            Button(containsLocked ? "Unlock selected" : "Lock selected") {
                setSelectedElementsLock(pageID: pageID, locked: !containsLocked)
            }
            Button("Copy selected") { copySelectedElements(pageID: pageID) }
            Divider()
            Menu("Align selected") {
                Button("Align selected left") { alignSelectedElements(pageID: pageID, alignment: .left) }
                Button("Align selected horizontal center") { alignSelectedElements(pageID: pageID, alignment: .horizontalCenter) }
                Button("Align selected right") { alignSelectedElements(pageID: pageID, alignment: .right) }
                Button("Align selected top") { alignSelectedElements(pageID: pageID, alignment: .top) }
                Button("Align selected vertical center") { alignSelectedElements(pageID: pageID, alignment: .verticalCenter) }
                Button("Align selected bottom") { alignSelectedElements(pageID: pageID, alignment: .bottom) }
            }
            .disabled(containsLocked)
            Button("Distribute horizontally") { distributeSelectedElements(pageID: pageID, horizontally: true) }
                .disabled(elements.count < 3 || containsLocked)
            Button("Distribute vertically") { distributeSelectedElements(pageID: pageID, horizontally: false) }
                .disabled(elements.count < 3 || containsLocked)
        } label: {
            Label("\(elements.count)", systemImage: grouped ? "square.3.layers.3d" : "square.on.square")
                .font(.caption2.weight(.bold))
        }
        .accessibilityLabel("Arrange \(elements.count) selected elements")
    }

    private func selectedElementMenu(pageID: UUID, element: MemoryBookElement) -> some View {
        Menu {
            Button(element.isInteractionLocked ? "Unlock element" : "Lock element") {
                setSelectedElementLock(pageID: pageID, locked: !element.isInteractionLocked)
            }
            Button("Duplicate element") { duplicateSelectedElement(pageID: pageID) }
                .disabled(element.kind == .text)
            Button("Copy element") { copySelectedElements(pageID: pageID) }
            if element.kind == .shape {
                Button("Edit shape appearance", systemImage: "paintbrush") {
                    appearanceTarget = ElementAppearanceTarget(pageID: pageID, elementID: element.id)
                }
            }
            Divider()
            Menu("Align") {
                Button("Align left") { alignSelectedElement(pageID: pageID, alignment: .left) }
                Button("Align horizontal center") { alignSelectedElement(pageID: pageID, alignment: .horizontalCenter) }
                Button("Align right") { alignSelectedElement(pageID: pageID, alignment: .right) }
                Button("Align top") { alignSelectedElement(pageID: pageID, alignment: .top) }
                Button("Align vertical center") { alignSelectedElement(pageID: pageID, alignment: .verticalCenter) }
                Button("Align bottom") { alignSelectedElement(pageID: pageID, alignment: .bottom) }
            }
            .disabled(element.isInteractionLocked)
            Menu("Layer") {
                Button("Bring forward") { layerSelectedElement(pageID: pageID, move: .forward) }
                Button("Send backward") { layerSelectedElement(pageID: pageID, move: .backward) }
                Button("Bring to front") { layerSelectedElement(pageID: pageID, move: .front) }
                Button("Send to back") { layerSelectedElement(pageID: pageID, move: .back) }
            }
            .disabled(element.isInteractionLocked)
        } label: {
            Label("Arrange", systemImage: element.isInteractionLocked ? "lock.fill" : "square.3.layers.3d")
                .font(.caption2.weight(.bold))
        }
        .accessibilityLabel("Arrange selected element")
    }

    private enum ElementAlignment { case left, horizontalCenter, right, top, verticalCenter, bottom }
    private enum ElementLayerMove { case forward, backward, front, back }

    private func copySelectedElements(pageID: UUID) {
        guard let book = memoryBook,
              let page = book.pages.first(where: { $0.id == pageID }) else { return }
        let ids = selectedElementIDs.isEmpty ? Set(selectedElementID.map { [$0] } ?? []) : selectedElementIDs
        editorClipboard = page.elements.filter { ids.contains($0.id) }
    }

    private func pasteCopiedElements(pageID: UUID) {
        guard !editorClipboard.isEmpty, let book = memoryBook,
              let pageIndex = book.pages.firstIndex(where: { $0.id == pageID }),
              !book.pages[pageIndex].isLocked else { return }
        recordHistory()
        mutate { book in
            guard let pageIndex = book.pages.firstIndex(where: { $0.id == pageID }) else { return }
            var groupMap: [UUID: UUID] = [:]
            var nextZ = (book.pages[pageIndex].elements.map(\.zIndex).max() ?? 0) + 1
            var existingFields = Set(book.pages[pageIndex].elements.compactMap(\.textField))
            var pastedIDs: Set<UUID> = []
            for source in editorClipboard {
                var copy = source
                copy.id = UUID()
                if let groupID = source.groupID {
                    if groupMap[groupID] == nil { groupMap[groupID] = UUID() }
                    copy.groupID = groupMap[groupID]
                }
                if copy.kind == .text, let field = copy.textField {
                    if existingFields.contains(field) { copy.textField = nil } else { existingFields.insert(field) }
                }
                copy.isInteractionLocked = false
                copy.isLayoutLocked = true
                copy.origin = .user
                copy.zIndex = nextZ; nextZ += 1
                copy.normalizedFrame.origin.x = min(1 - copy.normalizedFrame.width, max(0, copy.normalizedFrame.minX + 0.025))
                copy.normalizedFrame.origin.y = min(1 - copy.normalizedFrame.height, max(0, copy.normalizedFrame.minY + 0.025))
                copy.updatedAt = .now
                book.pages[pageIndex].elements.append(copy)
                if let assetID = copy.assetID, !book.pages[pageIndex].photoIDs.contains(assetID) { book.pages[pageIndex].photoIDs.append(assetID) }
                pastedIDs.insert(copy.id)
            }
            selectedElementIDs = pastedIDs
            selectedElementID = pastedIDs.first
            multiSelectEnabled = pastedIDs.count > 1
        }
    }

    private func selectedElementIndexes(pageID: UUID, in book: MemoryBookDocument) -> (Int, [Int])? {
        guard let pageIndex = book.pages.firstIndex(where: { $0.id == pageID }) else { return nil }
        let indexes = book.pages[pageIndex].elements.indices.filter { selectedElementIDs.contains(book.pages[pageIndex].elements[$0].id) }
        return indexes.count > 1 ? (pageIndex, Array(indexes)) : nil
    }

    private func setSelectedElementsGrouped(pageID: UUID, grouped: Bool) {
        guard let book = memoryBook, selectedElementIndexes(pageID: pageID, in: book) != nil else { return }
        recordHistory()
        mutate { book in
            guard let (pageIndex, indexes) = selectedElementIndexes(pageID: pageID, in: book) else { return }
            let groupID = grouped ? UUID() : nil
            for index in indexes { book.pages[pageIndex].elements[index].groupID = groupID; book.pages[pageIndex].elements[index].updatedAt = .now }
        }
    }

    private func setSelectedElementsLock(pageID: UUID, locked: Bool) {
        guard let book = memoryBook, selectedElementIndexes(pageID: pageID, in: book) != nil else { return }
        recordHistory()
        mutate { book in
            guard let (pageIndex, indexes) = selectedElementIndexes(pageID: pageID, in: book) else { return }
            for index in indexes {
                book.pages[pageIndex].elements[index].isInteractionLocked = locked
                book.pages[pageIndex].elements[index].origin = .user
                book.pages[pageIndex].elements[index].updatedAt = .now
            }
        }
    }

    private func alignSelectedElements(pageID: UUID, alignment: ElementAlignment) {
        guard let book = memoryBook,
              let (pageIndex, indexes) = selectedElementIndexes(pageID: pageID, in: book),
              indexes.allSatisfy({ !book.pages[pageIndex].elements[$0].isInteractionLocked }) else { return }
        recordHistory()
        mutate { book in
            guard let (pageIndex, indexes) = selectedElementIndexes(pageID: pageID, in: book) else { return }
            let frames = indexes.map { book.pages[pageIndex].elements[$0].normalizedFrame }
            guard let first = frames.first else { return }
            let bounds = frames.dropFirst().reduce(first) { $0.union($1) }
            for index in indexes {
                var frame = book.pages[pageIndex].elements[index].normalizedFrame
                switch alignment {
                case .left: frame.origin.x = bounds.minX
                case .horizontalCenter: frame.origin.x = bounds.midX - frame.width / 2
                case .right: frame.origin.x = bounds.maxX - frame.width
                case .top: frame.origin.y = bounds.minY
                case .verticalCenter: frame.origin.y = bounds.midY - frame.height / 2
                case .bottom: frame.origin.y = bounds.maxY - frame.height
                }
                book.pages[pageIndex].elements[index].normalizedFrame = frame
                book.pages[pageIndex].elements[index].isLayoutLocked = true
                book.pages[pageIndex].elements[index].origin = .user
                book.pages[pageIndex].elements[index].updatedAt = .now
            }
        }
    }

    private func distributeSelectedElements(pageID: UUID, horizontally: Bool) {
        guard let book = memoryBook,
              let (pageIndex, indexes) = selectedElementIndexes(pageID: pageID, in: book), indexes.count >= 3,
              indexes.allSatisfy({ !book.pages[pageIndex].elements[$0].isInteractionLocked }) else { return }
        recordHistory()
        mutate { book in
            guard let (pageIndex, indexes) = selectedElementIndexes(pageID: pageID, in: book) else { return }
            let sorted = indexes.sorted {
                let lhs = book.pages[pageIndex].elements[$0].normalizedFrame
                let rhs = book.pages[pageIndex].elements[$1].normalizedFrame
                return horizontally ? lhs.minX < rhs.minX : lhs.minY < rhs.minY
            }
            let frames = sorted.map { book.pages[pageIndex].elements[$0].normalizedFrame }
            guard let first = frames.first, let last = frames.last else { return }
            let span = horizontally ? last.maxX - first.minX : last.maxY - first.minY
            let occupied = frames.reduce(CGFloat.zero) { $0 + (horizontally ? $1.width : $1.height) }
            let gap = max(0, (span - occupied) / CGFloat(frames.count - 1))
            var cursor = horizontally ? first.minX : first.minY
            for (offset, index) in sorted.enumerated() {
                var frame = book.pages[pageIndex].elements[index].normalizedFrame
                if offset > 0 && offset < sorted.count - 1 {
                    if horizontally { frame.origin.x = cursor } else { frame.origin.y = cursor }
                    book.pages[pageIndex].elements[index].normalizedFrame = frame
                }
                cursor += (horizontally ? frame.width : frame.height) + gap
                book.pages[pageIndex].elements[index].isLayoutLocked = true
                book.pages[pageIndex].elements[index].origin = .user
                book.pages[pageIndex].elements[index].updatedAt = .now
            }
        }
    }

    private func selectedElementLocation(pageID: UUID, in book: MemoryBookDocument) -> (Int, Int)? {
        guard let selectedElementID,
              let pageIndex = book.pages.firstIndex(where: { $0.id == pageID }),
              let elementIndex = book.pages[pageIndex].elements.firstIndex(where: { $0.id == selectedElementID }) else { return nil }
        return (pageIndex, elementIndex)
    }

    private func setSelectedElementLock(pageID: UUID, locked: Bool) {
        guard let book = memoryBook, selectedElementLocation(pageID: pageID, in: book) != nil else { return }
        recordHistory()
        mutate { book in
            guard let (pageIndex, elementIndex) = selectedElementLocation(pageID: pageID, in: book) else { return }
            book.pages[pageIndex].elements[elementIndex].isInteractionLocked = locked
            book.pages[pageIndex].elements[elementIndex].origin = .user
        }
    }

    private func duplicateSelectedElement(pageID: UUID) {
        guard let book = memoryBook, selectedElementLocation(pageID: pageID, in: book) != nil else { return }
        recordHistory()
        mutate { book in
            guard let (pageIndex, elementIndex) = selectedElementLocation(pageID: pageID, in: book) else { return }
            var duplicate = book.pages[pageIndex].elements[elementIndex]
            duplicate.id = UUID()
            duplicate.textField = duplicate.kind == .text ? nil : duplicate.textField
            duplicate.isInteractionLocked = false
            duplicate.groupID = nil
            duplicate.isLayoutLocked = true
            duplicate.origin = .user
            duplicate.zIndex = (book.pages[pageIndex].elements.map(\.zIndex).max() ?? 0) + 1
            duplicate.normalizedFrame.origin.x = min(1 - duplicate.normalizedFrame.width, max(0, duplicate.normalizedFrame.origin.x + 0.025))
            duplicate.normalizedFrame.origin.y = min(1 - duplicate.normalizedFrame.height, max(0, duplicate.normalizedFrame.origin.y + 0.025))
            duplicate.updatedAt = .now
            book.pages[pageIndex].elements.append(duplicate)
            selectedElementID = duplicate.id
            selectedElementIDs = [duplicate.id]
        }
    }

    private func alignSelectedElement(pageID: UUID, alignment: ElementAlignment) {
        guard let book = memoryBook,
              let (pageIndex, elementIndex) = selectedElementLocation(pageID: pageID, in: book),
              !book.pages[pageIndex].elements[elementIndex].isInteractionLocked else { return }
        recordHistory()
        mutate { book in
            guard let (pageIndex, elementIndex) = selectedElementLocation(pageID: pageID, in: book) else { return }
            var element = book.pages[pageIndex].elements[elementIndex]
            let inset = element.kind == .text ? MemoryBookPageRenderPlan.safeInsetRatio : 0
            switch alignment {
            case .left: element.normalizedFrame.origin.x = inset
            case .horizontalCenter: element.normalizedFrame.origin.x = (1 - element.normalizedFrame.width) / 2
            case .right: element.normalizedFrame.origin.x = 1 - inset - element.normalizedFrame.width
            case .top: element.normalizedFrame.origin.y = inset
            case .verticalCenter: element.normalizedFrame.origin.y = (1 - element.normalizedFrame.height) / 2
            case .bottom: element.normalizedFrame.origin.y = 1 - inset - element.normalizedFrame.height
            }
            element.isLayoutLocked = true; element.origin = .user; element.updatedAt = .now
            book.pages[pageIndex].elements[elementIndex] = element
        }
    }

    private func layerSelectedElement(pageID: UUID, move: ElementLayerMove) {
        guard let book = memoryBook,
              let (pageIndex, elementIndex) = selectedElementLocation(pageID: pageID, in: book),
              !book.pages[pageIndex].elements[elementIndex].isInteractionLocked else { return }
        recordHistory()
        mutate { book in
            guard let (pageIndex, elementIndex) = selectedElementLocation(pageID: pageID, in: book) else { return }
            let elements = book.pages[pageIndex].elements
            let current = elements[elementIndex]
            let ordered = elements.sorted { $0.zIndex == $1.zIndex ? $0.id.uuidString < $1.id.uuidString : $0.zIndex < $1.zIndex }
            guard let orderedIndex = ordered.firstIndex(where: { $0.id == current.id }) else { return }
            switch move {
            case .forward where orderedIndex < ordered.count - 1:
                book.pages[pageIndex].elements[elementIndex].zIndex = ordered[orderedIndex + 1].zIndex + 1
            case .backward where orderedIndex > 0:
                book.pages[pageIndex].elements[elementIndex].zIndex = ordered[orderedIndex - 1].zIndex - 1
            case .front:
                book.pages[pageIndex].elements[elementIndex].zIndex = (elements.map(\.zIndex).max() ?? 0) + 1
            case .back:
                book.pages[pageIndex].elements[elementIndex].zIndex = (elements.map(\.zIndex).min() ?? 0) - 1
            default: return
            }
            book.pages[pageIndex].elements[elementIndex].origin = .user
            book.pages[pageIndex].elements[elementIndex].updatedAt = .now
        }
    }

    private func setCanvasZoom(_ proposed: CGFloat) {
        withAnimation(.easeInOut(duration: 0.18)) {
            canvasZoom = min(3, max(1, proposed))
        }
    }

    private func editorHeader(book: MemoryBookDocument, page: MemoryBookPage) -> some View {
        HStack(spacing: 14) {
            Button(action: back) { Image(systemName: "chevron.left") }
                .accessibilityLabel("Back")
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
                Button("Layers") { showLayers = true }
                if !page.isLocked {
                    Button("Add decoration", systemImage: "square.on.circle") { addDecoration(pageID: page.id) }
                }
                if !editorClipboard.isEmpty, !page.isLocked {
                    Button("Paste copied elements") { pasteCopiedElements(pageID: page.id) }
                }
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

    private func addDecoration(pageID: UUID) {
        guard var book = memoryBook,
              let pageIndex = book.pages.firstIndex(where: { $0.id == pageID }),
              !book.pages[pageIndex].isLocked else { return }
        recordHistory()
        var appearance = MemoryBookElementAppearance.default
        appearance.mask = .roundedRectangle
        appearance.cornerRadiusRatio = 18 / 612
        appearance.fillColor = book.pages[pageIndex].styleOverride.map(MemoryBookPageStyle.resolve)?.accent ?? MemoryBookPageStyle.resolve(book.style).accent
        appearance.opacity = 0.88
        appearance.shadowOpacity = 0.12
        appearance.shadowBlurRatio = 8 / 612
        let topLayer = (book.pages[pageIndex].elements.map(\.zIndex).max() ?? 0) + 1
        let element = MemoryBookElement(
            kind: .shape,
            // Start as a restrained accent in the lower-right whitespace.
            // Users can freely resize it, but the first result should not
            // obscure the page's primary photos or title.
            normalizedFrame: CGRect(x: 0.62, y: 0.76, width: 0.22, height: 0.08),
            zIndex: topLayer,
            isLayoutLocked: true,
            appearance: appearance,
            origin: .user
        )
        book.pages[pageIndex].elements.append(element)
        book.updatedAt = .now
        memoryBook = book
        selectedElementID = element.id
        selectedElementIDs = [element.id]
        commit()
        appearanceTarget = ElementAppearanceTarget(pageID: pageID, elementID: element.id)
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
            tool("textformat", "Text") { presentTextEditor(pageID: selectedPageID, elementID: selectedElementID, field: nil) }
            tool("paintpalette", "Style", action: openStyle)
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
    private var textEditorPresentation: Binding<Bool> {
        Binding(
            get: { textEditorTarget != nil },
            set: { presented in
                if !presented {
                    textEditorTarget = nil
                    textDraftHighlight = nil
                }
            }
        )
    }
    private func presentTextEditor(pageID: UUID?, elementID: UUID?, field: MemoryBookTextField?) {
        guard let pageID = pageID ?? memoryBook?.pages.first?.id,
              memoryBook?.pages.contains(where: { $0.id == pageID }) == true else { return }
        textEditorTarget = TextEditorTarget(pageID: pageID, elementID: elementID, field: field)
    }
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
        pendingBookCheckIssue = issue
        showIssues = false
    }

    private func presentPendingBookCheckIssue() {
        guard let issue = pendingBookCheckIssue else { return }
        pendingBookCheckIssue = nil
        // Finish the page change before selecting the target element. The
        // editor's page-change handler deliberately clears selection; setting
        // both synchronously made it erase Book Check's element and caused the
        // Photo panel to fall back to the first image on the page.
        DispatchQueue.main.async {
            selectedElementID = issue.elementID
            // A text blocker must then land in its actual semantic field, not
            // merely on the page. Give the selection binding one further turn
            // before the text sheet reads it.
            guard issue.field != nil, issue.elementID != nil else { return }
            DispatchQueue.main.async {
                presentTextEditor(pageID: issue.pageID, elementID: issue.elementID, field: issue.field)
            }
        }
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
    var selectedElementIDs: Binding<Set<UUID>> = .constant([])
    var multiSelectEnabled: Bool = false
    @Binding var textDraftHighlight: TextDraftHighlight?
    let editing: Bool
    let watermarked: Bool
    var isPhotoAvailable: (ArchivePhoto) -> Bool = PhotoAssetAvailability.isAvailable
    var replaceMissingPhoto: ((UUID) -> Void)? = nil
    let beginEdit: () -> Void
    let endEdit: () -> Void
    @State private var startFrame: CGRect?
    @State private var startImageFrame: CGRect?
    @State private var startResizeFrame: CGRect?
    @State private var startGroupFrames: [UUID: CGRect] = [:]
    @State private var startRotation: Double?
    @State private var textRotationStartAngle: Double?
    @State private var snapGuides: MemoryBookEditorSnapGuides = .none

    private var canvasCoordinateSpace: String { "MemoryBookPageCanvas-\(page.id.uuidString)" }
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                let plan = MemoryBookPageRenderPlan(page: page, document: document, pageSize: proxy.size, watermarked: watermarked)
                RoundedRectangle(cornerRadius: 5).fill(color(plan.style.backdrop))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color(plan.paperColor))
                    .frame(width: plan.paperRect.width, height: plan.paperRect.height)
                    .position(x: plan.paperRect.midX, y: plan.paperRect.midY)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("Page paper")
                    .accessibilityValue(memoryBookColorMarker(plan.paperColor))
                    .onTapGesture {
                        guard editing else { return }
                        selectedElementID = nil
                        selectedElementIDs.wrappedValue.removeAll()
                    }
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
                selectionControls(plan)
                snapGuideOverlay(plan)
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

    @ViewBuilder private func selectionControls(_ plan: MemoryBookPageRenderPlan) -> some View {
        let selected = page.elements.filter { activeSelectionIDs.contains($0.id) }
        if editing, selected.count > 1 {
            let normalizedBounds = selected.dropFirst().reduce(selected[0].normalizedFrame) { $0.union($1.normalizedFrame) }
            let frame = plan.rect(for: normalizedBounds)
            RoundedRectangle(cornerRadius: 6)
                .fill(TailorColor.clay.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(TailorColor.clay, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .contentShape(Rectangle())
                .gesture(groupDragGesture(selected, plan: plan))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("Multi-selection bounds")
                .accessibilityLabel("\(selected.count) selected elements")
                .accessibilityValue(memoryBookNormalizedFrameMarker(normalizedBounds))
                .accessibilityHint("Drag to move the selected elements together.")
            Text("\(selected.count) SELECTED")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(TailorColor.clay)
                .clipShape(Capsule())
                .position(x: frame.minX + 36, y: max(plan.paperRect.minY + 12, frame.minY - 12))
                .allowsHitTesting(false)
        } else if editing, let element = selected.first ?? selectedElementID.flatMap({ id in page.elements.first(where: { $0.id == id }) }) {
            let frame = plan.rect(for: element.normalizedFrame)
            if element.isInteractionLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(TailorColor.clay))
                    .position(x: frame.maxX + 14, y: frame.minY - 14)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("Locked element indicator")
                    .accessibilityLabel("Selected element is locked")
            } else if element.kind != .image {
                TextRotationHandle()
                    .position(x: frame.maxX + 14, y: frame.minY - 14)
                    .gesture(textRotationHandleGesture(element, frame: frame))
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("Text rotation handle")
                    .accessibilityLabel(element.kind == .shape ? "Rotate selected decoration" : "Rotate selected text")
                    .accessibilityHint("Drag around the element to rotate it.")
            }
            if !element.isInteractionLocked {
                ElementResizeHandle()
                    .position(x: frame.maxX + 14, y: frame.maxY + 14)
                    .gesture(resizeHandleGesture(element, plan: plan))
                    .accessibilityElement(children: .ignore)
            }
        }
    }

    private var activeSelectionIDs: Set<UUID> {
        if !selectedElementIDs.wrappedValue.isEmpty { return selectedElementIDs.wrappedValue }
        return selectedElementID.map { [$0] } ?? []
    }

    private func select(_ element: MemoryBookElement) {
        guard editing else { return }
        if multiSelectEnabled {
            if selectedElementIDs.wrappedValue.contains(element.id) {
                selectedElementIDs.wrappedValue.remove(element.id)
                if selectedElementID == element.id { selectedElementID = selectedElementIDs.wrappedValue.first }
            } else {
                selectedElementIDs.wrappedValue.insert(element.id)
                selectedElementID = element.id
            }
        } else if let groupID = element.groupID {
            let group = Set(page.elements.filter { $0.groupID == groupID }.map(\.id))
            selectedElementIDs.wrappedValue = group
            selectedElementID = element.id
        } else {
            selectedElementIDs.wrappedValue = [element.id]
            selectedElementID = element.id
        }
    }

    private func isSelected(_ element: MemoryBookElement) -> Bool {
        activeSelectionIDs.contains(element.id)
    }

    @ViewBuilder private func snapGuideOverlay(_ plan: MemoryBookPageRenderPlan) -> some View {
        if editing, let x = snapGuides.vertical {
            Rectangle()
                .fill(TailorColor.clay)
                .frame(width: 1.5, height: plan.paperRect.height)
                .position(x: plan.paperRect.minX + x * plan.paperRect.width, y: plan.paperRect.midY)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("Vertical snap guide")
                .accessibilityLabel("Vertically aligned")
        }
        if editing, let y = snapGuides.horizontal {
            Rectangle()
                .fill(TailorColor.clay)
                .frame(width: plan.paperRect.width, height: 1.5)
                .position(x: plan.paperRect.midX, y: plan.paperRect.minY + y * plan.paperRect.height)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("Horizontal snap guide")
                .accessibilityLabel("Horizontally aligned")
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
                    color: uiColor(element.textCustomColor ?? element.textColor.rgb(fallback: plan.fontToken(for: element) == .display ? plan.style.ink : plan.style.secondary)),
                    diagnosticRole: element.textField?.rawValue ?? element.id.uuidString,
                    canonicalScale: plan.canonicalTextRenderScale
                )
                .frame(width: frame.width, height: frame.height, alignment: .leading)
                // UIKit only paints the shared B1 attributed paragraph. The
                // editor interaction lives on this SwiftUI overlay so it has
                // a stable, real accessibility frame for VoiceOver/XCTest.
                .allowsHitTesting(false)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(textDraftHighlight?.pageID == page.id && textDraftHighlight?.elementID == element.id && textDraftHighlight?.isInvalid == true ? .red : (isSelected(element) && editing ? TailorColor.clay : .clear), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                .overlay {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(dragGesture(element, size: plan.pageSize, plan: plan))
                        .onTapGesture { select(element) }
                        .allowsHitTesting(editing)
                        // This document-derived marker is intentionally
                        // attached to the interaction surface, not UIKit.
                        .accessibilityIdentifier("Text element \(element.textField?.rawValue ?? "unassigned")")
                        .accessibilityLabel(isSelected(element) ? "Selected text element" : "Text element")
                        .accessibilityValue(memoryBookTextFrameMarker(element, layout: textLayout, paperRect: plan.paperRect))
                }
                .rotationEffect(.degrees(element.rotationDegrees))
                .position(x: frame.midX, y: frame.midY)
            } else {
                Text(element.text ?? "")
                    .foregroundStyle(plan.fontToken(for: element) == .display ? color(plan.style.ink) : color(plan.style.secondary))
                    .frame(width: frame.width, height: frame.height, alignment: .leading)
                    .position(x: frame.midX, y: frame.midY)
            }
        case .shape:
            MemoryBookElementMaskShape(
                mask: element.appearance.mask,
                cornerRadius: element.appearance.cornerRadiusRatio * plan.paperRect.width
            )
            .fill(color(element.appearance.fillColor ?? plan.style.accent))
            .overlay {
                if element.appearance.borderStyle != .none {
                    MemoryBookElementMaskShape(mask: element.appearance.mask, cornerRadius: element.appearance.cornerRadiusRatio * plan.paperRect.width)
                        .stroke(
                            color(element.appearance.borderColor),
                            style: StrokeStyle(
                                lineWidth: element.appearance.borderWidthRatio * plan.paperRect.width,
                                dash: element.appearance.borderStyle == .dashed ? [6 / 612 * plan.paperRect.width, 4 / 612 * plan.paperRect.width] : []
                            )
                        )
                }
            }
            .shadow(
                color: .black.opacity(element.appearance.shadowOpacity),
                radius: element.appearance.shadowBlurRatio * plan.paperRect.width,
                x: element.appearance.shadowOffset.width * plan.paperRect.width,
                y: element.appearance.shadowOffset.height * plan.paperRect.width
            )
            .opacity(element.appearance.opacity)
            .overlay(MemoryBookElementMaskShape(mask: element.appearance.mask, cornerRadius: element.appearance.cornerRadiusRatio * plan.paperRect.width).stroke(isSelected(element) && editing ? TailorColor.clay : .clear, lineWidth: 2))
            .frame(width: frame.width, height: frame.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(element, size: plan.pageSize, plan: plan))
            .simultaneousGesture(rotationGesture(element))
            .onTapGesture { select(element) }
            .allowsHitTesting(editing)
            .accessibilityIdentifier("Decoration element")
            .accessibilityLabel(isSelected(element) ? "Selected decoration" : "Decoration")
            .accessibilityValue(memoryBookTransformMarker(element))
            .rotationEffect(.degrees(element.rotationDegrees))
            .position(x: frame.midX, y: frame.midY)
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
                        adjustments: element.imageAdjustments,
                        background: .clear
                    )
                }
                    .clipShape(MemoryBookElementMaskShape(
                        mask: element.appearance.mask,
                        cornerRadius: element.appearance.cornerRadiusRatio * plan.paperRect.width
                    ))
                    .overlay {
                        if element.appearance.borderStyle != .none {
                            MemoryBookElementMaskShape(
                                mask: element.appearance.mask,
                                cornerRadius: element.appearance.cornerRadiusRatio * plan.paperRect.width
                            )
                            .stroke(
                                color(element.appearance.borderColor),
                                style: StrokeStyle(
                                    lineWidth: element.appearance.borderWidthRatio * plan.paperRect.width,
                                    dash: element.appearance.borderStyle == .dashed ? [6 / 612 * plan.paperRect.width, 4 / 612 * plan.paperRect.width] : []
                                )
                            )
                        }
                    }
                    .shadow(
                        color: .black.opacity(element.appearance.shadowOpacity),
                        radius: element.appearance.shadowBlurRatio * plan.paperRect.width,
                        x: element.appearance.shadowOffset.width * plan.paperRect.width,
                        y: element.appearance.shadowOffset.height * plan.paperRect.width
                    )
                    .opacity(element.appearance.opacity)
                    .overlay(MemoryBookElementMaskShape(mask: element.appearance.mask, cornerRadius: element.appearance.cornerRadiusRatio * plan.paperRect.width).stroke(isSelected(element) && editing ? TailorColor.clay : .clear, lineWidth: 2))
                    .overlay {
                        if isSelected(element) && activeSelectionIDs.count == 1 && editing {
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
                    .onTapGesture { select(element) }
                    .accessibilityAction { select(element) }
                    .allowsHitTesting(editing)
                    .accessibilityLabel(isSelected(element) ? "Selected photo. Drag to reposition, pinch to resize, or rotate with two fingers." : "Photo element")
                    .accessibilityIdentifier("Photo element")
                    // This is intentionally exposed in UI-test builds as a
                    // document readback marker. It lets the crop tests prove
                    // that Cancel leaves the document untouched and that
                    // Done/Undo/Redo restore the exact persisted transform.
                    .accessibilityValue(memoryBookTransformMarker(element))
                    .overlay(alignment: .topLeading) {
                        if isSelected(element) {
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
            guard editing,
                  let index = page.elements.firstIndex(where: { $0.id == element.id }),
                  !page.elements[index].isInteractionLocked else { return }
            // Direct manipulation should not require a preparatory tap. A
            // drag both selects the touched element and starts one atomic
            // history transaction.
            if !isSelected(element) { select(element) }
            if startFrame == nil { beginEdit(); startFrame = page.elements[index].normalizedFrame }
            var frame = startFrame ?? page.elements[index].normalizedFrame
            let horizontalScale = max(1, plan.paperRect.width)
            let verticalScale = max(1, plan.paperRect.height)
            let attempted = CGRect(
                x: frame.origin.x + value.translation.width / horizontalScale,
                y: frame.origin.y + value.translation.height / verticalScale,
                width: frame.width,
                height: frame.height
            )
            let snapped = MemoryBookEditorSnapEngine.snap(
                frame: attempted,
                peerFrames: page.elements.filter { $0.id != element.id }.map(\.normalizedFrame),
                threshold: 7 / min(horizontalScale, verticalScale)
            )
            frame = snapped.frame
            if element.kind == .text, plan.textLayout(for: element) != nil {
                frame = plan.clampedTextFrame(frame, for: element)
            } else {
                let safeInset: CGFloat = element.kind == .text ? MemoryBookPageRenderPlan.safeInsetRatio : 0
                frame.origin.x = min(max(safeInset, frame.origin.x), 1 - safeInset - frame.width)
                frame.origin.y = min(max(safeInset, frame.origin.y), 1 - safeInset - frame.height)
            }
            snapGuides = visibleSnapGuides(snapped.guides, for: frame)
            page.elements[index].normalizedFrame = frame; page.elements[index].isLayoutLocked = true; page.elements[index].origin = .user
        }.onEnded { _ in
            guard startFrame != nil else { return }
            startFrame = nil; snapGuides = .none; endEdit()
        }
    }

    private func groupDragGesture(_ elements: [MemoryBookElement], plan: MemoryBookPageRenderPlan) -> some Gesture {
        DragGesture().onChanged { value in
            let ids = Set(elements.map(\.id))
            guard editing, elements.count > 1,
                  elements.allSatisfy({ !$0.isInteractionLocked }) else { return }
            if startGroupFrames.isEmpty {
                beginEdit()
                startGroupFrames = Dictionary(uniqueKeysWithValues: page.elements.filter { ids.contains($0.id) }.map { ($0.id, $0.normalizedFrame) })
            }
            guard let first = startGroupFrames.values.first else { return }
            let bounds = startGroupFrames.values.dropFirst().reduce(first) { $0.union($1) }
            let horizontalScale = max(1, plan.paperRect.width)
            let verticalScale = max(1, plan.paperRect.height)
            let attempted = CGRect(
                x: bounds.minX + value.translation.width / horizontalScale,
                y: bounds.minY + value.translation.height / verticalScale,
                width: bounds.width,
                height: bounds.height
            )
            let snapped = MemoryBookEditorSnapEngine.snap(
                frame: attempted,
                peerFrames: page.elements.filter { !ids.contains($0.id) }.map(\.normalizedFrame),
                threshold: 7 / min(horizontalScale, verticalScale)
            )
            let targetX = min(max(0, snapped.frame.minX), 1 - bounds.width)
            let targetY = min(max(0, snapped.frame.minY), 1 - bounds.height)
            let dx = targetX - bounds.minX
            let dy = targetY - bounds.minY
            for index in page.elements.indices where ids.contains(page.elements[index].id) {
                guard let original = startGroupFrames[page.elements[index].id] else { continue }
                page.elements[index].normalizedFrame.origin = CGPoint(x: original.minX + dx, y: original.minY + dy)
                page.elements[index].isLayoutLocked = true
                page.elements[index].origin = .user
                page.elements[index].updatedAt = .now
            }
            snapGuides = visibleSnapGuides(snapped.guides, for: CGRect(x: targetX, y: targetY, width: bounds.width, height: bounds.height))
        }.onEnded { _ in
            guard !startGroupFrames.isEmpty else { return }
            startGroupFrames.removeAll()
            snapGuides = .none
            endEdit()
        }
    }

    private func visibleSnapGuides(_ guides: MemoryBookEditorSnapGuides, for frame: CGRect) -> MemoryBookEditorSnapGuides {
        let tolerance: CGFloat = 0.001
        let xAnchors = [frame.minX, frame.midX, frame.maxX]
        let yAnchors = [frame.minY, frame.midY, frame.maxY]
        return MemoryBookEditorSnapGuides(
            vertical: guides.vertical.flatMap { guide in xAnchors.contains(where: { abs($0 - guide) <= tolerance }) ? guide : nil },
            horizontal: guides.horizontal.flatMap { guide in yAnchors.contains(where: { abs($0 - guide) <= tolerance }) ? guide : nil }
        )
    }

    private func magnifyGesture(_ element: MemoryBookElement) -> some Gesture {
        MagnifyGesture().onChanged { value in
            guard selectedElementID == element.id,
                  let index = page.elements.firstIndex(where: { $0.id == element.id }),
                  !page.elements[index].isInteractionLocked else { return }
            if startImageFrame == nil { beginEdit(); startImageFrame = page.elements[index].normalizedFrame }
            page.elements[index].normalizedFrame = resizedImageFrame(startImageFrame ?? page.elements[index].normalizedFrame, magnification: value.magnification)
            page.elements[index].isLayoutLocked = true; page.elements[index].origin = .user
        }.onEnded { _ in
            guard startImageFrame != nil else { return }
            startImageFrame = nil; endEdit()
        }
    }

    private func resizeHandleGesture(_ element: MemoryBookElement, plan: MemoryBookPageRenderPlan) -> some Gesture {
        DragGesture().onChanged { value in
            guard editing,
                  selectedElementID == element.id,
                  let index = page.elements.firstIndex(where: { $0.id == element.id }),
                  !page.elements[index].isInteractionLocked else { return }
            if startResizeFrame == nil {
                beginEdit()
                startResizeFrame = page.elements[index].normalizedFrame
            }
            let original = startResizeFrame ?? page.elements[index].normalizedFrame
            let dx = value.translation.width / max(1, plan.paperRect.width)
            let dy = value.translation.height / max(1, plan.paperRect.height)
            var resized = original
            if element.kind == .image {
                let aspect = original.height / max(0.01, original.width)
                let widthDelta = abs(dx) >= abs(dy) ? dx : dy / max(0.01, aspect)
                resized.size.width = min(1 - original.minX, max(0.10, original.width + widthDelta))
                resized.size.height = min(1 - original.minY, max(0.10, resized.width * aspect))
                if resized.height >= 1 - original.minY {
                    resized.size.height = 1 - original.minY
                    resized.size.width = resized.height / max(0.01, aspect)
                }
            } else if element.kind == .shape {
                resized.size.width = min(1 - original.minX, max(0.04, original.width + dx))
                resized.size.height = min(1 - original.minY, max(0.04, original.height + dy))
            } else {
                resized.size.width = min(1 - original.minX - MemoryBookPageRenderPlan.safeInsetRatio, max(0.12, original.width + dx))
                resized.size.height = min(1 - original.minY - MemoryBookPageRenderPlan.safeInsetRatio, max(0.06, original.height + dy))
                resized = plan.clampedTextFrame(resized, for: element)
            }
            page.elements[index].normalizedFrame = resized
            page.elements[index].isLayoutLocked = true
            page.elements[index].origin = .user
        }.onEnded { _ in
            guard startResizeFrame != nil else { return }
            startResizeFrame = nil
            endEdit()
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
                  let index = page.elements.firstIndex(where: { $0.id == element.id }),
                  !page.elements[index].isInteractionLocked else { return }
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
                  let index = page.elements.firstIndex(where: { $0.id == element.id }),
                  !page.elements[index].isInteractionLocked else { return }
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

/// SwiftUI counterpart of the PDF mask path. It consumes the same normalized
/// appearance contract instead of choosing a canvas-only clipping shape.
private struct MemoryBookElementMaskShape: Shape {
    let mask: MemoryBookElementMask
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        switch mask {
        case .rectangle:
            Path(rect)
        case .roundedRectangle:
            Path(roundedRect: rect, cornerRadius: min(cornerRadius, min(rect.width, rect.height) / 2))
        case .ellipse:
            Path(ellipseIn: rect)
        }
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

private struct ElementResizeHandle: View {
    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(TailorColor.ink)
            .frame(width: 32, height: 32)
            .background(Circle().fill(TailorColor.paper))
            .overlay(Circle().stroke(TailorColor.clay, lineWidth: 2))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            .contentShape(Circle())
            .accessibilityIdentifier("Element resize handle")
            .accessibilityLabel("Resize selected element")
            .accessibilityHint("Drag to change the element frame.")
    }
}

/// Reader and PDF use the same CoreText drawing implementation. This bridge
/// only supplies SwiftUI with a UIKit canvas; it performs no text layout.
private struct MemoryBookAttributedTextPreview: UIViewRepresentable {
    let snapshot: MemoryBookTextLayoutSnapshot
    let color: UIColor
    let diagnosticRole: String
    let canonicalScale: CGFloat

    func makeUIView(context: Context) -> MemoryBookPreviewTextView {
        let view = MemoryBookPreviewTextView()
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    /// SwiftUI may ask a UIKit representable for an unconstrained size before
    /// applying the outer element frame. UILabel answers that question with
    /// `CGFloat.greatestFiniteMagnitude`, which then becomes its actual text
    /// width and leaves the glyphs off-canvas. The render-plan snapshot already
    /// contains the exact editor/PDF text rectangle, so use it as the bounded
    /// fallback while retaining the shared attributed paragraph.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MemoryBookPreviewTextView, context: Context) -> CGSize? {
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

    func updateUIView(_ view: MemoryBookPreviewTextView, context: Context) {
        let attributed = MemoryBookPreviewTextAdapter.attributedString(for: snapshot, color: color)
        view.snapshot = snapshot
        view.color = color
        view.canonicalScale = canonicalScale
        view.setNeedsDisplay()
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            view.isAccessibilityElement = true
            view.accessibilityIdentifier = "Text renderer diagnostic \(diagnosticRole)"
            view.accessibilityLabel = snapshot.value
            view.configureDiagnostic(
                prefix: "snapshot=\(snapshot.value.count);attributed=\(attributed.length);color=\(color.description)"
            )
        }
    }
}

private final class MemoryBookPreviewTextView: UIView {
    var snapshot: MemoryBookTextLayoutSnapshot?
    var color: UIColor = .label
    var canonicalScale: CGFloat = 1
    private var diagnosticPrefix: String?

    override func draw(_ rect: CGRect) {
        guard let snapshot, let context = UIGraphicsGetCurrentContext() else { return }
        MemoryBookTextRenderer.draw(
            snapshot: snapshot,
            color: color,
            in: bounds,
            context: context,
            canonicalScale: canonicalScale
        )
    }

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

}

private struct ElementLayersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    let pageID: UUID?
    @Binding var selectedElementID: UUID?
    @Binding var selectedElementIDs: Set<UUID>
    let recordHistory: () -> Void
    let commit: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let pageIndex {
                    List {
                        ForEach(Array(orderedElements(pageIndex).enumerated()), id: \.element.id) { offset, element in
                            layerRow(element, number: offset + 1, pageIndex: pageIndex)
                        }
                    }
                } else {
                    ContentUnavailableView("No page selected", systemImage: "square.stack.3d.up.slash")
                }
            }
            .navigationTitle("Layers")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var pageIndex: Int? { book.pages.firstIndex(where: { $0.id == pageID }) }

    private func orderedElements(_ pageIndex: Int) -> [MemoryBookElement] {
        book.pages[pageIndex].elements.sorted {
            $0.zIndex == $1.zIndex ? $0.id.uuidString > $1.id.uuidString : $0.zIndex > $1.zIndex
        }
    }

    private func layerName(_ element: MemoryBookElement) -> String {
        if element.kind == .image { return "Photo" }
        if element.kind == .shape { return "Decoration" }
        let value = (element.text ?? "Text").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Text" : String(value.prefix(28))
    }

    private func layerIcon(_ element: MemoryBookElement) -> String {
        switch element.kind {
        case .image: "photo"
        case .text: "textformat"
        case .shape: "square.on.circle"
        }
    }

    private func layerRow(_ element: MemoryBookElement, number: Int, pageIndex: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedElementID = element.id
                if let groupID = element.groupID {
                    selectedElementIDs = Set(book.pages[pageIndex].elements.filter { $0.groupID == groupID }.map(\.id))
                } else {
                    selectedElementIDs = [element.id]
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: layerIcon(element))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(layerName(element)).lineLimit(1)
                        Text("Layer \(number) · z \(element.zIndex)").font(.caption2).foregroundStyle(TailorColor.secondaryInk)
                    }
                    Spacer()
                    if selectedElementIDs.contains(element.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(TailorColor.clay) }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Layer row \(element.id.uuidString)")

            Button { toggleVisibility(element.id, pageIndex: pageIndex) } label: {
                Image(systemName: element.isHidden ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(element.isHidden ? "Show" : "Hide") \(layerName(element)) layer")

            Button { toggleLock(element.id, pageIndex: pageIndex) } label: {
                Image(systemName: element.isInteractionLocked ? "lock.fill" : "lock.open")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(element.isInteractionLocked ? "Unlock" : "Lock") \(layerName(element)) layer")

            Menu {
                Button("Bring layer forward") { moveLayer(element.id, pageIndex: pageIndex, toFront: true, oneStep: true) }
                Button("Send layer backward") { moveLayer(element.id, pageIndex: pageIndex, toFront: false, oneStep: true) }
                Button("Bring layer to front") { moveLayer(element.id, pageIndex: pageIndex, toFront: true, oneStep: false) }
                Button("Send layer to back") { moveLayer(element.id, pageIndex: pageIndex, toFront: false, oneStep: false) }
            } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Layer actions \(layerName(element))")
        }
    }

    private func toggleVisibility(_ elementID: UUID, pageIndex: Int) {
        guard let index = book.pages[pageIndex].elements.firstIndex(where: { $0.id == elementID }) else { return }
        recordHistory()
        book.pages[pageIndex].elements[index].isHidden.toggle()
        book.pages[pageIndex].elements[index].isLayoutLocked = true
        book.pages[pageIndex].elements[index].origin = .user
        book.pages[pageIndex].elements[index].updatedAt = .now
        commit()
    }

    private func toggleLock(_ elementID: UUID, pageIndex: Int) {
        guard let index = book.pages[pageIndex].elements.firstIndex(where: { $0.id == elementID }) else { return }
        recordHistory()
        book.pages[pageIndex].elements[index].isInteractionLocked.toggle()
        book.pages[pageIndex].elements[index].origin = .user
        book.pages[pageIndex].elements[index].updatedAt = .now
        commit()
    }

    private func moveLayer(_ elementID: UUID, pageIndex: Int, toFront: Bool, oneStep: Bool) {
        guard let index = book.pages[pageIndex].elements.firstIndex(where: { $0.id == elementID }) else { return }
        let ordered = book.pages[pageIndex].elements.sorted {
            $0.zIndex == $1.zIndex ? $0.id.uuidString < $1.id.uuidString : $0.zIndex < $1.zIndex
        }
        guard let position = ordered.firstIndex(where: { $0.id == elementID }) else { return }
        let oneStepTarget = toFront ? position + 1 : position - 1
        if oneStep { guard ordered.indices.contains(oneStepTarget) else { return } }
        recordHistory()
        if oneStep {
            book.pages[pageIndex].elements[index].zIndex = ordered[oneStepTarget].zIndex + (toFront ? 1 : -1)
        } else if toFront {
            book.pages[pageIndex].elements[index].zIndex = (ordered.map(\.zIndex).max() ?? 0) + 1
        } else {
            book.pages[pageIndex].elements[index].zIndex = (ordered.map(\.zIndex).min() ?? 0) - 1
        }
        book.pages[pageIndex].elements[index].origin = .user
        book.pages[pageIndex].elements[index].updatedAt = .now
        commit()
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
                    Text(page.isLocked ? "Locked layout page" : "Editable page").font(.caption2).foregroundStyle(TailorColor.secondaryInk)
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
    @State private var appearanceTarget: AppearanceTarget?

    private struct ResetTarget: Identifiable {
        let id = UUID()
        let pageIndex: Int
        let elementIndex: Int
    }
    private struct AppearanceTarget: Identifiable {
        let id = UUID()
        let pageID: UUID
        let elementID: UUID
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
                        Button("Appearance", systemImage: "paintbrush") {
                            appearanceTarget = AppearanceTarget(pageID: book.pages[pageIndex].id, elementID: book.pages[pageIndex].elements[elementIndex].id)
                        }
                        .accessibilityIdentifier("Photo appearance")
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
                    .disabled(book.pages[pageIndex].elements[elementIndex].isInteractionLocked)
                }
                Section("Choose from selected photos") {
                    ForEach(book.eligiblePhotos) { photo in Button { insert(photo.id) } label: { HStack { PhotoAssetThumbnail(identifier: photo.assetLocalIdentifier).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 6)); VStack(alignment: .leading) { Text(photo.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "No date"); Text("Use this photo").font(.caption).foregroundStyle(TailorColor.secondaryInk) }; Spacer(); Image(systemName: "plus.circle") } }
                        .accessibilityIdentifier("Replace photo \(photo.assetLocalIdentifier)")
                    }
                }
                .disabled(selectedElementIsInteractionLocked)
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
                Text("This restores the template frame, crop, rotation, appearance, and layer order. You can still undo it.")
            }
            .sheet(item: $appearanceTarget) { target in
                PhotoAppearanceEditorSheet(
                    book: $book,
                    pageID: target.pageID,
                    elementID: target.elementID,
                    recordHistory: recordHistory,
                    commit: commit
                )
            }
        }
    }

    private var selectedElementIsInteractionLocked: Bool {
        guard let pageIndex = book.pages.firstIndex(where: { $0.id == selectedPageID }),
              let selectedElementID,
              let element = book.pages[pageIndex].elements.first(where: { $0.id == selectedElementID }) else { return false }
        return element.isInteractionLocked
    }

    private func insert(_ photoID: UUID) {
        guard !selectedElementIsInteractionLocked else { return }
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
            book.pages[pageIndex].elements[elementIndex].appearance = .default
            book.pages[pageIndex].elements[elementIndex].imageAdjustments = .default
            book.pages[pageIndex].elements[elementIndex].imageTransformAdjustments = .default
            book.pages[pageIndex].elements[elementIndex].isLayoutLocked = false
            book.pages[pageIndex].elements[elementIndex].origin = .automatic
        }
        commit()
    }
}

private struct PhotoAppearanceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    let pageID: UUID
    let elementID: UUID
    let recordHistory: () -> Void
    let commit: () -> Void
    @State private var draft: MemoryBookElementAppearance
    @State private var draftAdjustments: MemoryBookImageAdjustments
    @State private var draftTransformAdjustments: MemoryBookImageTransformAdjustments
    @State private var isAutoEnhancing = false

    init(book: Binding<MemoryBookDocument>, pageID: UUID, elementID: UUID, recordHistory: @escaping () -> Void, commit: @escaping () -> Void) {
        self._book = book
        self.pageID = pageID
        self.elementID = elementID
        self.recordHistory = recordHistory
        self.commit = commit
        let appearance = book.wrappedValue.pages
            .first(where: { $0.id == pageID })?.elements
            .first(where: { $0.id == elementID })?.appearance ?? .default
        let adjustments = book.wrappedValue.pages
            .first(where: { $0.id == pageID })?.elements
            .first(where: { $0.id == elementID })?.imageAdjustments ?? .default
        let transformAdjustments = book.wrappedValue.pages
            .first(where: { $0.id == pageID })?.elements
            .first(where: { $0.id == elementID })?.imageTransformAdjustments ?? .default
        self._draft = State(initialValue: appearance)
        self._draftAdjustments = State(initialValue: adjustments)
        self._draftTransformAdjustments = State(initialValue: transformAdjustments)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .frame(maxWidth: .infinity)
                        .listRowBackground(TailorColor.mist.opacity(0.45))
                }
                Section("Shape") {
                    Picker("Mask", selection: $draft.mask) {
                        ForEach(MemoryBookElementMask.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if draft.mask == .roundedRectangle {
                        valueSlider("Corner radius", value: $draft.cornerRadiusRatio, range: 0...0.12, percent: true)
                    }
                    valueSlider("Opacity", value: Binding(get: { CGFloat(draft.opacity) }, set: { draft.opacity = Double($0) }), range: 0.2...1, percent: true)
                    if isDecoration {
                        ColorPicker("Fill color", selection: fillColor, supportsOpacity: false)
                    }
                }
                Section("Border") {
                    Picker("Style", selection: $draft.borderStyle) {
                        ForEach(MemoryBookElementBorderStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if draft.borderStyle != .none {
                        valueSlider("Width", value: $draft.borderWidthRatio, range: 1 / 612...12 / 612, percent: false)
                        ColorPicker("Color", selection: borderColor, supportsOpacity: false)
                    }
                }
                Section("Shadow") {
                    Button(draft.shadowOpacity > 0 ? "Remove shadow" : "Add shadow", systemImage: draft.shadowOpacity > 0 ? "shadow.slash" : "shadow") {
                        draft.shadowOpacity = draft.shadowOpacity > 0 ? 0 : 0.24
                    }
                    .accessibilityIdentifier(isDecoration ? "Toggle decoration shadow" : "Toggle photo shadow")
                    if draft.shadowOpacity > 0 {
                        valueSlider("Strength", value: Binding(get: { CGFloat(draft.shadowOpacity) }, set: { draft.shadowOpacity = Double($0) }), range: 0.05...0.60, percent: true)
                        valueSlider("Softness", value: $draft.shadowBlurRatio, range: 2 / 612...30 / 612, percent: false)
                        valueSlider("Horizontal", value: Binding(get: { draft.shadowOffset.width }, set: { draft.shadowOffset.width = $0 }), range: -20 / 612...20 / 612, percent: false)
                        valueSlider("Vertical", value: Binding(get: { draft.shadowOffset.height }, set: { draft.shadowOffset.height = $0 }), range: -20 / 612...20 / 612, percent: false)
                    }
                }
                if !isDecoration {
                Section("Photo geometry") {
                    HStack {
                        Button {
                            draftTransformAdjustments.flipHorizontal.toggle()
                        } label: {
                            Label(
                                draftTransformAdjustments.flipHorizontal ? "Horizontal flipped" : "Flip horizontal",
                                systemImage: draftTransformAdjustments.flipHorizontal
                                    ? "checkmark.circle.fill"
                                    : "arrow.left.and.right.righttriangle.left.righttriangle.right"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(draftTransformAdjustments.flipHorizontal ? TailorColor.clay : TailorColor.ink)
                        .accessibilityIdentifier("Flip photo horizontal")
                        .accessibilityValue(draftTransformAdjustments.flipHorizontal ? "On" : "Off")
                        Button {
                            draftTransformAdjustments.flipVertical.toggle()
                        } label: {
                            Label(
                                draftTransformAdjustments.flipVertical ? "Vertical flipped" : "Flip vertical",
                                systemImage: draftTransformAdjustments.flipVertical
                                    ? "checkmark.circle.fill"
                                    : "arrow.up.and.down.righttriangle.up.righttriangle.down"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(draftTransformAdjustments.flipVertical ? TailorColor.clay : TailorColor.ink)
                        .accessibilityIdentifier("Flip photo vertical")
                        .accessibilityValue(draftTransformAdjustments.flipVertical ? "On" : "Off")
                    }
                    if selectedElement?.imageContentMode == .fill {
                        adjustmentSlider("Straighten", value: $draftTransformAdjustments.straightenDegrees, range: -15...15)
                    } else {
                        Text("Straighten is available with Fill frame so the final image never exposes a blank edge.")
                            .font(.caption)
                            .foregroundStyle(TailorColor.secondaryInk)
                    }
                    Button("Reset photo geometry", role: .destructive) { draftTransformAdjustments = .default }
                }
                Section("Photo finishing") {
                    Button {
                        autoEnhance()
                    } label: {
                        HStack {
                            Label("Auto Enhance", systemImage: "wand.and.stars")
                            Spacer()
                            if isAutoEnhancing { ProgressView() }
                        }
                    }
                    .disabled(isAutoEnhancing)
                    .accessibilityIdentifier("Photo auto enhance")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            presetButton("Natural", adjustments: .default)
                            presetButton("Bright & clean", adjustments: .init(exposure: 0.30, brightness: 0.04, contrast: 1.04, saturation: 1.03, warmth: 0, highlights: 0.16, shadows: 0.18, vignette: 0, sharpness: 0.18))
                            presetButton("Warm memory", adjustments: .init(exposure: 0.10, brightness: 0.02, contrast: 1.06, saturation: 0.94, warmth: 0.28, highlights: 0.12, shadows: 0.12, vignette: 0.12, sharpness: 0.10))
                            presetButton("Soft portrait", adjustments: .init(exposure: 0.12, brightness: 0.03, contrast: 0.94, saturation: 0.96, warmth: 0.10, highlights: 0.24, shadows: 0.28, vignette: 0.08, sharpness: 0.05))
                            presetButton("Editorial", adjustments: .init(exposure: 0, brightness: 0, contrast: 1.16, saturation: 0.82, warmth: -0.08, highlights: 0.18, shadows: 0.08, vignette: 0.26, sharpness: 0.24))
                        }
                    }
                    adjustmentSlider("Exposure", value: $draftAdjustments.exposure, range: -2...2)
                    adjustmentSlider("Brightness", value: $draftAdjustments.brightness, range: -0.5...0.5)
                    adjustmentSlider("Contrast", value: $draftAdjustments.contrast, range: 0.5...1.5)
                    adjustmentSlider("Saturation", value: $draftAdjustments.saturation, range: 0...2)
                    adjustmentSlider("Warmth", value: $draftAdjustments.warmth, range: -1...1)
                    adjustmentSlider("Highlights", value: $draftAdjustments.highlights, range: 0...1)
                    adjustmentSlider("Shadows", value: $draftAdjustments.shadows, range: -1...1)
                    adjustmentSlider("Vignette", value: $draftAdjustments.vignette, range: 0...1)
                    adjustmentSlider("Sharpness", value: $draftAdjustments.sharpness, range: 0...1)
                    Button("Reset photo finishing", role: .destructive) { draftAdjustments = .default }
                }
                }
                Section {
                    Button("Restore appearance defaults", role: .destructive) { draft = .default }
                }
            }
            .navigationTitle(isDecoration ? "Decoration appearance" : "Photo appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply", action: apply).fontWeight(.bold) }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        let width: CGFloat = 260
        let height: CGFloat = 180
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(TailorColor.paper)
            if isDecoration {
                MemoryBookElementMaskShape(mask: draft.mask, cornerRadius: draft.cornerRadiusRatio * 612)
                    .fill(fillPreviewColor)
                    .frame(width: width, height: height)
                    .overlay {
                        if draft.borderStyle != .none {
                            MemoryBookElementMaskShape(mask: draft.mask, cornerRadius: draft.cornerRadiusRatio * 612)
                                .stroke(Color(red: draft.borderColor.red, green: draft.borderColor.green, blue: draft.borderColor.blue), style: StrokeStyle(lineWidth: draft.borderWidthRatio * 612, dash: draft.borderStyle == .dashed ? [6, 4] : []))
                        }
                    }
                    .shadow(color: .black.opacity(draft.shadowOpacity), radius: draft.shadowBlurRatio * 612, x: draft.shadowOffset.width * 612, y: draft.shadowOffset.height * 612)
                    .opacity(draft.opacity)
            } else if let identifier = photoIdentifier {
                PhotoAssetThumbnail(identifier: identifier, adjustments: draftAdjustments)
                    .frame(width: width, height: height)
                    .scaleEffect(previewStraightenScale)
                    .scaleEffect(x: draftTransformAdjustments.flipHorizontal ? -1 : 1, y: draftTransformAdjustments.flipVertical ? -1 : 1)
                    .rotationEffect(.degrees(draftTransformAdjustments.straightenDegrees))
                    .clipShape(MemoryBookElementMaskShape(mask: draft.mask, cornerRadius: draft.cornerRadiusRatio * 612))
                    .overlay {
                        if draft.borderStyle != .none {
                            MemoryBookElementMaskShape(mask: draft.mask, cornerRadius: draft.cornerRadiusRatio * 612)
                                .stroke(Color(red: draft.borderColor.red, green: draft.borderColor.green, blue: draft.borderColor.blue), style: StrokeStyle(lineWidth: draft.borderWidthRatio * 612, dash: draft.borderStyle == .dashed ? [6, 4] : []))
                        }
                    }
                    .shadow(color: .black.opacity(draft.shadowOpacity), radius: draft.shadowBlurRatio * 612, x: draft.shadowOffset.width * 612, y: draft.shadowOffset.height * 612)
                    .opacity(draft.opacity)
            } else {
                ContentUnavailableView("Photo unavailable", systemImage: "photo.badge.exclamationmark")
            }
        }
        .frame(width: width + 36, height: height + 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Appearance preview")
    }

    private func valueSlider(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, percent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(percent ? "\(Int((value.wrappedValue * 100).rounded()))%" : "\(Int((value.wrappedValue * 612).rounded())) pt")
                    .foregroundStyle(TailorColor.secondaryInk)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
                .accessibilityIdentifier("Adjustment slider \(title)")
        }
    }

    private func adjustmentSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())))
                    .foregroundStyle(TailorColor.secondaryInk)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
                .accessibilityIdentifier("Adjustment slider \(title)")
        }
    }

    private func presetButton(_ title: String, adjustments: MemoryBookImageAdjustments) -> some View {
        Button(title) { draftAdjustments = adjustments }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityLabel("Photo preset \(title)")
    }

    private var borderColor: Binding<Color> {
        Binding(
            get: { Color(red: draft.borderColor.red, green: draft.borderColor.green, blue: draft.borderColor.blue) },
            set: { value in
                let color = UIColor(value)
                var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
                if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                    draft.borderColor = .init(red: red, green: green, blue: blue)
                }
            }
        )
    }

    private var fillColor: Binding<Color> {
        Binding(
            get: { fillPreviewColor },
            set: { value in
                let color = UIColor(value)
                var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
                if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                    draft.fillColor = .init(red: red, green: green, blue: blue)
                }
            }
        )
    }

    private var fillPreviewColor: Color {
        let rgb = draft.fillColor ?? .init(red: 0.72, green: 0.29, blue: 0.17)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    private var isDecoration: Bool { selectedElement?.kind == .shape }

    private var previewStraightenScale: CGFloat {
        guard selectedElement?.imageContentMode == .fill else { return 1 }
        return FillCropConstraint(
            sourceAspect: photoAspect,
            containerAspect: 260 / 180,
            rotationDegrees: draftTransformAdjustments.straightenDegrees
        ).minimumScale
    }

    private var photoAspect: CGFloat {
        guard let assetID = selectedElement?.assetID else { return 1 }
        return book.photos.first(where: { $0.id == assetID })?.aspectRatio ?? 1
    }

    private var selectedElement: MemoryBookElement? {
        book.pages.first(where: { $0.id == pageID })?.elements.first(where: { $0.id == elementID })
    }

    private var photoIdentifier: String? {
        guard let assetID = book.pages.first(where: { $0.id == pageID })?.elements.first(where: { $0.id == elementID })?.assetID else { return nil }
        return book.photos.first(where: { $0.id == assetID })?.assetLocalIdentifier
    }

    private func apply() {
        guard let pageIndex = book.pages.firstIndex(where: { $0.id == pageID }),
              let elementIndex = book.pages[pageIndex].elements.firstIndex(where: { $0.id == elementID }) else { dismiss(); return }
        draft.normalize()
        draftAdjustments.normalize()
        draftTransformAdjustments.normalize()
        guard book.pages[pageIndex].elements[elementIndex].appearance != draft
                || book.pages[pageIndex].elements[elementIndex].imageAdjustments != draftAdjustments
                || book.pages[pageIndex].elements[elementIndex].imageTransformAdjustments != draftTransformAdjustments
        else { dismiss(); return }
        recordHistory()
        book.pages[pageIndex].elements[elementIndex].appearance = draft
        book.pages[pageIndex].elements[elementIndex].imageAdjustments = draftAdjustments
        book.pages[pageIndex].elements[elementIndex].imageTransformAdjustments = draftTransformAdjustments
        let element = book.pages[pageIndex].elements[elementIndex]
        _ = book.applyCrop(
            pageID: pageID,
            elementID: elementID,
            scale: element.cropScale,
            offset: element.cropOffset,
            sourceAspect: photoAspect
        )
        book.pages[pageIndex].elements[elementIndex].origin = .user
        book.pages[pageIndex].elements[elementIndex].updatedAt = .now
        commit()
        dismiss()
    }

    private func autoEnhance() {
        guard let identifier = photoIdentifier else { return }
        isAutoEnhancing = true
        Task {
            let image = await PhotoAssetImageLoader.image(identifier: identifier)
            await MainActor.run {
                if let image { draftAdjustments = MemoryBookImageProcessor.conservativeAutoEnhancement(for: image) }
                isAutoEnhancing = false
            }
        }
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
        format: "scale=%.3f;offsetX=%.3f;offsetY=%.3f;rotation=%.1f;z=%d;mask=%@;opacity=%.2f;border=%@;shadow=%.2f;ev=%.2f;contrast=%.2f;saturation=%.2f;warmth=%.2f;straighten=%.1f;flipH=%@;flipV=%@",
        Double(element.cropScale),
        Double(element.cropOffset.width),
        Double(element.cropOffset.height),
        Double(element.rotationDegrees),
        element.zIndex,
        element.appearance.mask.rawValue,
        element.appearance.opacity,
        element.appearance.borderStyle.rawValue,
        element.appearance.shadowOpacity,
        element.imageAdjustments.exposure,
        element.imageAdjustments.contrast,
        element.imageAdjustments.saturation,
        element.imageAdjustments.warmth,
        element.imageTransformAdjustments.straightenDegrees,
        element.imageTransformAdjustments.flipHorizontal ? "true" : "false",
        element.imageTransformAdjustments.flipVertical ? "true" : "false"
    )
}

/// Stable document readback for the text editor's no-commit Fit failure gate.
/// It deliberately reports the persisted normalized geometry, rather than a
/// presentation-layer frame, so the test covers the model used by PDF export.
private func memoryBookTextFrameMarker(_ element: MemoryBookElement, layout: MemoryBookTextLayoutSnapshot, paperRect: CGRect) -> String {
    func normalized(_ rect: CGRect) -> String {
        String(format: "%.3f,%.3f,%.3f,%.3f", Double((rect.minX - paperRect.minX) / paperRect.width), Double((rect.minY - paperRect.minY) / paperRect.height), Double(rect.width / paperRect.width), Double(rect.height / paperRect.height))
    }
    let color = element.textCustomColor.map { String(format: "custom(%.3f,%.3f,%.3f)", $0.red, $0.green, $0.blue) } ?? element.textColor.rawValue
    return String(
        format: "x=%.3f;y=%.3f;width=%.3f;height=%.3f;z=%d;alignment=%@;tracking=%.3f;lineHeight=%.3f;paragraph=%.3f;color=%@;editable=%@;protected=%@",
        Double(element.normalizedFrame.origin.x),
        Double(element.normalizedFrame.origin.y),
        Double(element.normalizedFrame.width),
        Double(element.normalizedFrame.height),
        element.zIndex,
        element.textTypographyAdjustments.alignment.rawValue,
        Double(element.textTypographyAdjustments.trackingEm),
        Double(element.textTypographyAdjustments.lineHeightMultiple),
        Double(element.textTypographyAdjustments.paragraphSpacingEm),
        color,
        normalized(layout.spec.editableRect),
        layout.spec.protectedRects.map(normalized).joined(separator: "|")
    )
}

private func memoryBookNormalizedFrameMarker(_ frame: CGRect) -> String {
    String(format: "x=%.4f;y=%.4f;width=%.4f;height=%.4f", Double(frame.minX), Double(frame.minY), Double(frame.width), Double(frame.height))
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
                            PhotoAssetThumbnail(identifier: target.photo.assetLocalIdentifier, treatment: MemoryBookPageStyle.resolve(book.pages[target.pageIndex].styleOverride ?? book.style).imageTreatment, adjustments: target.element.imageAdjustments)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                            Color.black.opacity(0.72).ignoresSafeArea().allowsHitTesting(false)
                            let draftElement = MemoryBookElement(
                                id: target.element.id, kind: .image, assetID: target.element.assetID,
                                normalizedFrame: target.element.normalizedFrame,
                                cropScale: session.draftTransform.scale, cropOffset: session.draftTransform.offset,
                                rotationDegrees: target.element.rotationDegrees, zIndex: target.element.zIndex,
                                textStyle: target.element.textStyle, imageContentMode: target.element.imageContentMode,
                                textFont: target.element.textFont, textColor: target.element.textColor, isLayoutLocked: target.element.isLayoutLocked, isInteractionLocked: target.element.isInteractionLocked, groupID: target.element.groupID, isHidden: target.element.isHidden, appearance: target.element.appearance, imageAdjustments: target.element.imageAdjustments, imageTransformAdjustments: target.element.imageTransformAdjustments,
                                origin: target.element.origin
                            )
                            let geometry = MemoryBookImageTransformGeometry(container: frame, sourceAspect: target.photo.aspectRatio, element: draftElement)
                            MemoryBookImageTransform(geometry: geometry) {
                                PhotoAssetThumbnail(identifier: target.photo.assetLocalIdentifier, treatment: MemoryBookPageStyle.resolve(book.pages[target.pageIndex].styleOverride ?? book.style).imageTreatment, adjustments: target.element.imageAdjustments)
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
        guard let target, let session else { dismiss(); return }
        // Done is also an explicit composition approval. An untouched
        // automatic crop may have been opened from Book Check specifically so
        // the user can confirm that the subject is framed acceptably; requiring
        // a meaningless nudge would make that blocking issue impossible to
        // resolve. Already-authored unchanged crops still dismiss without a
        // redundant history entry.
        let confirmsAutomaticCrop = target.element.origin == .automatic
        guard session.hasUncommittedChanges || confirmsAutomaticCrop else { dismiss(); return }
        recordHistory()
        if book.applyCrop(pageID: pageID, elementID: elementID, scale: session.draftTransform.scale, offset: session.draftTransform.offset, sourceAspect: target.photo.aspectRatio) {
            commit()
        }
        exitState = .dismissed
        dismiss()
    }
}

private enum TextHierarchyPreset {
    case editorialTitle, quietCaption, personalNote
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
    @State private var typography = MemoryBookTextTypographyAdjustments.default
    @State private var field: MemoryBookTextField?
    @State private var baselineText = ""
    @State private var baselineStyle: MemoryBookTextStyle = .standard
    @State private var baselineFontScale: CGFloat = 1
    @State private var baselineFont: MemoryBookTextFont = .editorial
    @State private var baselineColor: MemoryBookTextColor = .ink
    @State private var baselineCustomColor: MemoryBookRGB?
    @State private var baselineTypography = MemoryBookTextTypographyAdjustments.default
    @State private var forceCreateFreeText = false
    @State private var confirmExit = false
    @FocusState private var isTextInputFocused: Bool

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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        hierarchyPresetButton("Editorial title", preset: .editorialTitle)
                        hierarchyPresetButton("Quiet caption", preset: .quietCaption)
                        hierarchyPresetButton("Personal note", preset: .personalNote)
                    }
                }
                Picker("Alignment", selection: $typography.alignment) {
                    Label("Left", systemImage: "text.alignleft").tag(MemoryBookTextAlignment.leading)
                    Label("Center", systemImage: "text.aligncenter").tag(MemoryBookTextAlignment.center)
                    Label("Right", systemImage: "text.alignright").tag(MemoryBookTextAlignment.trailing)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("Text alignment")
                TextEditor(text: $text)
                    .focused($isTextInputFocused)
                    .frame(minHeight: 150)
                    .accessibilityIdentifier("Text draft input")
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
                Section("Typography") {
                    typographySlider("Tracking", value: $typography.trackingEm, range: -0.05...0.20, format: { String(format: "%+.2f em", $0) })
                    typographySlider("Line height", value: $typography.lineHeightMultiple, range: 0.90...2, format: { String(format: "%.2f×", $0) })
                    typographySlider("Paragraph spacing", value: $typography.paragraphSpacingEm, range: 0...1.5, format: { String(format: "%.2f em", $0) })
                    Button("Reset typography", role: .destructive) { typography = .default }
                }
            }
        }
            .safeAreaInset(edge: .bottom, spacing: 0) { editorStatusBar }
            .navigationTitle("Edit text").onAppear(perform: load).onChange(of: text) { _, _ in updateHighlight() }.onChange(of: textStyle) { _, _ in updateHighlight() }.onChange(of: textFontScale) { _, _ in updateHighlight() }.onChange(of: typography) { _, _ in updateHighlight() }.scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(isDirty)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { if save() { draftHighlight = nil; dismiss() } }.accessibilityIdentifier("Text draft done") }; ToolbarItem(placement: .cancellationAction) { Button("Back") { if isDirty { confirmExit = true } else { dismiss() } }.accessibilityIdentifier("Text draft back") } }
            .confirmationDialog("Keep this text draft?", isPresented: $confirmExit) {
                Button("Keep editing") {}
                    .accessibilityIdentifier("Text draft keep editing")
                Button("Save") { if save() { draftHighlight = nil; dismiss() } }
                    .accessibilityIdentifier("Text draft save")
                Button("Discard", role: .destructive) { text = baselineText; textStyle = baselineStyle; textFontScale = baselineFontScale; textFont = baselineFont; textColor = baselineColor; textCustomColor = baselineCustomColor; typography = baselineTypography; draftHighlight = nil; dismiss() }
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
    private var existingFields: [MemoryBookTextField] {
        guard let page else { return [] }
        var seen = Set<MemoryBookTextField>()
        return page.elements.compactMap(\.textField).filter { role in
            role.isAllowed(on: page.kind) && seen.insert(role).inserted
        }
    }
    private var addableFields: [MemoryBookTextField] { guard let page else { return [] }; return MemoryBookBuilder.optionalTextFields(for: page.kind).filter { !existingFields.contains($0) } }
    private var validation: MemoryBookTextDraftValidation? { guard let page, let field else { return nil }; let e = selectedTextElement; return book.textDraftValidation(text: text, style: textStyle, fontScale: textFontScale, typography: typography, normalizedFrame: e?.normalizedFrame ?? MemoryBookBuilder.defaultTextFrame(for: field), on: page, zIndex: e?.zIndex ?? 9, field: field) }
    private var readability: MemoryBookTextReadabilityAssessment? {
        guard let page, let field else { return nil }
        let element = selectedTextElement
        return book.textReadability(
            style: textStyle,
            fontScale: textFontScale,
            color: textColor,
            customColor: textCustomColor,
            normalizedFrame: element?.normalizedFrame ?? MemoryBookBuilder.defaultTextFrame(for: field),
            on: page,
            zIndex: element?.zIndex ?? 9,
            field: field
        )
    }
    private var isDirty: Bool { text != baselineText || textStyle != baselineStyle || textFontScale != baselineFontScale || textFont != baselineFont || textColor != baselineColor || textCustomColor != baselineCustomColor || typography != baselineTypography }
    private var shouldWarnAboutContrast: Bool {
        guard let page, let readability else { return false }
        return !readability.hasSufficientContrast && (page.backgroundColor != nil || textCustomColor != nil || textColor != .ink)
    }
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
    @ViewBuilder private func typographySlider(
        _ title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        format: @escaping (CGFloat) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value.wrappedValue)).foregroundStyle(TailorColor.secondaryInk)
            }
            Slider(value: value, in: range)
                .accessibilityIdentifier("Text typography \(title)")
                .accessibilityValue(format(value.wrappedValue))
        }
    }
    private func applyTypographyPreset(_ preset: TextHierarchyPreset) {
        switch preset {
        case .editorialTitle:
            textStyle = .large
            textFontScale = 1.10
            textFont = .editorial
            typography = .init(alignment: .leading, trackingEm: 0.01, lineHeightMultiple: 1.08, paragraphSpacingEm: 0.20)
        case .quietCaption:
            textStyle = .small
            textFontScale = 0.95
            textFont = .quietSans
            typography = .init(alignment: .leading, trackingEm: 0.02, lineHeightMultiple: 1.35, paragraphSpacingEm: 0.35)
        case .personalNote:
            textStyle = .standard
            textFontScale = 1
            textFont = .handwritten
            typography = .init(alignment: .leading, trackingEm: 0, lineHeightMultiple: 1.42, paragraphSpacingEm: 0.45)
        }
    }
    private func hierarchyPresetButton(_ title: String, preset: TextHierarchyPreset) -> some View {
        Button(title) { applyTypographyPreset(preset) }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("Text preset \(title)")
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
        typography = target?.textTypographyAdjustments ?? .default
        baselineText = text; baselineStyle = textStyle; baselineFontScale = textFontScale; baselineFont = textFont; baselineColor = textColor; baselineCustomColor = textCustomColor; baselineTypography = typography
        updateHighlight()
    }
    private func create(_ role: MemoryBookTextField) { forceCreateFreeText = false; field = role; text = ""; textStyle = .standard; textFontScale = 1; textFont = .editorial; textColor = .ink; textCustomColor = nil; typography = .default; baselineText = ""; baselineStyle = .standard; baselineFontScale = 1; baselineFont = .editorial; baselineColor = .ink; baselineCustomColor = nil; baselineTypography = .default; updateHighlight() }
    private func createFreeText() {
        // A free note is not tied to an existing semantic field.  Deferring
        // insertion until Save means Back/Discard leaves no empty ghost layer.
        forceCreateFreeText = true
        field = .legacyUserNote; text = ""; textStyle = .standard; textFontScale = 1; textFont = .editorial; textColor = .ink; textCustomColor = nil; typography = .default
        baselineText = ""; baselineStyle = .standard; baselineFontScale = 1; baselineFont = .editorial; baselineColor = .ink; baselineCustomColor = nil; baselineTypography = .default
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
            book.pages[pageIndex].elements[index].textTypographyAdjustments = typography
            book.pages[pageIndex].elements[index].textField = field
            book.pages[pageIndex].elements[index].origin = .user
        } else {
            let topLayer = (book.pages[pageIndex].elements.map(\.zIndex).max() ?? 9) + 1
            book.pages[pageIndex].elements.append(MemoryBookElement(kind: .text, text: text, normalizedFrame: MemoryBookBuilder.defaultTextFrame(for: field), zIndex: topLayer, textStyle: textStyle, textFontScale: textFontScale, textFont: textFont, textColor: textColor, textCustomColor: textCustomColor, textTypographyAdjustments: typography, textField: field, isLayoutLocked: true, origin: .user))
        }
        forceCreateFreeText = false
        commit(); baselineText = text; baselineStyle = textStyle; baselineFontScale = textFontScale; baselineFont = textFont; baselineColor = textColor; baselineCustomColor = textCustomColor; baselineTypography = typography; updateHighlight(); return true
    }
    private func fitText() {
        guard let page, let field, let element = selectedTextElement else { return }
        let candidates: [MemoryBookTextStyle] = textStyle == .large ? [.standard, .small] : (textStyle == .standard ? [.small] : [])
        guard let style = candidates.first(where: { book.textDraftValidation(text: text, style: $0, fontScale: textFontScale, typography: typography, normalizedFrame: element.normalizedFrame, on: page, zIndex: element.zIndex, field: field).isValid }) else { updateHighlight(); return }
        textStyle = style; _ = save()
    }
    private func useReadableColor() {
        guard let readability else { return }
        textCustomColor = readability.recommendedForeground
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
                    if let readability {
                        Text(String(format: "%.0f pt · %.1f:1", readability.fontSize, readability.contrastRatio))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(shouldWarnAboutContrast ? .orange : TailorColor.secondaryInk)
                            .accessibilityIdentifier("Text print readability")
                            .accessibilityValue(String(format: "%.0f point text, %.1f to 1 contrast", readability.fontSize, readability.contrastRatio))
                    }
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
                if let readability, shouldWarnAboutContrast {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.lefthalf.filled").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(String(format: "Low text contrast (%.1f:1)", readability.contrastRatio))
                                .font(.footnote.weight(.semibold))
                                .accessibilityIdentifier("Text contrast warning")
                            Text("The color may fade into this page when printed. You can keep it, or use Tailor's coordinated readable color.")
                                .font(.caption)
                            Button("Use readable color", action: useReadableColor)
                                .font(.footnote.weight(.bold))
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .foregroundStyle(.white)
                                .accessibilityIdentifier("Use readable text color")
                                .accessibilityLabel("Use readable text color")
                        }
                    }
                    .foregroundStyle(.orange)
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
    @State private var showBackgroundEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section("Apply to entire book") {
                    ForEach(AlbumStyle.allCases, id: \.self) { style in
                        Button {
                            recordHistory(); book.style = style; book.profile.albumStyle = style; commit(); dismiss()
                        } label: {
                            HStack { Text(style.label); Spacer(); if book.style == style { Image(systemName: "checkmark") } }
                                .foregroundStyle(TailorColor.ink)
                        }
                    }
                }
                Section("This page") {
                    Button("Customize background", systemImage: "paintbrush.pointed") { showBackgroundEditor = true }
                        .disabled(selectedPageID == nil)
                    Button("Use book style") { override(nil) }
                    ForEach(AlbumStyle.allCases, id: \.self) { style in Button(style.label) { override(style) } }
                }
                if chapterPageIDs.count > 1 {
                    Section("This chapter") {
                        Text("Applies the coordinated style to unlocked pages only. Custom backgrounds, crops, text and locked pages stay unchanged.")
                            .font(.caption)
                            .foregroundStyle(TailorColor.secondaryInk)
                        ForEach(AlbumStyle.allCases, id: \.self) { style in
                            Button("Apply \(style.label) to chapter") { overrideChapter(style) }
                                .accessibilityIdentifier("Apply chapter style \(style.rawValue)")
                        }
                    }
                }
            }
            .navigationTitle("Style")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showBackgroundEditor) {
                if let selectedPageID {
                    PageBackgroundEditorSheet(
                        book: $book,
                        pageID: selectedPageID,
                        recordHistory: recordHistory,
                        commit: commit
                    )
                }
            }
        }
    }
    private func override(_ style: AlbumStyle?) { guard let index = book.pages.firstIndex(where: { $0.id == selectedPageID }) else { return }; recordHistory(); book.pages[index].styleOverride = style; commit(); dismiss() }
    private var chapterPageIDs: Set<UUID> {
        guard let selected = book.pages.first(where: { $0.id == selectedPageID }), let chapterID = selected.chapterID else { return [] }
        return Set(book.pages.filter { $0.chapterID == chapterID }.map(\.id))
    }
    private func overrideChapter(_ style: AlbumStyle) {
        var updated = book
        guard updated.applyStyleOverride(style, to: chapterPageIDs) > 0 else { dismiss(); return }
        recordHistory()
        book = updated
        commit()
        dismiss()
    }
}

/// Screen 16. It deliberately owns a temporary draft: Cancel cannot mutate the
/// editor book, while Apply commits one atomic change before returning to 11.
struct EditorStyleFeatureView: View {
    @Binding var book: MemoryBookDocument?
    let selectedPageID: UUID?
    let apply: () -> Void
    let cancel: () -> Void
    @State private var draftStyle: AlbumStyle = .warmPaper
    @State private var scope = 0

    var body: some View {
        TailorScreen(eyebrow: "STYLE", title: "Set the page mood.", back: cancel) {
            TailorInfoCard(symbol: "paintpalette", title: "TEMPORARY STYLE FRAME", message: "Apply returns to your current page editor. Cancel leaves every page unchanged.")
            Picker("Apply style to", selection: $scope) {
                Text("This page").tag(0)
                Text("Entire book").tag(1)
            }
            .pickerStyle(.segmented)
            ForEach(AlbumStyle.allCases, id: \.self) { style in
                Button {
                    draftStyle = style
                } label: {
                    HStack {
                        Circle().fill(Color(red: MemoryBookPageStyle.resolve(style).accent.red, green: MemoryBookPageStyle.resolve(style).accent.green, blue: MemoryBookPageStyle.resolve(style).accent.blue)).frame(width: 22, height: 22)
                        Text(style.label)
                        Spacer()
                        if draftStyle == style { Image(systemName: "checkmark.circle.fill") }
                    }
                    .padding(14).foregroundStyle(TailorColor.ink)
                    .background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            TailorPrimaryButton(title: "Apply style", action: commit)
                .accessibilityIdentifier("Editor style apply")
            Button("Cancel", action: cancel).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay).frame(maxWidth: .infinity)
                .accessibilityIdentifier("Editor style cancel")
        }
        .onAppear { draftStyle = book?.style ?? .warmPaper }
    }

    private func commit() {
        guard var updated = book else { cancel(); return }
        if scope == 1 {
            updated.style = draftStyle
            updated.profile.albumStyle = draftStyle
        } else if let pageID = selectedPageID, let index = updated.pages.firstIndex(where: { $0.id == pageID }) {
            updated.pages[index].styleOverride = draftStyle
        } else {
            updated.style = draftStyle
            updated.profile.albumStyle = draftStyle
        }
        updated.beginNewRevision()
        book = updated
        apply()
    }
}

struct LatestEditsCheckingView: View {
    var body: some View {
        TailorScreen(eyebrow: "BOOK CHECK", title: "CHECKING LATEST EDITS", back: nil) {
            VStack(spacing: 18) {
                ProgressView().controlSize(.large)
                Text("Checking this new revision, paper size, and current print rules before continuing.")
                    .font(.callout).multilineTextAlignment(.center).foregroundStyle(TailorColor.secondaryInk)
                Text("Please wait — preview, purchase, and export stay unavailable until this check finishes.")
                    .font(.footnote.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(TailorColor.ink)
            }.frame(maxWidth: .infinity, minHeight: 300)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Checking latest edits")
    }
}

private struct PageBackgroundEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    let pageID: UUID
    let recordHistory: () -> Void
    let commit: () -> Void
    @State private var draft: MemoryBookRGB?

    init(book: Binding<MemoryBookDocument>, pageID: UUID, recordHistory: @escaping () -> Void, commit: @escaping () -> Void) {
        _book = book
        self.pageID = pageID
        self.recordHistory = recordHistory
        self.commit = commit
        _draft = State(initialValue: book.wrappedValue.pages.first(where: { $0.id == pageID })?.backgroundColor)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(previewColor)
                        .overlay {
                            VStack(spacing: 8) {
                                Text("A page to remember").font(.system(.title2, design: .serif)).foregroundStyle(previewInk)
                                Text("Preview with the current style").font(.caption).foregroundStyle(previewInk.opacity(0.68))
                            }
                        }
                        .frame(height: 190)
                        .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
                        .accessibilityIdentifier("Page background preview")
                }
                Section("Curated backgrounds") {
                    backgroundButton("Style original", color: nil)
                    backgroundButton("Warm ivory", color: .init(red: 0.97, green: 0.93, blue: 0.84))
                    backgroundButton("Soft blush", color: .init(red: 0.95, green: 0.86, blue: 0.82))
                    backgroundButton("Quiet sage", color: .init(red: 0.82, green: 0.87, blue: 0.78))
                }
                Section("Custom") {
                    ColorPicker("Background color", selection: customColor, supportsOpacity: false)
                        .accessibilityIdentifier("Page background color")
                    Text("Tailor keeps the current style's typography and texture. Review contrast in the preview before applying.")
                        .font(.caption)
                        .foregroundStyle(TailorColor.secondaryInk)
                }
            }
            .navigationTitle("Page background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply", action: apply).fontWeight(.bold) }
            }
        }
    }

    private var style: MemoryBookPageStyle {
        guard let page = book.pages.first(where: { $0.id == pageID }) else { return .resolve(book.style) }
        return .resolve(page.styleOverride ?? book.style)
    }

    private var previewColor: Color {
        let color = draft ?? style.paper
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private var previewInk: Color {
        let ink = style.ink
        return Color(red: ink.red, green: ink.green, blue: ink.blue)
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { previewColor },
            set: { value in
                let color = UIColor(value)
                var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
                if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                    draft = .init(red: red, green: green, blue: blue)
                }
            }
        )
    }

    private func backgroundButton(_ title: String, color: MemoryBookRGB?) -> some View {
        Button {
            draft = color
        } label: {
            HStack {
                Circle()
                    .fill(Color(red: (color ?? style.paper).red, green: (color ?? style.paper).green, blue: (color ?? style.paper).blue))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(TailorColor.secondaryInk.opacity(0.25)))
                Text(title)
                Spacer()
                if draft == color { Image(systemName: "checkmark.circle.fill").foregroundStyle(TailorColor.clay) }
            }
        }
        .accessibilityIdentifier("Background preset \(title)")
    }

    private func apply() {
        guard let index = book.pages.firstIndex(where: { $0.id == pageID }), book.pages[index].backgroundColor != draft else { dismiss(); return }
        recordHistory()
        book.pages[index].backgroundColor = draft
        commit()
        dismiss()
    }
}

private struct BookCheckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var book: MemoryBookDocument
    let assetIsAvailable: (ArchivePhoto) -> Bool
    let selectIssue: (MemoryBookIssue) -> Void
    let recordHistory: () -> Void
    let commit: () -> Void
    private var issues: [MemoryBookIssue] { book.checkBook(assetIsAvailable: assetIsAvailable) }
    var body: some View {
        NavigationStack {
            List {
                if issues.isEmpty {
                    ContentUnavailableView("Your book is ready to preview", systemImage: "checkmark.seal")
                } else {
                    ForEach(issues) { issue in
                        HStack(alignment: .top) {
                            Image(systemName: issue.severity == .blocking ? "exclamationmark.triangle.fill" : "lightbulb")
                                .foregroundStyle(issue.severity == .blocking ? .red : TailorColor.clay)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(issue.severity == .blocking ? "Needs attention" : "Suggestion").font(.caption.weight(.bold))
                                Text(issue.message)
                                HStack {
                                    if let repair = issue.repair {
                                        Button(repair.actionLabel) { applyRepair(issue) }
                                            .buttonStyle(.borderedProminent)
                                            .tint(TailorColor.clay)
                                            .accessibilityIdentifier("Book check fix \(repair.actionLabel) \(issue.field?.rawValue ?? issue.elementID?.uuidString ?? "document")")
                                    }
                                    if issue.pageID != nil {
                                        Button(issue.field == nil ? "Go" : "Go to text field") { selectIssue(issue) }
                                            .buttonStyle(.bordered)
                                            .accessibilityIdentifier("Book check go \(issue.field?.rawValue ?? issue.elementID?.uuidString ?? "page")")
                                            .accessibilityLabel(issue.field.map { "Go to \($0.rawValue) text field" } ?? "Go: \(issue.message)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Book check")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func applyRepair(_ issue: MemoryBookIssue) {
        var updated = book
        guard updated.applyBookCheckRepair(issue) else { return }
        recordHistory()
        book = updated
        commit()
    }
}

struct BookCheckFeatureView: View {
    @Binding var book: MemoryBookDocument?
    @Binding var focusedIssueKey: String?
    let editIssue: (BookCheckNavigationTarget) -> Void
    let continueFlow: () -> Void
    let back: () -> Void
    let persist: () -> Void
    @State private var pendingIgnoreIssue: MemoryBookIssue?

    private var issues: [MemoryBookIssue] {
        book?.checkBook(assetIsAvailable: PhotoAssetAvailability.isAvailable) ?? []
    }
    private var blockers: [MemoryBookIssue] { issues.filter { $0.severity == .blocking } }
    private var suggestions: [MemoryBookIssue] { issues.filter { $0.severity == .suggestion && book?.isBookCheckSuggestionIgnored($0) != true } }
    private var ignoredSuggestions: [MemoryBookIssue] { issues.filter { $0.severity == .suggestion && book?.isBookCheckSuggestionIgnored($0) == true } }

    var body: some View {
        ScrollViewReader { proxy in
        ZStack {
        TailorColor.paper.ignoresSafeArea()
        ScrollView {
        VStack(alignment: .leading, spacing: TailorSpacing.m) {
            HStack { Button(action: back) { Image(systemName: "chevron.left") }.frame(width: 44, height: 44).accessibilityLabel("Back"); Spacer(); Text("BOOK CHECK").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(TailorColor.clay) }
            Text(blockers.isEmpty ? "Almost ready to keep." : "A few pages need attention.").font(TailorFont.display(36)).foregroundStyle(TailorColor.ink)
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(TailorColor.mist, lineWidth: 9)
                    Circle().trim(from: 0, to: score / 100).stroke(blockers.isEmpty ? TailorColor.ink : TailorColor.clay, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(Int(score))").font(.title2.weight(.bold)).foregroundStyle(TailorColor.ink)
                }.frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 5) {
                    Text(blockers.isEmpty ? "Print-ready structure" : "Export is paused")
                        .font(.headline)
                    Text("\(blockers.count) blocking · \(suggestions.count) suggestions")
                        .font(.footnote).foregroundStyle(TailorColor.secondaryInk)
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 18))

            if issues.isEmpty {
                TailorInfoCard(symbol: "checkmark.seal", title: "Every page passed", message: "Photos, text fit, crop safety, fonts and printable resolution are ready for final preview.")
            } else {
                ForEach(Array(issues.enumerated()), id: \.element.persistenceKey) { index, issue in
                    VStack(alignment: .leading, spacing: 8) {
                    Button(action: { focusedIssueKey = issue.persistenceKey; editIssue(.init(issue: issue, issueIndex: index)) }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: issue.severity == .blocking ? "exclamationmark.triangle.fill" : "lightbulb.fill")
                                .foregroundStyle(issue.severity == .blocking ? .red : TailorColor.clay)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.severity == .blocking ? "Needs attention" : "Suggestion").font(.caption.weight(.bold)).foregroundStyle(TailorColor.ink)
                                Text(issue.message).font(.footnote).foregroundStyle(TailorColor.secondaryInk).multilineTextAlignment(.leading)
                                if let pageID = issue.pageID, let page = book?.pages.first(where: { $0.id == pageID }) {
                                    Text("Page \(page.pageNumber) · Open in editor").font(.caption.weight(.bold)).foregroundStyle(TailorColor.clay)
                                }
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(TailorColor.secondaryInk)
                        }.padding(14)
                    }
                    .buttonStyle(.plain)
                    if issue.severity == .suggestion {
                        let ignored = book?.isBookCheckSuggestionIgnored(issue) == true
                        Button(ignored ? "Undo ignore" : "Keep and ignore suggestion") {
                            if ignored { setIgnored(issue, false) } else { pendingIgnoreIssue = issue }
                        }
                            .font(.caption.weight(.bold)).foregroundStyle(TailorColor.clay).padding(.horizontal, 14)
                        if ignored { Text("Ignored by you · risk remains recorded").font(.caption2).foregroundStyle(TailorColor.secondaryInk).padding(.horizontal, 14) }
                    }
                    }.padding(.bottom, 8).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 16)).id(issue.persistenceKey)
                }
            }
            TailorInfoCard(symbol: "lock.shield", title: "Checked before payment", message: "Book Check inspects the complete document. Purchasing never hides a layout problem or changes your pages.")
        }.padding(.horizontal, TailorSpacing.l).padding(.top, TailorSpacing.s).padding(.bottom, 32)
        }.onAppear { scrollToFocused(proxy) }.onChange(of: focusedIssueKey) { _, _ in scrollToFocused(proxy) }
        .confirmationDialog("Ignore this suggestion?", isPresented: Binding(get: { pendingIgnoreIssue != nil }, set: { if !$0 { pendingIgnoreIssue = nil } })) {
            Button("Keep and ignore suggestion", role: .destructive) { if let issue = pendingIgnoreIssue { setIgnored(issue, true) }; pendingIgnoreIssue = nil }
                .accessibilityIdentifier("Confirm ignore Book Check suggestion")
            Button("Keep reviewing", role: .cancel) { pendingIgnoreIssue = nil }
        } message: { Text("\(pendingIgnoreIssue?.message ?? "This print risk remains.") Your choice is saved with this book revision and can be reversed with Undo ignore. Blocking issues can never be ignored.") }
        }
        .safeAreaInset(edge: .bottom) {
            TailorPrimaryButton(title: blockers.isEmpty ? "Continue to final preview" : "Review blocking issues", action: blockers.isEmpty ? continueFlow : reviewFirstBlockingIssue)
                .padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper)
        }
        }
    }

    /// Jumps to the first blocking issue. `issues` is recomputed on every access
    /// and each `MemoryBookIssue.id` is a fresh UUID, so matching by value
    /// (`firstIndex(of:)`) always failed and the button did nothing. Match on the
    /// content-stable `persistenceKey` instead — the same identity the issue
    /// cards and focus/scroll logic already use.
    private func reviewFirstBlockingIssue() {
        let current = issues
        guard let first = current.first(where: { $0.severity == .blocking }),
              let index = current.firstIndex(where: { $0.persistenceKey == first.persistenceKey }) else { return }
        focusedIssueKey = first.persistenceKey
        editIssue(.init(issue: first, issueIndex: index))
    }

    private var score: CGFloat {
        max(0, 100 - CGFloat(blockers.count * 18 + suggestions.count * 3))
    }
    private func setIgnored(_ issue: MemoryBookIssue, _ ignored: Bool) { guard var value = book else { return }; value.setBookCheckSuggestion(issue, ignored: ignored); book = value; persist() }
    private func scrollToFocused(_ proxy: ScrollViewProxy) { guard let focusedIssueKey else { return }; DispatchQueue.main.async { withAnimation { proxy.scrollTo(focusedIssueKey, anchor: .center) } } }
}

private extension AlbumStyle {
    var label: String { switch self { case .warmPaper: "Warm Paper"; case .quietNight: "Quiet Night"; case .fieldNotes: "Field Notes"; case .cinema: "Cinema"; case .filmAlbum: "Film Album" } }
}

private func memoryBookColorMarker(_ color: MemoryBookRGB) -> String {
    String(format: "red=%.3f;green=%.3f;blue=%.3f", color.red, color.green, color.blue)
}

struct PreviewFeatureView: View {
    let name: String
    @Binding var style: AlbumStyle
    @Binding var pageSize: PDFPageSize
    let chapters: [Chapter]
    let photos: [ArchivePhoto]
    @Binding var memoryBook: MemoryBookDocument?
    @Binding var selectedLogicalPageID: UUID?
    let purchased: Bool
    let next: () -> Void
    let back: () -> Void
    let editPage: (UUID?) -> Void
    let changeStyle: (() -> Void)?
    @State private var readerPage = 0
    /// This is the source of truth for reading position. A tab index describes
    /// a presentation group, which changes from one page to a two-page spread
    /// after rotation; a MemoryBookPage identity does not.
    @State private var showCustomization = false
    @State private var showContents = false
    @StateObject private var photoAvailability = PhotoAssetAvailabilityMonitor()

    init(
        name: String,
        style: Binding<AlbumStyle>,
        pageSize: Binding<PDFPageSize>,
        chapters: [Chapter],
        photos: [ArchivePhoto],
        memoryBook: Binding<MemoryBookDocument?>,
        selectedLogicalPageID: Binding<UUID?>,
        purchased: Bool,
        next: @escaping () -> Void,
        back: @escaping () -> Void,
        editPage: @escaping (UUID?) -> Void,
        changeStyle: (() -> Void)? = nil
    ) {
        self.name = name
        self._style = style
        self._pageSize = pageSize
        self.chapters = chapters
        self.photos = photos
        self._memoryBook = memoryBook
        self._selectedLogicalPageID = selectedLogicalPageID
        self.purchased = purchased
        self.next = next
        self.back = back
        self.editPage = editPage
        self.changeStyle = changeStyle
    }

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
                    selectedLogicalPageID: $selectedLogicalPageID,
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
                    Button("Edit") { editPage(selectedLogicalPageID) }
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
                // Two rows: actions on top (Style / Customize / Paper), reading
                // status below (swipe hint + page count). Splitting them stops
                // the single crowded row that forced "Customize" to hyphenate,
                // and keeps controls and status at distinct information levels.
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        Button("Style") { changeStyle?() }
                            .foregroundStyle(changeStyle == nil ? TailorColor.secondaryInk : TailorColor.clay)
                            .disabled(changeStyle == nil)
                        Rectangle().fill(TailorColor.line).frame(width: 1, height: 14)
                        Button("Customize") { editPage(selectedLogicalPageID) }
                            .foregroundStyle(TailorColor.clay)
                        Rectangle().fill(TailorColor.line).frame(width: 1, height: 14)
                        Button("Paper") { showCustomization = true }
                            .foregroundStyle(TailorColor.clay)
                        Spacer()
                    }
                    .font(.footnote.weight(.bold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    HStack {
                        Label("Swipe left or right", systemImage: "hand.draw")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(TailorColor.secondaryInk)
                            .accessibilityIdentifier("Reader navigation hint")
                        Spacer()
                        Text("PAGE \(readerLogicalPageNumber) OF \(visiblePageCount)")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(TailorColor.secondaryInk)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                if !purchased {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Every preview page is watermarked.", systemImage: "drop.triangle")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(TailorColor.ink)
                        Text("Your book remains fully editable until you unlock the complete album.")
                            .font(.caption)
                            .foregroundStyle(TailorColor.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(TailorColor.elevated)
                }
            }
        }
        .sheet(isPresented: $showCustomization) {
            PreviewCustomizationSheet(style: $style, pageSize: $pageSize, showsStyles: false)
        }
        .sheet(isPresented: $showContents) {
            ReaderContentsSheet(
                document: documentBinding.wrappedValue,
                visiblePageIDs: Set(documentBinding.wrappedValue.readerVisiblePages(watermarked: !purchased).map(\.id))
            ) { pageID in
                // The reader maps this identity into its current portrait or
                // landscape group. Never treat a logical page as a tab index.
                selectedLogicalPageID = pageID
                showContents = false
            }
        }
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-uiFixturePage"), arguments.indices.contains(index + 1), let requested = UUID(uuidString: arguments[index + 1]), memoryBook?.pages.contains(where: { $0.id == requested }) == true { selectedLogicalPageID = requested }
            else if selectedLogicalPageID == nil { selectedLogicalPageID = memoryBook?.readerVisiblePages(watermarked: !purchased).first?.id }
        }
        .safeAreaInset(edge: .bottom) {
            TailorPrimaryButton(title: purchased ? "Generate full PDF" : "Unlock complete album", action: next)
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
            let pageID = selectedLogicalPageID,
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
                    ReaderPageSpread(
                        pages: pages,
                        document: document,
                        watermarked: watermarked,
                        assetIsAvailable: assetIsAvailable,
                        isSpread: landscape
                    )
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
extension MemoryBookDocument {
    func readerVisiblePages(watermarked: Bool) -> [MemoryBookPage] {
        guard watermarked else { return pages }
        let ids = Set(MemoryBookSamplePlanner.make(for: self).pageIDs)
        return pages.filter { ids.contains($0.id) }
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
    let showsStyles: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if showsStyles {
                        Text("Choose a visual voice for every page. Your photos and page edits stay unchanged.")
                            .font(.footnote)
                            .foregroundStyle(TailorColor.secondaryInk)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(AlbumStyle.allCases, id: \.self) { choice in
                                styleCard(choice)
                            }
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
            .navigationTitle(showsStyles ? "Customize book" : "Print size")
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
    let revisionID: UUID?; let paperSize: PDFPageSize; let displayPrice: String?; let isLoadingPrice: Bool; let priceLoadFailed: Bool; let retryPrice: () -> Void; let purchase: () -> Void; let restore: () -> Void; let errorMessage: String?; let noticeMessage: String?; let isPurchasing: Bool; let next: () -> Void; let back: () -> Void
    var body: some View { TailorScreen(eyebrow: "ONE-TIME UNLOCK", title: "Keep every page.", back: back) {
        TailorInfoCard(symbol: "checkmark.seal.fill", title: "BOOK CHECK PASSED", message: "Revision \(revisionID?.uuidString.prefix(8) ?? "—") · \(paperSize == .letter ? "US Letter" : "A4") · Rules v\(BookCheckCacheKey.currentRulesVersion)")
        if let displayPrice {
            Text("\(displayPrice) · One-time purchase")
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier("Localized unlock price")
        } else if isLoadingPrice {
            HStack(spacing: 10) { ProgressView(); Text("Loading price from the App Store…") }
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("Unlock price loading")
        } else if priceLoadFailed {
            TailorInfoCard(symbol: "wifi.exclamationmark", title: "Price unavailable", message: "Connect to the App Store and load the current price before purchasing.")
            Button("Try loading price again", action: retryPrice)
                .font(.footnote.weight(.bold))
                .foregroundStyle(TailorColor.clay)
                .accessibilityIdentifier("Retry unlock price")
        }
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
            TailorPrimaryButton(title: isPurchasing ? "Contacting App Store…" : "Unlock complete album", disabled: isPurchasing || displayPrice == nil, action: purchase)
                .accessibilityIdentifier("Unlock complete album")
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
    let name: String; let exportURL: URL?; let exportRecord: MemoryBookExportRecord?; let memoryBook: MemoryBookDocument?; let errorMessage: String?; let isExporting: Bool; let completedPages: Int; let totalPages: Int; let createPDF: () -> Void; let cancelPDF: () -> Void; let done: () -> Void; let back: () -> Void
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
                Button("Return to timeline", action: back).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 10).background(TailorColor.paper)
    }
}
}

struct ArchivesFeatureView: View {
    let name: String; let pdfURL: URL?; let exportRecord: MemoryBookExportRecord?; let resumeActionLabel: String; let canRescan: Bool; let openArchive: () -> Void; let rescan: () -> Void; let restart: () -> Void; let delete: () -> Void
    @State private var confirmDeletion = false
    @State private var showAbout = false
    @Environment(\.openURL) private var openURL
    var body: some View { TailorScreen(eyebrow: "TAILOR     SETTINGS", title: "Your\narchives.", back: nil) {
        Button(action: openArchive) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10).fill(TailorColor.mist).frame(width: 72, height: 72).overlay(Text(String(name.prefix(1))).font(TailorFont.display(28)).foregroundStyle(TailorColor.ink))
                VStack(alignment: .leading) {
                    Text("\(name)’s Life Archive").font(.callout.weight(.bold))
                    Text(archiveSubtitle).font(.footnote).foregroundStyle(TailorColor.ink.opacity(0.7)).accessibilityIdentifier("Archive metadata")
                    Text(checkpointSummary).font(.caption).foregroundStyle(TailorColor.secondaryInk)
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
            if canRescan {
                Button(action: rescan) {
                    HStack { Text("Refresh new photos"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 48)
                }.buttonStyle(.plain).accessibilityIdentifier("Refresh new photos")
                Rectangle().fill(TailorColor.line).frame(height: 1)
            }
            Button(action: { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }) {
                HStack { Text("Manage photo access"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 48)
            }.buttonStyle(.plain).accessibilityIdentifier("Manage photo access")
            Rectangle().fill(TailorColor.line).frame(height: 1)
            Button(action: { showAbout = true }) {
                HStack { Text("About Tailor"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 48)
            }.buttonStyle(.plain).accessibilityIdentifier("About Tailor")
            Rectangle().fill(TailorColor.line).frame(height: 1)
            Button(role: .destructive) { confirmDeletion = true } label: {
                HStack { Text("Delete all local Tailor data"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 48)
            }
        }.foregroundStyle(TailorColor.ink)
        TailorInfoCard(symbol: "lock.shield", title: "Your system photos stay untouched.", message: "Deletion removes Tailor’s local matches, edits, and generated PDFs after its confirmation.")
    }.safeAreaInset(edge: .bottom) { VStack(spacing: 8) { TailorPrimaryButton(title: resumeActionLabel, action: openArchive); Button("Create another archive", action: restart).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) }.alert("Delete all local Tailor data?", isPresented: $confirmDeletion) { Button("Delete local data", role: .destructive, action: delete); Button("Cancel", role: .cancel) {} } message: { Text("This removes Tailor’s local pet profiles, photo matches, decisions, edits, and generated PDFs from this iPhone. Your original Photos library will not be changed. This cannot be undone.") }
    .sheet(isPresented: $showAbout) { AboutTailorSheet() } }

    private var checkpointSummary: String {
        switch resumeActionLabel {
        case "Continue profile": "Profile details are saved."
        case "Choose photos": "Your profile and selected photo slots are saved."
        case "Resume scan": "Scan progress is saved on this iPhone."
        case "Review photos": "Your matches and review decisions are saved."
        case "Continue draft": "Your latest completed planning step is saved."
        case "Review story": "Your Story Plan draft is ready to review."
        case "Choose style": "Your confirmed story is waiting for style and paper."
        default: "Your editable document is saved locally."
        }
    }

    private var archiveSubtitle: String {
        guard let exportRecord else { return "Saved locally · Ready to continue" }
        let paper = exportRecord.pageSize == .letter ? "US Letter" : "A4"
        return "\(exportRecord.pageCount) pages · \(paper) · \(exportRecord.exportedAt.formatted(date: .abbreviated, time: .omitted))"
    }
}

/// About / support surface reached from Settings. Required for App Store review:
/// it exposes the app version, a working privacy-policy link and a support
/// contact.
struct AboutTailorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let privacyPolicyURL = URL(string: "https://shilverfox.github.io/tailor-legal/privacy-policy.html")
    private let supportURL = URL(string: "https://shilverfox.github.io/tailor-legal/support.html")

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TailorSpacing.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tailor").font(TailorFont.display(32)).foregroundStyle(TailorColor.ink)
                        Text("A private, on-device life archive for the pets you love.")
                            .font(.callout).foregroundStyle(TailorColor.secondaryInk)
                    }
                    TailorInfoCard(symbol: "lock.shield", title: "Everything stays on this iPhone", message: "Photo matching runs locally. Tailor never uploads your library.")
                    VStack(spacing: 0) {
                        aboutRow("Privacy Policy", url: privacyPolicyURL)
                        Rectangle().fill(TailorColor.line).frame(height: 1)
                        aboutRow("Support", url: supportURL)
                        Rectangle().fill(TailorColor.line).frame(height: 1)
                        HStack { Text("Version"); Spacer(); Text(appVersion).foregroundStyle(TailorColor.secondaryInk) }
                            .frame(minHeight: 48)
                    }
                    .foregroundStyle(TailorColor.ink)
                }
                .padding(.horizontal, TailorSpacing.l)
                .padding(.top, TailorSpacing.m)
            }
            .background(TailorColor.paper.ignoresSafeArea())
            .navigationTitle("About Tailor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    @ViewBuilder private func aboutRow(_ title: String, url: URL?) -> some View {
        Button(action: { if let url { openURL(url) } }) {
            HStack { Text(title); Spacer(); Image(systemName: "arrow.up.right").font(.caption) }.frame(minHeight: 48)
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .accessibilityIdentifier("About \(title)")
    }
}
