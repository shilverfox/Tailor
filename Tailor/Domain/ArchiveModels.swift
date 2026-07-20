import Foundation
import UIKit
import CoreText
import CryptoKit

enum PetSpecies: String, Codable, CaseIterable, Sendable { case dog, cat }
enum ProfileLifecycle: String, Codable, Sendable { case draft, scanning, ready, exported, deleted }
enum PhotoAccessScope: String, Codable, Sendable { case notDetermined, full, limited, denied, restricted }
enum PhotoDecision: String, Codable, Sendable { case selected, needsReview, excluded }
/// A local, user-controlled safety state. It intentionally describes the handling decision,
/// never a diagnosis or a claim about what is happening in the photograph.
enum PhotoSensitivityState: String, Codable, CaseIterable, Sendable {
    case normal
    case needsSensitiveReview
    case hiddenUntilUserDecides
    case neverUse
}

/// Why a photo was excluded from this archive. This affects Tailor's local index only;
/// it never changes the user's original Photos library asset.
enum PhotoExcludedReason: String, Codable, Sendable {
    case userMarkedNotPet
    case userExcluded
    case neverUse
}

/// The local calendar period to which a photo belongs. We retain the original creation
/// timestamp separately; this bucket exists so timeline grouping remains deterministic.
struct ArchivePhotoDateRange: Codable, Equatable, Sendable {
    var start: Date
    var end: Date

    static func day(containing date: Date, calendar: Calendar = .current) -> ArchivePhotoDateRange {
        ArchivePhotoDateRange(start: calendar.startOfDay(for: date), end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date)
    }
}
enum AlbumStyle: String, Codable, CaseIterable, Sendable { case warmPaper, quietNight, fieldNotes, cinema, filmAlbum }
enum PDFPageSize: String, Codable, CaseIterable, Sendable { case letter, a4 }

/// Deterministic non-personal book for the explicit UI-automation visual route.
/// It is never constructed by a production archive flow.
enum MemoryBookVisualQAFixture {
    static func make(style: AlbumStyle, paper: PDFPageSize) -> MemoryBookDocument {
        let profile = PetProfile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!, name: "Milo", species: .dog, arrivalYear: 2017, departureYear: 2024, lifecycle: .ready, albumStyle: style)
        // Each rendered placement uses its own source asset.  This deliberately
        // exercises seven distinct crops without turning the visual fixture
        // into a duplicate-photo validation failure.
        let photos = (1...7).map { i in
            ArchivePhoto(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 200 + i))!,
                assetLocalIdentifier: "fixture-photo-\(i)",
                decision: .selected,
                confidence: 1,
                createdAt: Date(timeIntervalSince1970: 1_704_067_200 + TimeInterval(i * 86_400)),
                // The deterministic bitmap generator draws its explicit
                // subject marker in this centre region. Supplying that known
                // fixture metadata keeps rendering tests focused on output
                // equality instead of intentionally triggering crop review.
                subjectRegion: CGRect(x: 0.38, y: 0.38, width: 0.24, height: 0.24)
            )
        }
        func page(_ n: Int, _ kind: MemoryBookPageKind, _ title: String, _ subtitle: String = "", _ ids: [UUID] = [], _ layout: MemoryBookLayout = .note) -> MemoryBookPage { MemoryBookPage(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 500 + n))!, kind: kind, title: title, subtitle: subtitle, photoIDs: ids, layout: layout, pageNumber: n, elements: MemoryBookBuilder.elements(kind: kind, title: title, subtitle: subtitle, photos: ids, layout: layout)) }
        var pages = [page(1,.cover,"Milo","A life in moments",[photos[4].id],.single),page(2,.dedication,"For Milo","For every ordinary morning, every walk, and every place that still feels like home."),page(3,.contents,"Contents","Early days · 4\nDays together · 5\nKept close · 7"),page(4,.chapterOpener,"Days together","2019–2021",[photos[5].id],.single),page(5,.photoSelection,"Small adventures","A few of the days we kept.",Array(photos.prefix(4).map(\.id)),.grid2x2),page(6,.milestone,"2017","The first year we saved together.",[photos[6].id],.single),page(7,.closing,"Kept with care.","Tailor never changes your original photos.")]
        // The production builder's subtitle slot is intentionally compact for
        // ordinary metadata.  These two QA page kinds verify real multi-line
        // composition, so use explicit text frames rather than pretending a
        // three-line passage belongs in a one-line subtitle slot.
        pages[1].elements = [
            MemoryBookElement(kind: .text, text: "For Milo", normalizedFrame: CGRect(x: 0.12, y: 0.20, width: 0.68, height: 0.10), zIndex: 12, textStyle: .large, textField: .dedicationMessage),
            MemoryBookElement(kind: .text, text: "For every ordinary morning,\nevery walk, and every place\nthat still feels like home.", normalizedFrame: CGRect(x: 0.12, y: 0.37, width: 0.68, height: 0.23), zIndex: 11)
        ]
        pages[2].elements = [
            MemoryBookElement(kind: .text, text: "Contents", normalizedFrame: CGRect(x: 0.10, y: 0.10, width: 0.70, height: 0.09), zIndex: 12, textStyle: .large),
            MemoryBookElement(kind: .text, text: "Early days · 4\nDays together · 5\nKept close · 7", normalizedFrame: CGRect(x: 0.12, y: 0.30, width: 0.70, height: 0.34), zIndex: 11)
        ]
        return MemoryBookDocument(profile: profile, photos: photos, chapters: [], pages: pages, style: style, pageSize: paper)
    }
}

/// Deterministic, non-personal calibration assets for the UI-only visual QA
/// route.  The Editor/Reader thumbnail pipeline and PDF evidence provider must
/// use this exact generator: otherwise a "three-surface" comparison can hide
/// different crop sources behind visually similar placeholders.
///
/// These assets are never substituted for a Photos asset in a production
/// archive.  Callers opt in only for identifiers prefixed with `fixture-photo-`
/// (or the explicit crop exercise identifiers used by UI tests).
enum MemoryBookVisualQAAsset {
    static func image(identifier: String) -> UIImage? {
        guard (identifier.contains("ui-timeline-photo") && identifier.contains("crop-")) || identifier.hasPrefix("fixture-photo-") else { return nil }
        let size: CGSize
        if identifier.hasPrefix("fixture-photo-") {
            let number = Int(identifier.drop(while: { !$0.isNumber })) ?? 1
            size = number.isMultiple(of: 2) ? CGSize(width: 900, height: 1_600) : CGSize(width: 1_600, height: 900)
        } else if identifier.contains("landscape") {
            size = CGSize(width: 1_600, height: 900)
        } else if identifier.contains("portrait") {
            size = CGSize(width: 900, height: 1_600)
        } else {
            size = CGSize(width: 1_200, height: 1_200)
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            UIColor(red: 0.82, green: 0.88, blue: 0.76, alpha: 1).setFill(); cg.fill(rect)
            UIColor(red: 0.12, green: 0.29, blue: 0.24, alpha: 1).setFill(); cg.fill(CGRect(x: 0, y: 0, width: size.width * 0.28, height: size.height * 0.22))
            UIColor(red: 0.78, green: 0.31, blue: 0.17, alpha: 1).setFill(); cg.fill(CGRect(x: size.width * 0.72, y: size.height * 0.78, width: size.width * 0.28, height: size.height * 0.22))
            #if DEBUG
            // Only the first source owns focal metadata. The neighbouring
            // centred sources make the resulting crop visually auditable.
            let focalRight = identifier.contains("photo-0-crop-landscape-focal-right")
            #else
            let focalRight = false
            #endif
            let subjectRect = focalRight
                ? CGRect(x: size.width * 0.72, y: size.height * 0.30, width: size.width * 0.20, height: size.height * 0.34)
                : CGRect(x: size.width * 0.38, y: size.height * 0.38, width: size.width * 0.24, height: size.height * 0.24)
            UIColor.white.withAlphaComponent(0.92).setFill(); cg.fillEllipse(in: subjectRect)
            UIColor(red: 0.12, green: 0.29, blue: 0.24, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: subjectRect.midX - size.width * 0.045, y: subjectRect.midY - size.width * 0.045, width: size.width * 0.09, height: size.width * 0.09))
            let label = focalRight ? "AUTO FOCUS →" : (identifier.hasPrefix("fixture-photo-") ? "F\(identifier.suffix(1)) · CENTER" : (identifier.contains("minus15") ? "-15°  •  CENTER" : (identifier.contains("plus15") ? "+15°  •  CENTER" : "0°  •  CENTER")))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: min(size.width, size.height) * 0.038, weight: .bold), .foregroundColor: UIColor(red: 0.12, green: 0.29, blue: 0.24, alpha: 1)]
            let textSize = (label as NSString).size(withAttributes: attributes)
            label.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2), withAttributes: attributes)
        }
    }
}

/// Platform-neutral page tokens. SwiftUI and the Quartz exporter deliberately
/// consume this value rather than maintaining visually similar palettes in two
/// different files.
struct MemoryBookRGB: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    /// WCAG's sRGB relative luminance is useful beyond screens: it gives the
    /// editor a deterministic, renderer-independent way to catch text that
    /// will disappear into a custom paper colour before a book is exported.
    var relativeLuminance: Double {
        func linear(_ component: Double) -> Double {
            let value = min(1, max(0, component))
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrastRatio(with other: MemoryBookRGB) -> Double {
        let values = [relativeLuminance, other.relativeLuminance].sorted()
        return (values[1] + 0.05) / (values[0] + 0.05)
    }
}

enum MemoryBookImageTreatment: Codable, Equatable, Sendable { case original, mono }
enum MemoryBookFontToken: Codable, Equatable, Sendable { case display, body }

/// A text role is product data, not a presentation accident.  In particular we
/// must never infer that a free-form note is a cover title merely because it
/// happens to share a z-index with one.  Roles make the Text tool's whitelist
/// and its persistence/migration rules auditable.
enum MemoryBookTextField: String, Codable, CaseIterable, Sendable {
    case coverPetName
    case coverSubtitle
    case coverYearRange
    case dedicationMessage
    case chapterTitle
    case chapterDateRange
    case chapterNote
    case photoTitle
    case photoCaption
    case milestoneDate
    case milestoneNote
    case closingMessage
    case legacyUserNote

    var characterLimit: Int {
        switch self {
        case .photoTitle, .photoCaption: 120
        default: 240
        }
    }

    func isAllowed(on kind: MemoryBookPageKind) -> Bool {
        switch (kind, self) {
        case (.cover, .coverPetName), (.cover, .coverSubtitle), (.cover, .coverYearRange),
             (.dedication, .dedicationMessage),
             (.chapterOpener, .chapterTitle), (.chapterOpener, .chapterDateRange), (.chapterOpener, .chapterNote),
             (.photoSelection, .photoTitle), (.photoSelection, .photoCaption),
             (.milestone, .milestoneDate), (.milestone, .milestoneNote),
             (.closing, .closingMessage):
            return true
        case (_, .legacyUserNote):
            // A legacy free-form note remains editable only after migration
            // has attached it to an editable page. Contents has no editable
            // fields and therefore cannot adopt this fallback role.
            return kind != .contents
        default:
            return false
        }
    }

    static func allowed(on kind: MemoryBookPageKind) -> [MemoryBookTextField] {
        allCases.filter { $0 != .legacyUserNote && $0.isAllowed(on: kind) }
    }
}

/// Typography values consumed by the editor canvas, Reader and Quartz PDF
/// renderer.  The data is Codable so a render manifest can show exactly why a
/// line wrapped; it is deliberately independent of a UIKit/SwiftUI view.
struct MemoryBookTextLayoutSpec: Codable, Equatable, Sendable {
    let fontPostScriptName: String
    let fallbackPostScriptName: String
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let kern: CGFloat
    let paragraphSpacing: CGFloat
    let alignment: MemoryBookTextAlignment
    let writingDirection: MemoryBookTextWritingDirection
    let textRect: CGRect
    let editableRect: CGRect
    let protectedRects: [CGRect]

    func uiFont() -> UIFont {
        UIFont(name: fontPostScriptName, size: fontSize)
            ?? UIFont(name: fallbackPostScriptName, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)
    }

    func paragraphStyle() -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment.nsTextAlignment
        paragraph.baseWritingDirection = writingDirection.nsWritingDirection
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        paragraph.paragraphSpacing = paragraphSpacing
        return paragraph
    }

    func attributedString(_ text: String, color: UIColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: uiFont(),
            .foregroundColor: color,
            .kern: kern,
            .paragraphStyle: paragraphStyle()
        ])
    }
}

/// The renderer factory is intentionally the only place that turns a text
/// snapshot into an attributed paragraph.  UIKit Preview and Quartz PDF use
/// its output verbatim, while their small adapters expose an auditable contract
/// for model tests without requiring screenshot comparisons.
struct MemoryBookTextRenderContract: Codable, Equatable, Sendable {
    let value: String
    let spec: MemoryBookTextLayoutSpec
    let measurement: MemoryBookTextMeasurement
}

enum MemoryBookTextRenderer {
    static func contract(for snapshot: MemoryBookTextLayoutSnapshot) -> MemoryBookTextRenderContract {
        MemoryBookTextRenderContract(value: snapshot.value, spec: snapshot.spec, measurement: snapshot.measurement)
    }

    static func attributedString(for snapshot: MemoryBookTextLayoutSnapshot, color: UIColor) -> NSAttributedString {
        snapshot.spec.attributedString(snapshot.value, color: color)
    }
}

enum MemoryBookPreviewTextAdapter {
    static func contract(for snapshot: MemoryBookTextLayoutSnapshot) -> MemoryBookTextRenderContract {
        MemoryBookTextRenderer.contract(for: snapshot)
    }

    static func attributedString(for snapshot: MemoryBookTextLayoutSnapshot, color: UIColor) -> NSAttributedString {
        MemoryBookTextRenderer.attributedString(for: snapshot, color: color)
    }
}

enum MemoryBookPDFTextAdapter {
    static func contract(for snapshot: MemoryBookTextLayoutSnapshot) -> MemoryBookTextRenderContract {
        MemoryBookTextRenderer.contract(for: snapshot)
    }

    static func attributedString(for snapshot: MemoryBookTextLayoutSnapshot, color: UIColor) -> NSAttributedString {
        MemoryBookTextRenderer.attributedString(for: snapshot, color: color)
    }
}

enum MemoryBookTextAlignment: String, Codable, Equatable, Sendable {
    case leading, center, trailing

    var nsTextAlignment: NSTextAlignment {
        switch self { case .leading: .natural; case .center: .center; case .trailing: .right }
    }
}

/// Exact, non-destructive typography controls persisted with each text layer.
/// Values are relative to the resolved font size so they remain visually
/// identical from the phone canvas to A4/Letter PDF output.
struct MemoryBookTextTypographyAdjustments: Codable, Equatable, Sendable {
    var alignment: MemoryBookTextAlignment
    var trackingEm: CGFloat
    var lineHeightMultiple: CGFloat
    var paragraphSpacingEm: CGFloat

    init(
        alignment: MemoryBookTextAlignment = .leading,
        trackingEm: CGFloat = 0,
        lineHeightMultiple: CGFloat = 1.22,
        paragraphSpacingEm: CGFloat = 0
    ) {
        self.alignment = alignment
        self.trackingEm = trackingEm
        self.lineHeightMultiple = lineHeightMultiple
        self.paragraphSpacingEm = paragraphSpacingEm
        normalize()
    }

    mutating func normalize() {
        trackingEm = min(0.20, max(-0.05, trackingEm))
        lineHeightMultiple = min(2, max(0.90, lineHeightMultiple))
        paragraphSpacingEm = min(1.5, max(0, paragraphSpacingEm))
    }

    static let `default` = MemoryBookTextTypographyAdjustments()
}

enum MemoryBookTextWritingDirection: String, Codable, Equatable, Sendable {
    case natural, leftToRight, rightToLeft

    var nsWritingDirection: NSWritingDirection {
        switch self { case .natural: .natural; case .leftToRight: .leftToRight; case .rightToLeft: .rightToLeft }
    }

    static func inferred(from text: String) -> MemoryBookTextWritingDirection {
        // The first non-neutral strong scalar is enough for a paragraph's base
        // direction. Arabic/Hebrew ranges are handled explicitly; all other
        // human-authored fixture text falls back to LTR rather than silently
        // leaving the Preview and PDF adapters to make different choices.
        for scalar in text.unicodeScalars where !CharacterSet.whitespacesAndNewlines.contains(scalar) {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF:
                return .rightToLeft
            case 0x0000...0x0040, 0x005B...0x0060, 0x007B...0x00BF:
                continue
            default:
                return .leftToRight
            }
        }
        return .natural
    }
}

struct MemoryBookTextLineBox: Codable, Equatable, Sendable {
    let rect: CGRect
}

struct MemoryBookTextMeasurement: Codable, Equatable, Sendable {
    let requiredLines: Int
    let availableLines: Int
    let requiredHeight: CGFloat
    let availableHeight: CGFloat
    let occupiedRect: CGRect
    let lineBoxes: [MemoryBookTextLineBox]

    init(requiredLines: Int, availableLines: Int, requiredHeight: CGFloat, availableHeight: CGFloat, occupiedRect: CGRect = .zero, lineBoxes: [MemoryBookTextLineBox] = []) {
        self.requiredLines = requiredLines
        self.availableLines = availableLines
        self.requiredHeight = requiredHeight
        self.availableHeight = availableHeight
        self.occupiedRect = occupiedRect
        self.lineBoxes = lineBoxes
    }

    var overflows: Bool { requiredHeight > availableHeight + 0.25 }
}

/// Validation is deliberately evaluated from the in-memory editing draft. It
/// is not an export concern: B2 must keep an invalid Save inside the editor.
struct MemoryBookTextDraftValidation: Equatable, Sendable {
    let characterLimit: Int
    let characterCount: Int
    let measurement: MemoryBookTextMeasurement
    var exceedsCharacterLimit: Bool { characterCount > characterLimit }
    var isValid: Bool { !exceedsCharacterLimit && !measurement.overflows }
}

/// A print-focused quality signal computed from the exact text layout and
/// colours used by Editor, Reader and PDF. Low contrast remains a suggestion
/// so deliberate artistic choices stay possible; the 11pt renderer floor is a
/// hard invariant and is reported here for auditability.
struct MemoryBookTextReadabilityAssessment: Equatable, Sendable {
    static let minimumPrintPointSize: CGFloat = 11
    /// Print paper, texture and antialiasing differ from an emissive screen.
    /// 4.0:1 catches genuinely disappearing custom colours while keeping the
    /// authored 4.2–4.4:1 secondary inks in Tailor's default styles quiet.
    static let minimumContrastRatio = 4.0

    let fontSize: CGFloat
    let contrastRatio: Double
    let foreground: MemoryBookRGB
    let background: MemoryBookRGB
    let recommendedForeground: MemoryBookRGB

    var isPrintSizeReadable: Bool { fontSize + 0.01 >= Self.minimumPrintPointSize }
    var hasSufficientContrast: Bool { contrastRatio + 0.01 >= Self.minimumContrastRatio }
}

struct MemoryBookTextLayoutSnapshot: Codable, Equatable, Sendable {
    let elementID: UUID
    let field: MemoryBookTextField?
    let value: String
    let style: MemoryBookTextStyle
    let spec: MemoryBookTextLayoutSpec
    let measurement: MemoryBookTextMeasurement
}

/// Typography is part of the render contract, rather than a SwiftUI/PDF detail.
/// Both renderers intentionally resolve the display face from this identifier.
enum MemoryBookTypography {
    /// Explicit public PostScript names. Do not persist UIKit's private
    /// `.SFUI-*` aliases: Quartz/Core Text may silently substitute a different
    /// face while rendering the PDF.
    static let displayPostScriptName = "IowanOldStyle-Roman"
    static let displayFallbackPostScriptName = "HelveticaNeue"
    static let bodyPostScriptName = "Helvetica"
    static let bodyFallbackPostScriptName = "HelveticaNeue"
}

/// Film Album is not an editor-only flourish. Its geometry is expressed in paper
/// coordinates so SwiftUI and Quartz paint the exact same decoration.
struct MemoryBookFilmFrameStyle: Codable, Equatable, Sendable {
    let insetRatio: CGFloat
    let lineWidthRatio: CGFloat
    let dashRatio: [CGFloat]
    let cornerRadiusRatio: CGFloat
    let imageBorderInsetRatio: CGFloat
    let imageBorderLineWidthRatio: CGFloat
    let imageBorderCornerRadiusRatio: CGFloat
}

struct MemoryBookWatermarkStyle: Codable, Equatable, Sendable {
    let text: String
    let opacity: Double
    let rotationDegrees: Double
    let fontSizeRatio: CGFloat
    let letterSpacingRatio: CGFloat
    let normalizedCenters: [CGPoint]

    static let preview = MemoryBookWatermarkStyle(
        text: "TAILOR · PREVIEW",
        opacity: 0.22,
        rotationDegrees: -28,
        fontSizeRatio: 13 / 612,
        letterSpacingRatio: 3 / 13,
        normalizedCenters: [CGPoint(x: 0.30, y: 0.30), CGPoint(x: 0.70, y: 0.70)]
    )
}

/// A template-owned paper treatment.  This is data, rather than a SwiftUI or
/// Core Graphics implementation detail, so editor, reader and PDF consume the
/// same texture decision.  When an asset is unavailable the renderer must
/// retain the declared solid paper colour; it may never substitute a
/// different, renderer-specific background.
struct MemoryBookTextureDescriptor: Codable, Equatable, Sendable {
    enum ContentMode: String, Codable, Sendable { case fill }
    enum Fallback: String, Codable, Sendable { case solidPaper }

    let assetName: String
    let opacity: Double
    let contentMode: ContentMode
    let fallback: Fallback

    static func editorial(_ assetName: String, opacity: Double = 0.34) -> MemoryBookTextureDescriptor {
        .init(assetName: assetName, opacity: opacity, contentMode: .fill, fallback: .solidPaper)
    }
}

struct MemoryBookPageStyle: Codable, Equatable, Sendable {
    let paper: MemoryBookRGB
    let backdrop: MemoryBookRGB
    let ink: MemoryBookRGB
    let secondary: MemoryBookRGB
    let accent: MemoryBookRGB
    let imageTreatment: MemoryBookImageTreatment
    let filmFrame: MemoryBookFilmFrameStyle?
    /// Candidate editorial material used by every renderer.  `nil` is an
    /// intentional pure-colour style, not an instruction for a consumer to
    /// invent a texture.
    let texture: MemoryBookTextureDescriptor?

    var drawsFilmFrame: Bool { filmFrame != nil }

    static func resolve(_ style: AlbumStyle) -> MemoryBookPageStyle {
        let paper = MemoryBookRGB(red: 248 / 255, green: 243 / 255, blue: 232 / 255)
        let ink = MemoryBookRGB(red: 24 / 255, green: 58 / 255, blue: 49 / 255)
        let secondary = MemoryBookRGB(red: 100 / 255, green: 117 / 255, blue: 108 / 255)
        let clay = MemoryBookRGB(red: 184 / 255, green: 86 / 255, blue: 57 / 255)
        switch style {
        case .warmPaper:
            return .init(paper: paper, backdrop: .init(red: 239 / 255, green: 228 / 255, blue: 209 / 255), ink: ink, secondary: secondary, accent: clay, imageTreatment: .original, filmFrame: nil, texture: .editorial("WarmPaper"))
        case .quietNight:
            return .init(paper: ink, backdrop: .init(red: 13 / 255, green: 31 / 255, blue: 26 / 255), ink: paper, secondary: .init(red: 216 / 255, green: 223 / 255, blue: 203 / 255), accent: clay, imageTreatment: .original, filmFrame: nil, texture: .editorial("QuietNight", opacity: 0.30))
        case .fieldNotes:
            return .init(paper: .init(red: 216 / 255, green: 223 / 255, blue: 203 / 255), backdrop: .init(red: 186 / 255, green: 196 / 255, blue: 168 / 255), ink: ink, secondary: secondary, accent: clay, imageTreatment: .original, filmFrame: nil, texture: .editorial("FieldNotes", opacity: 0.36))
        case .cinema:
            return .init(paper: .init(red: 0, green: 0, blue: 0), backdrop: .init(red: 10 / 255, green: 10 / 255, blue: 10 / 255), ink: .init(red: 1, green: 1, blue: 1), secondary: .init(red: 0.72, green: 0.72, blue: 0.72), accent: clay, imageTreatment: .mono, filmFrame: nil, texture: nil)
        case .filmAlbum:
            let frame = MemoryBookFilmFrameStyle(
                insetRatio: 10 / 612,
                lineWidthRatio: 2 / 612,
                dashRatio: [5 / 612, 4 / 612],
                cornerRadiusRatio: 4 / 612,
                imageBorderInsetRatio: 1 / 612,
                imageBorderLineWidthRatio: 1 / 612,
                imageBorderCornerRadiusRatio: 4 / 612
            )
            let backdrop = MemoryBookRGB(red: 48 / 255, green: 41 / 255, blue: 33 / 255)
            return .init(paper: paper, backdrop: backdrop, ink: ink, secondary: secondary, accent: clay, imageTreatment: .original, filmFrame: frame, texture: nil)
        }
    }
}

/// Shared geometry and typography contract. Element frames are normalized to
/// `paperRect`, never to an iPhone screen or a PDF-specific inner rectangle.
struct MemoryBookPageRenderPlan: Codable, Equatable, Sendable {
    static let paperInsetRatio: CGFloat = 18 / 612
    static let safeInsetRatio: CGFloat = 0.07

    let pageSize: CGSize
    let pageRect: CGRect
    let paperRect: CGRect
    let safeRect: CGRect
    let style: MemoryBookPageStyle
    /// The page's actual printable base color. A page override belongs to the
    /// document contract, while the resolved style continues to supply ink,
    /// texture and other coordinated tokens.
    let paperColor: MemoryBookRGB
    let pageID: UUID?
    let orderedElements: [MemoryBookElement]
    let watermark: MemoryBookWatermarkStyle?
    /// Per-text-element typography/line-box evidence.  It travels with the
    /// normal render plan, so all consumers can inspect a single contract.
    var textLayouts: [MemoryBookTextLayoutSnapshot]

    init(pageSize: CGSize, style: MemoryBookPageStyle, watermarked: Bool = false) {
        self.pageSize = pageSize
        pageRect = CGRect(origin: .zero, size: pageSize)
        paperRect = pageRect.insetBy(dx: pageSize.width * Self.paperInsetRatio, dy: pageSize.width * Self.paperInsetRatio)
        safeRect = paperRect.insetBy(dx: paperRect.width * Self.safeInsetRatio, dy: paperRect.height * Self.safeInsetRatio)
        self.style = style
        paperColor = style.paper
        pageID = nil
        orderedElements = []
        watermark = watermarked ? .preview : nil
        textLayouts = []
    }

    init(pageSize: PDFPageSize, style: AlbumStyle, watermarked: Bool = false) {
        self.init(pageSize: Self.points(for: pageSize), style: .resolve(style), watermarked: watermarked)
    }

    init(page: MemoryBookPage, document: MemoryBookDocument, pageSize: CGSize, watermarked: Bool = false) {
        self.pageSize = pageSize
        pageRect = CGRect(origin: .zero, size: pageSize)
        paperRect = pageRect.insetBy(dx: pageSize.width * Self.paperInsetRatio, dy: pageSize.width * Self.paperInsetRatio)
        safeRect = paperRect.insetBy(dx: paperRect.width * Self.safeInsetRatio, dy: paperRect.height * Self.safeInsetRatio)
        let resolvedStyle = MemoryBookPageStyle.resolve(page.styleOverride ?? document.style)
        style = resolvedStyle
        paperColor = page.backgroundColor ?? resolvedStyle.paper
        pageID = page.id
        let elements = page.elements.isEmpty
            ? MemoryBookBuilder.elements(kind: page.kind, title: page.title, subtitle: page.subtitle, photos: page.photoIDs, layout: page.layout)
            : page.elements
        let ordered = elements.filter { !$0.isHidden }.sorted {
            $0.zIndex == $1.zIndex ? $0.id.uuidString < $1.id.uuidString : $0.zIndex < $1.zIndex
        }
        orderedElements = ordered
        watermark = watermarked ? .preview : nil
        textLayouts = []
        textLayouts = ordered.compactMap { element in
            guard element.kind == .text else { return nil }
            return Self.makeTextLayout(
                element: element,
                pageKind: page.kind,
                pageSize: pageSize,
                paperRect: paperRect,
                safeRect: safeRect,
                style: resolvedStyle,
                watermarked: watermarked
            )
        }
    }

    static func points(for pageSize: PDFPageSize) -> CGSize {
        pageSize == .a4 ? CGSize(width: 595, height: 842) : CGSize(width: 612, height: 792)
    }

    func rect(for normalizedFrame: CGRect) -> CGRect {
        CGRect(
            x: paperRect.minX + normalizedFrame.minX * paperRect.width,
            y: paperRect.minY + normalizedFrame.minY * paperRect.height,
            width: normalizedFrame.width * paperRect.width,
            height: normalizedFrame.height * paperRect.height
        )
    }

    func fontToken(for element: MemoryBookElement) -> MemoryBookFontToken {
        element.zIndex >= 10 ? .display : .body
    }

    func filmFrameRect() -> CGRect? {
        guard let filmFrame = style.filmFrame else { return nil }
        let inset = paperRect.width * filmFrame.insetRatio
        return paperRect.insetBy(dx: inset, dy: inset)
    }

    func filmFrameLineWidth() -> CGFloat? {
        style.filmFrame.map { paperRect.width * $0.lineWidthRatio }
    }

    func filmFrameDash() -> [CGFloat]? {
        style.filmFrame.map { frame in frame.dashRatio.map { paperRect.width * $0 } }
    }

    func filmFrameCornerRadius() -> CGFloat? {
        style.filmFrame.map { paperRect.width * $0.cornerRadiusRatio }
    }

    func filmImageBorderRect(in imageRect: CGRect) -> CGRect? {
        guard let filmFrame = style.filmFrame else { return nil }
        let inset = paperRect.width * filmFrame.imageBorderInsetRatio
        return imageRect.insetBy(dx: inset, dy: inset)
    }

    func filmImageBorderLineWidth() -> CGFloat? {
        style.filmFrame.map { paperRect.width * $0.imageBorderLineWidthRatio }
    }

    func filmImageBorderCornerRadius() -> CGFloat? {
        style.filmFrame.map { paperRect.width * $0.imageBorderCornerRadiusRatio }
    }

    func watermarkFontSize() -> CGFloat? {
        watermark.map { paperRect.width * $0.fontSizeRatio }
    }

    func watermarkLetterSpacing() -> CGFloat? {
        guard let watermark, let fontSize = watermarkFontSize() else { return nil }
        return fontSize * watermark.letterSpacingRatio
    }

    func watermarkCenters() -> [CGPoint] {
        guard let watermark else { return [] }
        return watermark.normalizedCenters.map { normalized in
            CGPoint(x: paperRect.minX + normalized.x * paperRect.width, y: paperRect.minY + normalized.y * paperRect.height)
        }
    }

    func fontSize(for element: MemoryBookElement, in rect: CGRect) -> CGFloat {
        let multiplier: CGFloat
        switch element.textStyle {
        case .small: multiplier = 0.82
        case .standard: multiplier = 1
        case .large: multiplier = 1.22
        }
        // Font size is tied to the physical paper, not to a text box's height.
        // Otherwise making a text frame taller also enlarged its font and Fit text
        // could never create additional usable lines.
        let base = paperRect.width * (fontToken(for: element) == .display ? 0.045 : 0.026)
        return max(11, base * multiplier * element.textFontScale)
    }

    func textLayout(for element: MemoryBookElement) -> MemoryBookTextLayoutSnapshot? {
        textLayouts.first(where: { $0.elementID == element.id })
    }

    func clampedTextFrame(_ normalizedFrame: CGRect, for element: MemoryBookElement) -> CGRect {
        guard let layout = textLayout(for: element) else { return normalizedFrame }
        let width = min(max(0.01, normalizedFrame.width * paperRect.width), layout.spec.editableRect.width)
        let height = min(max(0.01, normalizedFrame.height * paperRect.height), layout.spec.editableRect.height)
        var rect = CGRect(
            x: paperRect.minX + normalizedFrame.minX * paperRect.width,
            y: paperRect.minY + normalizedFrame.minY * paperRect.height,
            width: width,
            height: height
        )
        rect.origin.x = min(max(rect.minX, layout.spec.editableRect.minX), layout.spec.editableRect.maxX - rect.width)
        rect.origin.y = min(max(rect.minY, layout.spec.editableRect.minY), layout.spec.editableRect.maxY - rect.height)
        // Text must never use a protected rectangle (footer, watermarks or
        // future system anchors). Choose the nearest legal edge rather than
        // silently allowing a drag to overlap a system-owned mark.
        for protected in layout.spec.protectedRects where rect.intersects(protected) {
            let candidates = [
                CGPoint(x: protected.minX - rect.width, y: rect.minY),
                CGPoint(x: protected.maxX, y: rect.minY),
                CGPoint(x: rect.minX, y: protected.minY - rect.height),
                CGPoint(x: rect.minX, y: protected.maxY)
            ].map { point -> CGRect in
                var candidate = rect
                candidate.origin.x = min(max(point.x, layout.spec.editableRect.minX), layout.spec.editableRect.maxX - candidate.width)
                candidate.origin.y = min(max(point.y, layout.spec.editableRect.minY), layout.spec.editableRect.maxY - candidate.height)
                return candidate
            }.filter { candidate in
                layout.spec.editableRect.contains(candidate) && !layout.spec.protectedRects.contains(where: { candidate.intersects($0) })
            }
            if let nearest = candidates.min(by: { hypot($0.midX - rect.midX, $0.midY - rect.midY) < hypot($1.midX - rect.midX, $1.midY - rect.midY) }) {
                rect = nearest
            }
        }
        return CGRect(
            x: (rect.minX - paperRect.minX) / paperRect.width,
            y: (rect.minY - paperRect.minY) / paperRect.height,
            width: rect.width / paperRect.width,
            height: rect.height / paperRect.height
        )
    }

    static func makeTextLayout(
        element: MemoryBookElement,
        pageKind: MemoryBookPageKind,
        pageSize: CGSize,
        paperRect: CGRect,
        safeRect: CGRect,
        style: MemoryBookPageStyle,
        watermarked: Bool
    ) -> MemoryBookTextLayoutSnapshot {
        let textRect = CGRect(
            x: paperRect.minX + element.normalizedFrame.minX * paperRect.width,
            y: paperRect.minY + element.normalizedFrame.minY * paperRect.height,
            width: element.normalizedFrame.width * paperRect.width,
            height: element.normalizedFrame.height * paperRect.height
        )
        let multiplier: CGFloat
        switch element.textStyle {
        case .small: multiplier = 0.82
        case .standard: multiplier = 1
        case .large: multiplier = 1.22
        }
        let token: MemoryBookFontToken = element.zIndex >= 10 ? .display : .body
        let fontSize = max(11, paperRect.width * (token == .display ? 0.045 : 0.026) * multiplier * element.textFontScale)
        let resolvedFont = element.textFont.font(size: fontSize, fallback: token)
        let fallbackPostScript = token == .display
            ? MemoryBookTypography.displayFallbackPostScriptName
            : MemoryBookTypography.bodyFallbackPostScriptName
        let footer = CGRect(x: safeRect.minX, y: safeRect.maxY - safeRect.height * 0.055, width: safeRect.width, height: safeRect.height * 0.055)
        var protected = [footer]
        if watermarked {
            let watermarkFont = paperRect.width * MemoryBookWatermarkStyle.preview.fontSizeRatio
            let watermarkWidth = watermarkFont * 11
            let watermarkHeight = watermarkFont * 2
            protected += MemoryBookWatermarkStyle.preview.normalizedCenters.map {
                CGRect(
                    x: paperRect.minX + $0.x * paperRect.width - watermarkWidth / 2,
                    y: paperRect.minY + $0.y * paperRect.height - watermarkHeight / 2,
                    width: watermarkWidth,
                    height: watermarkHeight
                )
            }
        }
        let editableRect = CGRect(x: safeRect.minX, y: safeRect.minY, width: safeRect.width, height: max(0, footer.minY - safeRect.minY))
        let spec = MemoryBookTextLayoutSpec(
            fontPostScriptName: resolvedFont.fontName,
            fallbackPostScriptName: fallbackPostScript,
            fontSize: fontSize,
            lineHeight: max(resolvedFont.lineHeight, fontSize * element.textTypographyAdjustments.lineHeightMultiple),
            kern: fontSize * element.textTypographyAdjustments.trackingEm,
            paragraphSpacing: fontSize * element.textTypographyAdjustments.paragraphSpacingEm,
            alignment: element.textTypographyAdjustments.alignment,
            writingDirection: .inferred(from: element.text ?? ""),
            textRect: textRect,
            editableRect: editableRect,
            protectedRects: protected
        )
        let measurement = measureText(element.text ?? "", spec: spec)
        return MemoryBookTextLayoutSnapshot(
            elementID: element.id,
            field: element.textField?.isAllowed(on: pageKind) == true ? element.textField : nil,
            value: element.text ?? "",
            style: element.textStyle,
            spec: spec,
            measurement: measurement
        )
    }

    static func measureText(_ text: String, spec: MemoryBookTextLayoutSpec) -> MemoryBookTextMeasurement {
        let attributed = spec.attributedString(text, color: .black)
        let width = max(1, spec.textRect.width)
        let unconstrained = CGRect(x: 0, y: 0, width: width, height: 1_000_000)
        let typesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: unconstrained, transform: nil)
        let frame = CTFramesetterCreateFrame(typesetter, CFRange(location: 0, length: attributed.length), path, nil)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        let lineBoxes = zip(lines, origins).map { line, origin -> MemoryBookTextLineBox in
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
            // Core Text has a bottom-left origin; manifests use the normal
            // page top-left origin so Preview/PDF diagnostics are comparable.
            return MemoryBookTextLineBox(rect: CGRect(
                x: spec.textRect.minX + origin.x,
                y: spec.textRect.minY + (1_000_000 - origin.y - ascent),
                width: lineWidth,
                height: max(spec.lineHeight, ascent + descent + leading)
            ))
        }
        let requiredLines = max(1, lineBoxes.count)
        let availableLines = max(1, Int(floor(spec.textRect.height / spec.lineHeight)))
        let bounds = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        // Core Text already gives the exact wrapped line count. Add authored
        // paragraph gaps deterministically instead of using boundingRect's
        // platform-dependent font-leading padding, which can falsely reject a
        // text block that fits on the final line by a fraction of a point.
        let paragraphBreaks = text.reduce(into: 0) { count, character in
            if character == "\n" { count += 1 }
        }
        let occupiedHeight = CGFloat(requiredLines) * spec.lineHeight
            + CGFloat(paragraphBreaks) * spec.paragraphSpacing
        let occupied = CGRect(x: spec.textRect.minX, y: spec.textRect.minY, width: min(width, bounds.width), height: occupiedHeight)
        return MemoryBookTextMeasurement(
            requiredLines: requiredLines,
            availableLines: availableLines,
            requiredHeight: occupiedHeight,
            availableHeight: spec.textRect.height,
            occupiedRect: occupied,
            lineBoxes: lineBoxes
        )
    }
}

/// A serializable snapshot passed between preview/export boundaries. It makes
/// the concrete page order, source assets and watermark state auditable before
/// any renderer begins drawing.
struct MemoryBookRenderManifest: Codable, Equatable, Sendable {
    let documentID: UUID
    let pageSize: PDFPageSize
    let watermarked: Bool
    let plans: [MemoryBookPageRenderPlan]
}

/// An immutable export boundary. The renderer receives this value, never a
/// live editor binding, so changes made after export begins belong to the next
/// file rather than leaking into the current one.
struct MemoryBookExportSnapshot: Equatable, Sendable {
    let document: MemoryBookDocument
    let manifest: MemoryBookRenderManifest
    let fingerprint: String
}

struct PetProfile: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var species: PetSpecies
    var arrivalYear: Int?
    var departureYear: Int
    var lifecycle: ProfileLifecycle
    var referenceAssetIdentifiers: [String]
    var albumStyle: AlbumStyle

    init(id: UUID = UUID(), name: String, species: PetSpecies, arrivalYear: Int? = nil, departureYear: Int, lifecycle: ProfileLifecycle = .draft, referenceAssetIdentifiers: [String] = [], albumStyle: AlbumStyle = .warmPaper) {
        self.id = id; self.name = name; self.species = species; self.arrivalYear = arrivalYear
        self.departureYear = departureYear; self.lifecycle = lifecycle
        self.referenceAssetIdentifiers = referenceAssetIdentifiers; self.albumStyle = albumStyle
    }
}

struct ArchivePhoto: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var assetLocalIdentifier: String
    var decision: PhotoDecision
    var confidence: Double
    var createdAt: Date?
    var sensitivityState: PhotoSensitivityState
    var excludedReason: PhotoExcludedReason?
    var localDateRange: ArchivePhotoDateRange?
    /// Pixel dimensions are metadata only (never a copied image).  They let
    /// every renderer apply the same aspect-aware, no-blank crop constraint.
    var pixelSize: CGSize?
    /// Local, non-reversible 8x8 visual signature used only to suppress exact
    /// re-imports and burst frames within this archive. It is never uploaded.
    var visualHash: UInt64?
    /// Scanner evidence stays on this device so confirmed decisions can later
    /// be evaluated against the exact policy that proposed the photo.
    var recognitionEvidence: PetRecognitionEvidence?
    /// Normalized top-left image coordinates for the locally detected target
    /// animal. This is geometry only, never a copied image or uploaded signal;
    /// automatic layouts use it to avoid centring a crop on empty background.
    var subjectRegion: CGRect?
    /// A local grouping key for near-identical burst/re-import candidates. It
    /// never changes the user's inclusion/exclusion decision.
    var visualDuplicateGroupID: String?

    var aspectRatio: CGFloat {
        guard let pixelSize, pixelSize.width > 0, pixelSize.height > 0 else { return 1 }
        return pixelSize.width / pixelSize.height
    }

    /// A single source of truth used by timeline, preview, and PDF generation.
    /// Sensitive content must be explicitly restored to `.normal` before it can be used.
    var isEligibleForArchive: Bool {
        decision == .selected && sensitivityState == .normal
    }

    init(
        id: UUID,
        assetLocalIdentifier: String,
        decision: PhotoDecision,
        confidence: Double,
        createdAt: Date?,
        sensitivityState: PhotoSensitivityState = .normal,
        excludedReason: PhotoExcludedReason? = nil,
        localDateRange: ArchivePhotoDateRange? = nil,
        pixelSize: CGSize? = nil,
        visualHash: UInt64? = nil,
        recognitionEvidence: PetRecognitionEvidence? = nil,
        subjectRegion: CGRect? = nil,
        visualDuplicateGroupID: String? = nil
    ) {
        self.id = id
        self.assetLocalIdentifier = assetLocalIdentifier
        self.decision = decision
        self.confidence = confidence
        self.createdAt = createdAt
        self.sensitivityState = sensitivityState
        self.excludedReason = excludedReason
        self.localDateRange = localDateRange ?? createdAt.map { ArchivePhotoDateRange.day(containing: $0) }
        self.pixelSize = pixelSize
        self.visualHash = visualHash
        self.recognitionEvidence = recognitionEvidence
        self.subjectRegion = subjectRegion.map(FocalCropPolicy.normalizedSubjectRegion)
        self.visualDuplicateGroupID = visualDuplicateGroupID
    }

    private enum CodingKeys: String, CodingKey {
        case id, assetLocalIdentifier, decision, confidence, createdAt
        case sensitivityState, excludedReason, localDateRange, pixelSize, visualHash, recognitionEvidence, subjectRegion, visualDuplicateGroupID
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        assetLocalIdentifier = try values.decode(String.self, forKey: .assetLocalIdentifier)
        decision = try values.decode(PhotoDecision.self, forKey: .decision)
        confidence = try values.decode(Double.self, forKey: .confidence)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt)
        sensitivityState = try values.decodeIfPresent(PhotoSensitivityState.self, forKey: .sensitivityState) ?? .normal
        excludedReason = try values.decodeIfPresent(PhotoExcludedReason.self, forKey: .excludedReason)
        localDateRange = try values.decodeIfPresent(ArchivePhotoDateRange.self, forKey: .localDateRange)
            ?? createdAt.map { ArchivePhotoDateRange.day(containing: $0) }
        pixelSize = try values.decodeIfPresent(CGSize.self, forKey: .pixelSize)
        visualHash = try values.decodeIfPresent(UInt64.self, forKey: .visualHash)
        recognitionEvidence = try values.decodeIfPresent(PetRecognitionEvidence.self, forKey: .recognitionEvidence)
        subjectRegion = try values.decodeIfPresent(CGRect.self, forKey: .subjectRegion).map(FocalCropPolicy.normalizedSubjectRegion)
        visualDuplicateGroupID = try values.decodeIfPresent(String.self, forKey: .visualDuplicateGroupID)
    }
}

/// Pure, local focal geometry. Vision uses a bottom-left origin while Tailor's
/// page/source coordinate system uses a top-left origin.
enum FocalCropPolicy {
    static func normalizedSubjectRegion(_ region: CGRect) -> CGRect {
        let x = min(1, max(0, region.minX))
        let y = min(1, max(0, region.minY))
        let maxX = min(1, max(x, region.maxX))
        let maxY = min(1, max(y, region.maxY))
        return CGRect(x: x, y: y, width: maxX - x, height: maxY - y)
    }

    static func topLeftRegion(fromVisionBoundingBox box: CGRect) -> CGRect {
        normalizedSubjectRegion(CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
    }

    static func recommendedOffset(subjectRegion: CGRect, sourceAspect: CGFloat, containerAspect: CGFloat) -> CGSize {
        let region = normalizedSubjectRegion(subjectRegion)
        guard region.width > 0, region.height > 0 else { return .zero }
        return FillCropConstraint(sourceAspect: sourceAspect, containerAspect: containerAspect)
            .offsetCenteringSourcePoint(CGPoint(x: region.midX, y: region.midY))
    }
}

enum MemoryBookPrintQuality {
    static let preferredPPI: CGFloat = 300
    static let minimumPPI: CGFloat = 150

    static func drawnSizeInPoints(
        container: CGRect,
        photo: ArchivePhoto,
        element: MemoryBookElement
    ) -> CGSize {
        let sourceAspect = max(0.01, photo.aspectRatio)
        let baseHeight: CGFloat = switch element.imageContentMode {
        case .fill: max(container.height, container.width / sourceAspect)
        case .fit: min(container.height, container.width / sourceAspect)
        }
        let geometry = MemoryBookImageTransformGeometry(container: container, sourceAspect: sourceAspect, element: element)
        return CGSize(
            width: sourceAspect * baseHeight * geometry.transform.scale,
            height: baseHeight * geometry.transform.scale
        )
    }

    static func effectivePPI(
        container: CGRect,
        photo: ArchivePhoto,
        element: MemoryBookElement
    ) -> CGFloat? {
        guard let pixels = photo.pixelSize, pixels.width > 0, pixels.height > 0 else { return nil }
        let drawn = drawnSizeInPoints(container: container, photo: photo, element: element)
        return min(
            pixels.width / max(1, drawn.width) * 72,
            pixels.height / max(1, drawn.height) * 72
        )
    }
}

enum MemoryBookCropQuality {
    /// Below this threshold an automatic aspect-fill discards enough of the
    /// source that a centred fallback can easily remove a face or pet. The
    /// user may keep the crop, but must explicitly review it first.
    static let minimumUnreviewedVisibleFraction: CGFloat = 0.65

    static func visibleSourceFraction(sourceAspect: CGFloat, containerAspect: CGFloat) -> CGFloat {
        let source = max(0.01, sourceAspect)
        let container = max(0.01, containerAspect)
        return min(source, container) / max(source, container)
    }
}

/// Local-only model evidence. These values are diagnostic/calibration inputs,
/// not a claim that the image contains a specific pet.
struct PetRecognitionEvidence: Codable, Equatable, Sendable {
    var policyVersion: Int
    var animalConfidence: Double
    var maximumReferenceSimilarity: Double
    var agreeingReferenceCount: Int
    var referenceCount: Int
    var wasHighAutoSelected: Bool
}

/// Persisted, aggregate feedback only. Tailor never uploads this summary,
/// photo metadata, pet names, or feature vectors.
struct PetRecognitionFeedbackSummary: Codable, Equatable, Sendable {
    var confirmedPetCount: Int = 0
    var confirmedNotPetCount: Int = 0
    var highAutoSelectedCount: Int = 0
    var highAutoFalsePositiveCount: Int = 0

    static func make(from photos: [ArchivePhoto]) -> PetRecognitionFeedbackSummary {
        PetRecognitionFeedbackSummary(
            confirmedPetCount: photos.filter { $0.decision == .selected }.count,
            confirmedNotPetCount: photos.filter { $0.decision == .excluded && $0.excludedReason == .userMarkedNotPet }.count,
            highAutoSelectedCount: photos.filter { $0.recognitionEvidence?.wasHighAutoSelected == true }.count,
            highAutoFalsePositiveCount: photos.filter {
                $0.recognitionEvidence?.wasHighAutoSelected == true
                    && $0.decision == .excluded
                    && $0.excludedReason == .userMarkedNotPet
            }.count
        )
    }
}

/// The only crop geometry policy used by the editor and PDF renderer.  The
/// transform is normalized to the destination frame, so it survives device
/// size and paper-size changes.  A candidate is projected back along its drag
/// vector until all four destination corners remain inside the rotated image.
struct FillCropConstraint: Equatable, Sendable {
    static let maximumScale: CGFloat = 3

    let sourceAspect: CGFloat
    let containerAspect: CGFloat
    let rotationDegrees: Double

    init(sourceAspect: CGFloat, containerAspect: CGFloat, rotationDegrees: Double = 0) {
        self.sourceAspect = max(0.01, sourceAspect)
        self.containerAspect = max(0.01, containerAspect)
        self.rotationDegrees = rotationDegrees
    }

    var minimumScale: CGFloat {
        // The aspect-fill image at scale 1 covers the frame before rotation.
        // Rotation enlarges the required source rectangle to contain each
        // destination corner; use that rectangle, not an arbitrary 0.5 limit.
        let base = baseDrawnSize
        let angle = CGFloat(rotationDegrees * .pi / 180)
        let c = abs(cos(angle)), s = abs(sin(angle))
        let requiredWidth = containerAspect * c + s
        let requiredHeight = containerAspect * s + c
        return min(Self.maximumScale, max(1, requiredWidth / base.width, requiredHeight / base.height))
    }

    func normalized(scale: CGFloat, offset: CGSize) -> (scale: CGFloat, offset: CGSize) {
        let validScale = min(Self.maximumScale, max(minimumScale, scale))
        let proposed = offset
        // A valid candidate is already the user's intended crop.  Only project
        // a candidate that would expose the page background back to the last
        // legal point on its drag vector. (The previous inverted guard did the
        // opposite and allowed invalid offsets to escape unchanged.)
        guard containsBlankEdge(scale: validScale, offset: proposed) else { return (validScale, proposed) }
        // A binary projection gives a stable, non-bouncy edge clamp for a
        // diagonal drag while preserving the user's intended direction.
        var low: CGFloat = 0
        var high: CGFloat = 1
        for _ in 0..<24 {
            let mid = (low + high) / 2
            let candidate = CGSize(width: proposed.width * mid, height: proposed.height * mid)
            if containsBlankEdge(scale: validScale, offset: candidate) { high = mid } else { low = mid }
        }
        return (validScale, CGSize(width: proposed.width * low, height: proposed.height * low))
    }

    /// Translate the detected source point toward the frame centre, then use
    /// the same projection as direct manipulation to guarantee no blank edge.
    func offsetCenteringSourcePoint(_ point: CGPoint) -> CGSize {
        let sourcePoint = CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y)))
        let size = baseDrawnSize
        let proposed = CGSize(
            width: -(sourcePoint.x - 0.5) * size.width / containerAspect,
            height: -(sourcePoint.y - 0.5) * size.height
        )
        // A fill crop often has spare room on only one axis. Projecting the
        // diagonal vector as a whole would collapse both components to zero
        // when the no-slack axis asks for even a tiny move. Preserve all legal
        // movement by clamping each axis first, then validate the combination.
        let horizontal = normalized(scale: 1, offset: CGSize(width: proposed.width, height: 0)).offset.width
        let vertical = normalized(scale: 1, offset: CGSize(width: 0, height: proposed.height)).offset.height
        return normalized(scale: 1, offset: CGSize(width: horizontal, height: vertical)).offset
    }

    func containsBlankEdge(scale: CGFloat, offset: CGSize) -> Bool {
        let size = baseDrawnSize
        let imageWidth = size.width * scale
        let imageHeight = size.height * scale
        let angle = CGFloat(rotationDegrees * .pi / 180)
        let c = cos(angle), s = sin(angle)
        let tx = offset.width * containerAspect
        let ty = offset.height
        for x in [-containerAspect / 2, containerAspect / 2] {
            for y in [-CGFloat(0.5), CGFloat(0.5)] {
                let dx = x - tx, dy = y - ty
                // Inverse rotation maps a frame corner into image coordinates.
                let ix = c * dx + s * dy
                let iy = -s * dx + c * dy
                if abs(ix) > imageWidth / 2 + 0.0000001 || abs(iy) > imageHeight / 2 + 0.0000001 { return true }
            }
        }
        return false
    }

    private var baseDrawnSize: CGSize {
        let scale = max(containerAspect / sourceAspect, 1)
        return CGSize(width: sourceAspect * scale, height: scale)
    }
}

/// The render-time counterpart of `FillCropConstraint`.  Every surface that
/// presents a memory-book image (editor, reader and PDF) receives this value
/// instead of independently re-deriving scale, offset or rotation.  The
/// prescribed order is deliberately explicit: clip the destination container,
/// then transform the source around that container's centre.
struct MemoryBookImageTransformGeometry: Equatable, Sendable {
    let container: CGRect
    let sourceAspect: CGFloat
    let transform: CropTransform
    let rotationDegrees: Double
    let flipHorizontal: Bool
    let flipVertical: Bool
    let contentMode: MemoryBookImageContentMode

    init(container: CGRect, sourceAspect: CGFloat, element: MemoryBookElement) {
        self.container = container
        self.sourceAspect = max(0.01, sourceAspect)
        rotationDegrees = element.rotationDegrees + element.imageTransformAdjustments.straightenDegrees
        flipHorizontal = element.imageTransformAdjustments.flipHorizontal
        flipVertical = element.imageTransformAdjustments.flipVertical
        contentMode = element.imageContentMode
        // Fit is a placement mode, not a crop mode.  Never carry an old
        // aspect-fill crop transform into it: that would silently enlarge and
        // crop a photo which is explicitly meant to be shown in full.
        guard element.imageContentMode == .fill else {
            transform = CropTransform()
            return
        }
        let constraint = FillCropConstraint(
            sourceAspect: sourceAspect,
            containerAspect: container.width / max(0.01, container.height),
            rotationDegrees: rotationDegrees
        )
        let normalized = constraint.normalized(scale: element.cropScale, offset: element.cropOffset)
        transform = CropTransform(scale: normalized.scale, offset: normalized.offset)
    }

    /// The unrotated, aspect-fill source rectangle.  Renderers apply scale,
    /// offset and rotation to this rectangle *inside* `container`'s clip.
    func sourceRect(sourcePixelSize: CGSize) -> CGRect {
        let source = CGSize(width: max(1, sourcePixelSize.width), height: max(1, sourcePixelSize.height))
        let baseScale: CGFloat
        switch contentMode {
        case .fill: baseScale = max(container.width / source.width, container.height / source.height)
        case .fit: baseScale = min(container.width / source.width, container.height / source.height)
        }
        let scale = baseScale * transform.scale
        let drawn = CGSize(width: source.width * scale, height: source.height * scale)
        // Fit is intentionally centred: panning a fully-visible photo creates
        // arbitrary paper gaps and defeats the promise that Fit shows it all.
        let centre = contentMode == .fit ? CGPoint(x: container.midX, y: container.midY) : CGPoint(
            x: container.midX + transform.offset.width * container.width,
            y: container.midY + transform.offset.height * container.height
        )
        return CGRect(x: centre.x - drawn.width / 2, y: centre.y - drawn.height / 2, width: drawn.width, height: drawn.height)
    }

    var sourceCentre: CGPoint {
        CGPoint(
            x: container.midX + transform.offset.width * container.width,
            y: container.midY + transform.offset.height * container.height
        )
    }
}

/// A normalized crop is independent of an iPhone canvas or a paper size.  It
/// is deliberately a value type so a crop sheet can keep edits local until
/// the user explicitly commits them.
struct CropTransform: Codable, Equatable, Sendable {
    var scale: CGFloat
    var offset: CGSize

    init(scale: CGFloat = 1, offset: CGSize = .zero) {
        self.scale = scale
        self.offset = offset
    }
}

/// Transaction state for one independent crop session.  The document never
/// receives `draftTransform`; callers apply it only from Done/Save and create
/// a single undo entry immediately before that mutation. `historyBaseline` is
/// intentionally retained separately from `entryElement`: it makes the
/// before-state used by Undo explicit even when a future UI refreshes the
/// presentation element.
struct MemoryBookCropSession: Equatable, Sendable {
    let pageID: UUID
    let elementID: UUID
    let entryElement: MemoryBookElement
    let historyBaseline: MemoryBookElement
    let sourceAspect: CGFloat
    let entryTransform: CropTransform
    var draftTransform: CropTransform

    init(pageID: UUID, element: MemoryBookElement, sourceAspect: CGFloat) {
        self.pageID = pageID
        elementID = element.id
        entryElement = element
        historyBaseline = element
        self.sourceAspect = max(0.01, sourceAspect)
        let constraint = FillCropConstraint(
            sourceAspect: sourceAspect,
            containerAspect: element.normalizedFrame.width / max(0.01, element.normalizedFrame.height),
            rotationDegrees: element.rotationDegrees
        )
        let normalized = constraint.normalized(scale: element.cropScale, offset: element.cropOffset)
        let transform = CropTransform(scale: normalized.scale, offset: normalized.offset)
        entryTransform = transform
        draftTransform = transform
    }

    var constraint: FillCropConstraint {
        FillCropConstraint(
            sourceAspect: sourceAspect,
            containerAspect: entryElement.normalizedFrame.width / max(0.01, entryElement.normalizedFrame.height),
            rotationDegrees: entryElement.rotationDegrees
        )
    }

    var hasUncommittedChanges: Bool {
        abs(draftTransform.scale - entryTransform.scale) > 0.0001
            || abs(draftTransform.offset.width - entryTransform.offset.width) > 0.0001
            || abs(draftTransform.offset.height - entryTransform.offset.height) > 0.0001
    }

    mutating func update(scale: CGFloat, offset: CGSize) {
        let normalized = constraint.normalized(scale: scale, offset: offset)
        draftTransform = CropTransform(scale: normalized.scale, offset: normalized.offset)
    }

    mutating func reset() {
        update(scale: 1, offset: .zero)
    }
}

struct Chapter: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var dateLabel: String
    /// A user-authored, optional note. It is deliberately neutral by default: Tailor never
    /// invents a story about a pet from a photograph.
    var note: String
    var photoIDs: [UUID]
    var isHidden: Bool
    var sortOrder: Int

    init(id: UUID, title: String, dateLabel: String, note: String = "", photoIDs: [UUID], isHidden: Bool, sortOrder: Int) {
        self.id = id
        self.title = title
        self.dateLabel = dateLabel
        self.note = note
        self.photoIDs = photoIDs
        self.isHidden = isHidden
        self.sortOrder = sortOrder
    }

    private enum CodingKeys: String, CodingKey { case id, title, dateLabel, note, photoIDs, isHidden, sortOrder }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        dateLabel = try values.decode(String.self, forKey: .dateLabel)
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        photoIDs = try values.decode([UUID].self, forKey: .photoIDs)
        isHidden = try values.decode(Bool.self, forKey: .isHidden)
        sortOrder = try values.decode(Int.self, forKey: .sortOrder)
    }
}

struct MemoryBookExportRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    /// Store a filename rather than an absolute sandbox path. The app container
    /// can move between installs while its Documents directory remains the
    /// correct resolution boundary for an existing archive.
    var fileName: String
    var exportedAt: Date
    var pageCount: Int
    var pageSize: PDFPageSize
    var watermarked: Bool
    var snapshotFingerprint: String?

    init(id: UUID = UUID(), fileName: String, exportedAt: Date = .now, pageCount: Int, pageSize: PDFPageSize, watermarked: Bool, snapshotFingerprint: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.exportedAt = exportedAt
        self.pageCount = pageCount
        self.pageSize = pageSize
        self.watermarked = watermarked
        self.snapshotFingerprint = snapshotFingerprint
    }

    var fileURL: URL { .documentsDirectory.appending(path: fileName) }
}

struct ArchiveDocument: Identifiable, Codable, Equatable, Sendable {
    var profile: PetProfile
    var photos: [ArchivePhoto]
    var chapters: [Chapter]
    var scanCheckpoint: ScanCheckpoint?
    var scanAuditMetrics: ScanAuditMetrics
    /// The saved, user-editable album. It deliberately belongs to the archive so
    /// reopening a draft never regenerates or overwrites manual page changes.
    var memoryBook: MemoryBookDocument?
    /// Successful exports are durable archive metadata. A cancelled or failed
    /// renderer never appends a record, so archive UI cannot advertise a
    /// partial PDF after a restart.
    var exportRecords: [MemoryBookExportRecord]
    /// A local aggregate used to decide when a human-reviewed calibration set
    /// is large enough. Thresholds are never automatically changed from it.
    var recognitionFeedback: PetRecognitionFeedbackSummary
    var updatedAt: Date

    var id: UUID { profile.id }

    init(profile: PetProfile, photos: [ArchivePhoto] = [], chapters: [Chapter] = [], scanCheckpoint: ScanCheckpoint? = nil, scanAuditMetrics: ScanAuditMetrics = .init(), memoryBook: MemoryBookDocument? = nil, exportRecords: [MemoryBookExportRecord] = [], recognitionFeedback: PetRecognitionFeedbackSummary? = nil, updatedAt: Date = .now) {
        self.profile = profile
        self.photos = photos
        self.chapters = chapters
        self.scanCheckpoint = scanCheckpoint
        self.scanAuditMetrics = scanAuditMetrics
        self.memoryBook = memoryBook
        self.exportRecords = exportRecords
        self.recognitionFeedback = recognitionFeedback ?? .make(from: photos)
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey { case profile, photos, chapters, scanCheckpoint, scanAuditMetrics, memoryBook, exportRecords, recognitionFeedback, updatedAt }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        profile = try values.decode(PetProfile.self, forKey: .profile)
        photos = try values.decodeIfPresent([ArchivePhoto].self, forKey: .photos) ?? []
        chapters = try values.decodeIfPresent([Chapter].self, forKey: .chapters) ?? []
        scanCheckpoint = try values.decodeIfPresent(ScanCheckpoint.self, forKey: .scanCheckpoint)
        scanAuditMetrics = try values.decodeIfPresent(ScanAuditMetrics.self, forKey: .scanAuditMetrics) ?? scanCheckpoint?.auditMetrics ?? .init()
        memoryBook = try values.decodeIfPresent(MemoryBookDocument.self, forKey: .memoryBook)
        exportRecords = try values.decodeIfPresent([MemoryBookExportRecord].self, forKey: .exportRecords) ?? []
        recognitionFeedback = try values.decodeIfPresent(PetRecognitionFeedbackSummary.self, forKey: .recognitionFeedback) ?? .make(from: photos)
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }
}

enum MemoryBookPageKind: String, Codable, Sendable {
    case cover, dedication, contents, chapterOpener, photoSelection, milestone, closing
}

enum MemoryBookLayout: String, Codable, CaseIterable, Sendable {
    case single, diptych, grid2x2, grid3x2, note
    /// Legacy persisted documents used `mosaic`; decode it as the explicit 3×2 grid.
    case mosaic

    var displayName: String {
        switch self {
        case .single: "Single"
        case .diptych: "Two-up"
        case .grid2x2: "Grid 2×2"
        case .grid3x2, .mosaic: "Grid 3×2"
        case .note: "Note"
        }
    }

    var photoCapacity: Int {
        switch self {
        case .single: 1
        case .diptych: 2
        case .grid2x2: 4
        case .grid3x2, .mosaic: 6
        case .note: 0
        }
    }

    var canonical: MemoryBookLayout { self == .mosaic ? .grid3x2 : self }
}

enum MemoryBookElementKind: String, Codable, Sendable { case image, text, shape }
enum MemoryBookElementOrigin: String, Codable, Sendable { case automatic, user }
enum MemoryBookTextStyle: String, Codable, Sendable, CaseIterable { case small, standard, large }

struct MemoryBookEditorSnapGuides: Equatable, Sendable {
    var vertical: CGFloat?
    var horizontal: CGFloat?

    static let none = MemoryBookEditorSnapGuides(vertical: nil, horizontal: nil)
}

struct MemoryBookEditorSnapResult: Equatable, Sendable {
    let frame: CGRect
    let guides: MemoryBookEditorSnapGuides
}

/// Pure normalized alignment policy for the page editor. Matching equivalent
/// anchors (left-to-left, centre-to-centre, right-to-right) avoids surprising
/// jumps such as snapping an element edge to a neighbour's centre. The UI
/// supplies a zoom-aware normalized threshold and renders the returned guides.
enum MemoryBookEditorSnapEngine {
    static func snap(
        frame: CGRect,
        peerFrames: [CGRect],
        safeInset: CGFloat = MemoryBookPageRenderPlan.safeInsetRatio,
        threshold: CGFloat
    ) -> MemoryBookEditorSnapResult {
        var result = frame

        var xCandidates: [(delta: CGFloat, guide: CGFloat)] = [
            (safeInset - frame.minX, safeInset),
            (0.5 - frame.midX, 0.5),
            ((1 - safeInset) - frame.maxX, 1 - safeInset)
        ]
        var yCandidates: [(delta: CGFloat, guide: CGFloat)] = [
            (safeInset - frame.minY, safeInset),
            (0.5 - frame.midY, 0.5),
            ((1 - safeInset) - frame.maxY, 1 - safeInset)
        ]
        for peer in peerFrames {
            xCandidates.append(contentsOf: [
                (peer.minX - frame.minX, peer.minX),
                (peer.midX - frame.midX, peer.midX),
                (peer.maxX - frame.maxX, peer.maxX)
            ])
            yCandidates.append(contentsOf: [
                (peer.minY - frame.minY, peer.minY),
                (peer.midY - frame.midY, peer.midY),
                (peer.maxY - frame.maxY, peer.maxY)
            ])
        }

        let xMatch = xCandidates.min { abs($0.delta) < abs($1.delta) }
        let yMatch = yCandidates.min { abs($0.delta) < abs($1.delta) }
        let vertical = xMatch.flatMap { match -> CGFloat? in
            guard abs(match.delta) <= threshold else { return nil }
            result.origin.x += match.delta
            return match.guide
        }
        let horizontal = yMatch.flatMap { match -> CGFloat? in
            guard abs(match.delta) <= threshold else { return nil }
            result.origin.y += match.delta
            return match.guide
        }
        return MemoryBookEditorSnapResult(
            frame: result,
            guides: MemoryBookEditorSnapGuides(vertical: vertical, horizontal: horizontal)
        )
    }
}

/// How an image occupies its user-owned frame. `fit` deliberately preserves
/// every pixel (with the page paper visible around it); `fill` is the familiar
/// editorial crop. Both modes are proportional and never stretch a photo.
enum MemoryBookImageContentMode: String, Codable, Sendable, CaseIterable {
    case fit, fill
}

/// A deliberately curated set rather than arbitrary installed fonts. The same
/// PostScript name is available to UIKit and Quartz, keeping preview/PDF text
/// identical and avoiding an unprintable "art font" choice.
enum MemoryBookTextFont: String, Codable, Sendable, CaseIterable {
    case editorial, quietSans, handwritten, cinema

    var displayName: String {
        switch self {
        case .editorial: "Editorial"
        case .quietSans: "Quiet sans"
        case .handwritten: "Handwritten"
        case .cinema: "Cinema"
        }
    }

    func font(size: CGFloat, fallback: MemoryBookFontToken) -> UIFont {
        let candidates: [String]
        switch self {
        case .editorial:
            candidates = fallback == .display
                ? [MemoryBookTypography.displayPostScriptName, MemoryBookTypography.displayFallbackPostScriptName, "Georgia"]
                : [MemoryBookTypography.bodyPostScriptName, MemoryBookTypography.bodyFallbackPostScriptName, "Avenir-Book"]
        case .quietSans: candidates = ["Avenir-Book", "HelveticaNeue", "Helvetica"]
        case .handwritten: candidates = ["Noteworthy-Light", "BradleyHandITCTT-Bold", "ChalkboardSE-Regular"]
        case .cinema: candidates = ["AvenirNext-DemiBold", "HelveticaNeue-Medium", "Helvetica-Bold"]
        }
        return candidates.lazy.compactMap { UIFont(name: $0, size: size) }.first ?? UIFont.systemFont(ofSize: size)
    }
}

enum MemoryBookTextColor: String, Codable, Sendable, CaseIterable {
    case ink, clay, moss, mist, night

    var displayName: String {
        switch self {
        case .ink: "Ink"
        case .clay: "Clay"
        case .moss: "Moss"
        case .mist: "Mist"
        case .night: "Night"
        }
    }

    func rgb(fallback: MemoryBookRGB) -> MemoryBookRGB {
        switch self {
        case .ink: fallback
        case .clay: .init(red: 0.72, green: 0.29, blue: 0.17)
        case .moss: .init(red: 0.18, green: 0.34, blue: 0.26)
        case .mist: .init(red: 0.38, green: 0.45, blue: 0.40)
        case .night: .init(red: 0.09, green: 0.17, blue: 0.15)
        }
    }
}

/// Persisted, renderer-independent styling for a page element. Measurements
/// are ratios of the paper width so the same composition scales from the
/// editor viewport to Letter/A4 PDF without point-size drift.
enum MemoryBookElementMask: String, Codable, Sendable, CaseIterable {
    case rectangle, roundedRectangle, ellipse

    var displayName: String {
        switch self {
        case .rectangle: "Square"
        case .roundedRectangle: "Rounded"
        case .ellipse: "Oval"
        }
    }
}

enum MemoryBookElementBorderStyle: String, Codable, Sendable, CaseIterable {
    case none, solid, dashed

    var displayName: String { rawValue.capitalized }
}

struct MemoryBookElementAppearance: Codable, Equatable, Sendable {
    var opacity: Double
    var mask: MemoryBookElementMask
    var cornerRadiusRatio: CGFloat
    var borderStyle: MemoryBookElementBorderStyle
    var borderWidthRatio: CGFloat
    var borderColor: MemoryBookRGB
    var shadowOpacity: Double
    var shadowBlurRatio: CGFloat
    var shadowOffset: CGSize
    /// Used by decoration elements. Nil lets image/text elements preserve
    /// their source content without inventing a background fill.
    var fillColor: MemoryBookRGB? = nil

    static let `default` = MemoryBookElementAppearance(
        opacity: 1,
        mask: .roundedRectangle,
        cornerRadiusRatio: 4 / 612,
        borderStyle: .none,
        borderWidthRatio: 2 / 612,
        borderColor: .init(red: 1, green: 1, blue: 1),
        shadowOpacity: 0,
        shadowBlurRatio: 8 / 612,
        shadowOffset: CGSize(width: 0, height: 4 / 612)
    )

    mutating func normalize() {
        opacity = min(1, max(0.1, opacity))
        cornerRadiusRatio = min(0.20, max(0, cornerRadiusRatio))
        borderWidthRatio = min(0.03, max(0, borderWidthRatio))
        shadowOpacity = min(0.8, max(0, shadowOpacity))
        shadowBlurRatio = min(0.08, max(0, shadowBlurRatio))
        shadowOffset.width = min(0.10, max(-0.10, shadowOffset.width))
        shadowOffset.height = min(0.10, max(-0.10, shadowOffset.height))
    }
}

/// Non-destructive photo finishing values. Neutral defaults preserve legacy
/// documents byte-for-byte at the model level; renderers clamp again before
/// handing the values to Core Image.
struct MemoryBookImageAdjustments: Codable, Equatable, Sendable {
    var exposure: Double = 0
    var brightness: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var warmth: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var vignette: Double = 0
    var sharpness: Double = 0

    static let `default` = MemoryBookImageAdjustments()

    mutating func normalize() {
        exposure = min(2, max(-2, exposure))
        brightness = min(0.5, max(-0.5, brightness))
        contrast = min(1.5, max(0.5, contrast))
        saturation = min(2, max(0, saturation))
        warmth = min(1, max(-1, warmth))
        highlights = min(1, max(0, highlights))
        shadows = min(1, max(-1, shadows))
        vignette = min(1, max(0, vignette))
        sharpness = min(1, max(0, sharpness))
    }

    var isNeutral: Bool { self == .default }
}

/// Reversible source-image geometry that lives inside the composition frame.
/// `MemoryBookElement.rotationDegrees` rotates the complete frame; these
/// values straighten or mirror only the photograph clipped inside it.
struct MemoryBookImageTransformAdjustments: Codable, Equatable, Sendable {
    var straightenDegrees: Double = 0
    var flipHorizontal: Bool = false
    var flipVertical: Bool = false

    static let `default` = MemoryBookImageTransformAdjustments()

    mutating func normalize() {
        straightenDegrees = min(15, max(-15, straightenDegrees))
        if abs(straightenDegrees) < 0.05 { straightenDegrees = 0 }
    }
}

enum MemoryBookImageProcessor {
    private static let context = CIContext(options: [.cacheIntermediates: true])

    static func process(_ image: UIImage, treatment: MemoryBookImageTreatment, adjustments source: MemoryBookImageAdjustments = .default) -> UIImage {
        if treatment == .original, source.isNeutral { return image }
        guard let cgImage = image.cgImage else { return image }
        var adjustments = source
        adjustments.normalize()
        var output = CIImage(cgImage: cgImage)

        if treatment == .mono, let filter = CIFilter(name: "CIPhotoEffectMono") {
            filter.setValue(output, forKey: kCIInputImageKey)
            output = filter.outputImage ?? output
        }
        if adjustments.exposure != 0, let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(adjustments.exposure, forKey: kCIInputEVKey)
            output = filter.outputImage ?? output
        }
        if adjustments.brightness != 0 || adjustments.contrast != 1 || adjustments.saturation != 1,
           let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(adjustments.brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(adjustments.contrast, forKey: kCIInputContrastKey)
            filter.setValue(adjustments.saturation, forKey: kCIInputSaturationKey)
            output = filter.outputImage ?? output
        }
        if adjustments.warmth != 0, let filter = CIFilter(name: "CITemperatureAndTint") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6_500, y: 0), forKey: "inputNeutral")
            filter.setValue(CIVector(x: 6_500 + adjustments.warmth * 2_500, y: 0), forKey: "inputTargetNeutral")
            output = filter.outputImage ?? output
        }
        if adjustments.highlights != 0 || adjustments.shadows != 0,
           let filter = CIFilter(name: "CIHighlightShadowAdjust") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(1 - adjustments.highlights, forKey: "inputHighlightAmount")
            filter.setValue(adjustments.shadows, forKey: "inputShadowAmount")
            output = filter.outputImage ?? output
        }
        if adjustments.vignette > 0, let filter = CIFilter(name: "CIVignette") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(adjustments.vignette * 1.5, forKey: kCIInputIntensityKey)
            filter.setValue(min(output.extent.width, output.extent.height) * 0.45, forKey: kCIInputRadiusKey)
            output = filter.outputImage ?? output
        }
        if adjustments.sharpness > 0, let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(adjustments.sharpness, forKey: kCIInputSharpnessKey)
            output = filter.outputImage ?? output
        }
        guard let rendered = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }

    /// A deliberately restrained, deterministic starting point. It analyses
    /// only average luminance and never crops, detects faces or changes the
    /// original asset. Users can refine every returned value afterwards.
    static func conservativeAutoEnhancement(for image: UIImage) -> MemoryBookImageAdjustments {
        guard let cgImage = image.cgImage else { return .default }
        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIAreaAverage") else { return .default }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: input.extent), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return .default }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        let red = Double(pixel[0]) / 255
        let green = Double(pixel[1]) / 255
        let blue = Double(pixel[2]) / 255
        let luminance = max(0.02, 0.2126 * red + 0.7152 * green + 0.0722 * blue)
        let exposure = min(0.45, max(-0.35, log2(0.48 / luminance)))
        return MemoryBookImageAdjustments(
            exposure: exposure,
            brightness: 0,
            contrast: 1.04,
            saturation: 1.03,
            warmth: 0,
            highlights: luminance > 0.62 ? 0.14 : 0.06,
            shadows: luminance < 0.42 ? 0.18 : 0.08,
            vignette: 0,
            sharpness: 0.12
        )
    }
}

/// A page element uses normalized coordinates (0...1), so the same edit can be
/// rendered in SwiftUI preview and in a Letter/A4 PDF without coordinate drift.
struct MemoryBookElement: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: MemoryBookElementKind
    var assetID: UUID?
    var text: String?
    var normalizedFrame: CGRect
    var cropScale: CGFloat
    var cropOffset: CGSize
    var rotationDegrees: Double
    var zIndex: Int
    var textStyle: MemoryBookTextStyle
    /// Continuous user-controlled font-size multiplier. Text style remains a
    /// useful preset, while this value records the exact iOS slider choice.
    var textFontScale: CGFloat
    var imageContentMode: MemoryBookImageContentMode
    var textFont: MemoryBookTextFont
    var textColor: MemoryBookTextColor
    /// Optional exact color selected from the native iOS color picker. When
    /// nil, the named Tailor palette color remains the source of truth.
    var textCustomColor: MemoryBookRGB?
    var textTypographyAdjustments: MemoryBookTextTypographyAdjustments
    /// Nil is supported only for legacy/system text.  Newly generated editable
    /// text always has an explicit product field role.
    var textField: MemoryBookTextField?
    var isLayoutLocked: Bool
    /// User-facing interaction lock. This is intentionally separate from
    /// `isLayoutLocked`, which protects authored geometry from auto-arrange.
    var isInteractionLocked: Bool
    /// Page-local grouping identity. Grouping affects editor selection and
    /// transforms only; renderers continue drawing the original elements.
    var groupID: UUID?
    var isHidden: Bool
    var appearance: MemoryBookElementAppearance
    var imageAdjustments: MemoryBookImageAdjustments
    var imageTransformAdjustments: MemoryBookImageTransformAdjustments
    var origin: MemoryBookElementOrigin
    var updatedAt: Date

    init(id: UUID = UUID(), kind: MemoryBookElementKind, assetID: UUID? = nil, text: String? = nil, normalizedFrame: CGRect, cropScale: CGFloat = 1, cropOffset: CGSize = .zero, rotationDegrees: Double = 0, zIndex: Int = 0, textStyle: MemoryBookTextStyle = .standard, textFontScale: CGFloat = 1, imageContentMode: MemoryBookImageContentMode = .fill, textFont: MemoryBookTextFont = .editorial, textColor: MemoryBookTextColor = .ink, textCustomColor: MemoryBookRGB? = nil, textTypographyAdjustments: MemoryBookTextTypographyAdjustments = .default, textField: MemoryBookTextField? = nil, isLayoutLocked: Bool = false, isInteractionLocked: Bool = false, groupID: UUID? = nil, isHidden: Bool = false, appearance: MemoryBookElementAppearance = .default, imageAdjustments: MemoryBookImageAdjustments = .default, imageTransformAdjustments: MemoryBookImageTransformAdjustments = .default, origin: MemoryBookElementOrigin = .automatic, updatedAt: Date = .now) {
        self.id = id; self.kind = kind; self.assetID = assetID; self.text = text
        self.normalizedFrame = normalizedFrame; self.cropScale = cropScale; self.cropOffset = cropOffset
        self.rotationDegrees = rotationDegrees; self.zIndex = zIndex; self.textStyle = textStyle; self.textFontScale = textFontScale; self.imageContentMode = imageContentMode; self.textFont = textFont; self.textColor = textColor; self.textCustomColor = textCustomColor; self.textTypographyAdjustments = textTypographyAdjustments; self.textField = textField; self.isLayoutLocked = isLayoutLocked; self.isInteractionLocked = isInteractionLocked; self.groupID = groupID; self.isHidden = isHidden
        self.appearance = appearance; self.imageAdjustments = imageAdjustments; self.imageTransformAdjustments = imageTransformAdjustments; self.origin = origin; self.updatedAt = updatedAt
    }

    private struct LegacyPoint: Decodable { let x: CGFloat; let y: CGFloat }
    private struct LegacySize: Decodable { let width: CGFloat; let height: CGFloat }
    private struct LegacyRect: Decodable { let origin: LegacyPoint; let size: LegacySize }

    private enum CodingKeys: String, CodingKey { case id, kind, assetID, text, normalizedFrame, cropScale, cropOffset, rotationDegrees, zIndex, textStyle, textFontScale, imageContentMode, textFont, textColor, textCustomColor, textTypographyAdjustments, textField, isLayoutLocked, isInteractionLocked, groupID, isHidden, appearance, imageAdjustments, imageTransformAdjustments, origin, updatedAt }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id); kind = try values.decode(MemoryBookElementKind.self, forKey: .kind)
        assetID = try values.decodeIfPresent(UUID.self, forKey: .assetID); text = try values.decodeIfPresent(String.self, forKey: .text)
        if let frame = try? values.decode(CGRect.self, forKey: .normalizedFrame) {
            normalizedFrame = frame
        } else {
            // Swift's Codable representation for CGRect changed across SDK
            // generations. Existing Tailor documents used the keyed
            // origin/size shape, so continue accepting it during migration.
            let frame = try values.decode(LegacyRect.self, forKey: .normalizedFrame)
            normalizedFrame = CGRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height
            )
        }
        cropScale = try values.decodeIfPresent(CGFloat.self, forKey: .cropScale) ?? 1
        if !values.contains(.cropOffset) {
            cropOffset = .zero
        } else if let offset = try? values.decode(CGSize.self, forKey: .cropOffset) {
            cropOffset = offset
        } else {
            let offset = try values.decode(LegacySize.self, forKey: .cropOffset)
            cropOffset = CGSize(width: offset.width, height: offset.height)
        }
        rotationDegrees = try values.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        zIndex = try values.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0
        textStyle = try values.decodeIfPresent(MemoryBookTextStyle.self, forKey: .textStyle) ?? .standard
        textFontScale = min(2.4, max(0.5, try values.decodeIfPresent(CGFloat.self, forKey: .textFontScale) ?? 1))
        // Legacy template images were aspect-fill. Preserve that appearance;
        // Fit remains available only when a user or newer document records it
        // explicitly.
        imageContentMode = try values.decodeIfPresent(MemoryBookImageContentMode.self, forKey: .imageContentMode) ?? .fill
        textFont = try values.decodeIfPresent(MemoryBookTextFont.self, forKey: .textFont) ?? .editorial
        textColor = try values.decodeIfPresent(MemoryBookTextColor.self, forKey: .textColor) ?? .ink
        textCustomColor = try values.decodeIfPresent(MemoryBookRGB.self, forKey: .textCustomColor)
        textTypographyAdjustments = try values.decodeIfPresent(MemoryBookTextTypographyAdjustments.self, forKey: .textTypographyAdjustments) ?? .default
        textTypographyAdjustments.normalize()
        textField = try values.decodeIfPresent(MemoryBookTextField.self, forKey: .textField)
        isLayoutLocked = try values.decodeIfPresent(Bool.self, forKey: .isLayoutLocked) ?? false
        isInteractionLocked = try values.decodeIfPresent(Bool.self, forKey: .isInteractionLocked) ?? false
        groupID = try values.decodeIfPresent(UUID.self, forKey: .groupID)
        isHidden = try values.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        appearance = try values.decodeIfPresent(MemoryBookElementAppearance.self, forKey: .appearance) ?? .default
        appearance.normalize()
        imageAdjustments = try values.decodeIfPresent(MemoryBookImageAdjustments.self, forKey: .imageAdjustments) ?? .default
        imageAdjustments.normalize()
        imageTransformAdjustments = try values.decodeIfPresent(MemoryBookImageTransformAdjustments.self, forKey: .imageTransformAdjustments) ?? .default
        imageTransformAdjustments.normalize()
        origin = try values.decodeIfPresent(MemoryBookElementOrigin.self, forKey: .origin) ?? .automatic
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }
}

/// One source of truth for both the SwiftUI preview and the exported PDF.
struct MemoryBookPage: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: MemoryBookPageKind
    var title: String
    var subtitle: String
    var chapterID: UUID?
    var photoIDs: [UUID]
    var layout: MemoryBookLayout
    var pageNumber: Int
    var elements: [MemoryBookElement]
    var styleOverride: AlbumStyle?
    /// Nil preserves the selected style's authored paper color.
    var backgroundColor: MemoryBookRGB?
    var isLocked: Bool

    init(id: UUID = UUID(), kind: MemoryBookPageKind, title: String, subtitle: String = "", chapterID: UUID? = nil, photoIDs: [UUID] = [], layout: MemoryBookLayout = .note, pageNumber: Int, elements: [MemoryBookElement] = [], styleOverride: AlbumStyle? = nil, backgroundColor: MemoryBookRGB? = nil, isLocked: Bool = false) {
        self.id = id; self.kind = kind; self.title = title; self.subtitle = subtitle
        self.chapterID = chapterID; self.photoIDs = photoIDs; self.layout = layout; self.pageNumber = pageNumber; self.elements = elements; self.styleOverride = styleOverride; self.backgroundColor = backgroundColor; self.isLocked = isLocked
    }

    private enum CodingKeys: String, CodingKey { case id, kind, title, subtitle, chapterID, photoIDs, layout, pageNumber, elements, styleOverride, backgroundColor, isLocked }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id); kind = try values.decode(MemoryBookPageKind.self, forKey: .kind)
        title = try values.decode(String.self, forKey: .title); subtitle = try values.decode(String.self, forKey: .subtitle)
        chapterID = try values.decodeIfPresent(UUID.self, forKey: .chapterID); photoIDs = try values.decode([UUID].self, forKey: .photoIDs)
        layout = try values.decode(MemoryBookLayout.self, forKey: .layout); pageNumber = try values.decode(Int.self, forKey: .pageNumber)
        elements = try values.decodeIfPresent([MemoryBookElement].self, forKey: .elements) ?? []
        styleOverride = try values.decodeIfPresent(AlbumStyle.self, forKey: .styleOverride)
        backgroundColor = try values.decodeIfPresent(MemoryBookRGB.self, forKey: .backgroundColor)
        isLocked = try values.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }
}

struct MemoryBookDocument: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { profile.id }
    var profile: PetProfile
    var photos: [ArchivePhoto]
    var chapters: [Chapter]
    var pages: [MemoryBookPage]
    var style: AlbumStyle
    var pageSize: PDFPageSize
    var schemaVersion: Int
    var updatedAt: Date

    var eligiblePhotos: [ArchivePhoto] { photos.filter(\.isEligibleForArchive) }

    init(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pages: [MemoryBookPage], style: AlbumStyle, pageSize: PDFPageSize, schemaVersion: Int = 2, updatedAt: Date = .now) {
        self.profile = profile; self.photos = photos; self.chapters = chapters; self.pages = pages
        self.style = style; self.pageSize = pageSize; self.schemaVersion = schemaVersion; self.updatedAt = updatedAt
    }
}

enum MemoryBookIssueSeverity: String, Codable, Sendable { case blocking, suggestion }

struct MemoryBookElementFrameRepair: Equatable, Sendable {
    let elementID: UUID
    let frame: CGRect
}

/// The exact document mutation behind a Book Check suggestion. Keeping the
/// target geometry in the issue makes the repair explainable, deterministic
/// and testable instead of rerunning a potentially different heuristic after
/// the user taps Fix.
enum MemoryBookIssueRepair: Equatable, Sendable {
    case elementFrames([MemoryBookElementFrameRepair])
    case recenterElementFrames([MemoryBookElementFrameRepair])
    case elementRotation(Double)
    case textColor(MemoryBookRGB)

    var actionLabel: String {
        switch self {
        case .elementFrames: "Align"
        case .recenterElementFrames: "Balance page"
        case .elementRotation: "Straighten"
        case .textColor: "Improve contrast"
        }
    }
}

struct MemoryBookIssue: Identifiable, Equatable, Sendable {
    var id = UUID()
    var severity: MemoryBookIssueSeverity
    var pageID: UUID?
    /// A Book Check issue is actionable only when it can point back to the
    /// persisted element that caused it. `nil` is reserved for document-wide
    /// issues such as a book with no photos at all.
    var elementID: UUID?
    /// Text issues also retain their semantic field, so the editor never
    /// guesses which text box to open from display order or z-index.
    var field: MemoryBookTextField?
    var message: String
    var repair: MemoryBookIssueRepair?

    init(
        id: UUID = UUID(),
        severity: MemoryBookIssueSeverity,
        pageID: UUID?,
        elementID: UUID? = nil,
        field: MemoryBookTextField? = nil,
        message: String,
        repair: MemoryBookIssueRepair? = nil
    ) {
        self.id = id
        self.severity = severity
        self.pageID = pageID
        self.elementID = elementID
        self.field = field
        self.message = message
        self.repair = repair
    }
}

struct MemoryBookLayoutChangeSummary: Equatable, Sendable {
    let pageID: UUID
    let layout: MemoryBookLayout
    let retainedPhotoCount: Int
    let movedPhotoCount: Int
    let newPageCount: Int
    /// Locked image elements are intentionally never regenerated or moved by a
    /// template change. This makes the confirmation's impact explicit when a
    /// requested template has fewer slots than the locked elements already on
    /// the page (including Note, whose capacity is zero).
    let lockedPhotoCount: Int

    var hasLockedCapacityImpact: Bool { lockedPhotoCount > layout.photoCapacity }

    var message: String {
        let movement = movedPhotoCount == 0
            ? "This page will keep its \(retainedPhotoCount) photo\(retainedPhotoCount == 1 ? "" : "s")."
            : "This page will keep \(retainedPhotoCount) photo\(retainedPhotoCount == 1 ? "" : "s") and move \(movedPhotoCount) to \(newPageCount) new page\(newPageCount == 1 ? "" : "s") in this chapter."
        guard lockedPhotoCount > 0 else { return movement }
        let locked = " \(lockedPhotoCount) locked photo\(lockedPhotoCount == 1 ? "" : "s") will stay exactly where placed and will not be rearranged."
        if hasLockedCapacityImpact {
            return movement + locked + " This means the source page can exceed the \(layout.displayName) template capacity."
        }
        return movement + locked
    }
}

extension MemoryBookDocument {
    /// Freeze the document's page geometry, style and optional free-sample
    /// watermark before handing it to any renderer. Consumers never infer a
    /// different page order or template from chapters.
    func renderPlans(watermarked: Bool = false) -> [MemoryBookPageRenderPlan] {
        let size = MemoryBookPageRenderPlan.points(for: pageSize)
        let migrated = migratedLegacyTextFields()
        return migrated.pages.map { MemoryBookPageRenderPlan(page: $0, document: migrated, pageSize: size, watermarked: watermarked) }
    }

    func renderManifest(watermarked: Bool = false) -> MemoryBookRenderManifest {
        MemoryBookRenderManifest(documentID: id, pageSize: pageSize, watermarked: watermarked, plans: renderPlans(watermarked: watermarked))
    }

    func exportSnapshot(watermarked: Bool = false) -> MemoryBookExportSnapshot {
        let document = migratedLegacyTextFields()
        let manifest = document.renderManifest(watermarked: watermarked)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = (try? encoder.encode(manifest)) ?? Data()
        let fingerprint = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        return MemoryBookExportSnapshot(document: document, manifest: manifest, fingerprint: fingerprint)
    }

    mutating func renumberPages() {
        for index in pages.indices { pages[index].pageNumber = index + 1 }
        updatedAt = .now
    }

    /// Fit means the element's own bounds follow the source photo. Keeping a
    /// landscape template rectangle around a portrait source creates a false
    /// coloured "background" and a selection box that does not describe the
    /// actual photo. This migration is idempotent and preserves each frame's
    /// centre while shrinking only the surplus axis.
    @discardableResult
    mutating func normalizeFitImageFramesToAssetAspect() -> Bool {
        var changed = false
        for pageIndex in pages.indices {
            for elementIndex in pages[pageIndex].elements.indices {
                let element = pages[pageIndex].elements[elementIndex]
                guard element.kind == .image,
                      element.imageContentMode == .fit,
                      let assetID = element.assetID,
                      let photo = photos.first(where: { $0.id == assetID }),
                      photo.aspectRatio > 0 else { continue }
                var migratedElement = element
                if migratedElement.cropScale != 1 || migratedElement.cropOffset != .zero {
                    migratedElement.cropScale = 1
                    migratedElement.cropOffset = .zero
                    changed = true
                }
                let current = migratedElement.normalizedFrame
                let currentAspect = current.width / max(0.0001, current.height)
                if abs(currentAspect - photo.aspectRatio) > 0.001 {
                    var fitted = current
                    if currentAspect > photo.aspectRatio {
                        fitted.size.width = current.height * photo.aspectRatio
                        fitted.origin.x = current.midX - fitted.width / 2
                    } else {
                        fitted.size.height = current.width / photo.aspectRatio
                        fitted.origin.y = current.midY - fitted.height / 2
                    }
                    migratedElement.normalizedFrame = fitted
                    changed = true
                }
                pages[pageIndex].elements[elementIndex] = migratedElement
            }
        }
        if changed { updatedAt = .now }
        return changed
    }

    /// Character limits are deliberately page-kind based. A compact photo page
    /// must stay legible beside imagery, while a note/dedication page can hold
    /// a longer user-authored message.
    func textCharacterLimit(on page: MemoryBookPage) -> Int {
        page.kind == .photoSelection && page.layout.canonical != .note ? 120 : 240
    }

    func textCharacterLimit(for element: MemoryBookElement, on page: MemoryBookPage) -> Int {
        element.textField?.characterLimit ?? textCharacterLimit(on: page)
    }

    func textMeasurement(for element: MemoryBookElement, on page: MemoryBookPage) -> MemoryBookTextMeasurement? {
        guard element.kind == .text else { return nil }
        return textLayout(for: element, on: page)?.measurement
    }

    func textLayout(for element: MemoryBookElement, on page: MemoryBookPage) -> MemoryBookTextLayoutSnapshot? {
        guard element.kind == .text else { return nil }
        let migrated = migratedLegacyTextFields()
        guard let migratedPage = migrated.pages.first(where: { $0.id == page.id }),
              let migratedElement = migratedPage.elements.first(where: { $0.id == element.id }) else { return nil }
        let plan = MemoryBookPageRenderPlan(page: migratedPage, document: migrated, pageSize: MemoryBookPageRenderPlan.points(for: pageSize))
        return plan.textLayout(for: migratedElement)
    }

    func textReadability(for element: MemoryBookElement, on page: MemoryBookPage) -> MemoryBookTextReadabilityAssessment? {
        guard element.kind == .text else { return nil }
        let migrated = migratedLegacyTextFields()
        guard let migratedPage = migrated.pages.first(where: { $0.id == page.id }),
              let migratedElement = migratedPage.elements.first(where: { $0.id == element.id }) else { return nil }
        let plan = MemoryBookPageRenderPlan(page: migratedPage, document: migrated, pageSize: MemoryBookPageRenderPlan.points(for: pageSize))
        guard let layout = plan.textLayout(for: migratedElement) else { return nil }
        return Self.readabilityAssessment(element: migratedElement, layout: layout, plan: plan)
    }

    func textLayout(
        text: String,
        style: MemoryBookTextStyle,
        fontScale: CGFloat = 1,
        typography: MemoryBookTextTypographyAdjustments = .default,
        normalizedFrame: CGRect,
        on page: MemoryBookPage,
        zIndex: Int = 20,
        field: MemoryBookTextField? = nil
    ) -> MemoryBookTextLayoutSnapshot {
        let migrated = migratedLegacyTextFields()
        let migratedPage = migrated.pages.first(where: { $0.id == page.id }) ?? page
        let probe = MemoryBookElement(kind: .text, text: text, normalizedFrame: normalizedFrame, zIndex: zIndex, textStyle: style, textFontScale: fontScale, textTypographyAdjustments: typography, textField: field)
        let plan = MemoryBookPageRenderPlan(page: migratedPage, document: migrated, pageSize: MemoryBookPageRenderPlan.points(for: pageSize))
        return MemoryBookPageRenderPlan.makeTextLayout(
            element: probe,
            pageKind: migratedPage.kind,
            pageSize: plan.pageSize,
            paperRect: plan.paperRect,
            safeRect: plan.safeRect,
            style: plan.style,
            watermarked: false
        )
    }

    func textReadability(
        style: MemoryBookTextStyle,
        fontScale: CGFloat = 1,
        color: MemoryBookTextColor = .ink,
        customColor: MemoryBookRGB? = nil,
        normalizedFrame: CGRect,
        on page: MemoryBookPage,
        zIndex: Int = 20,
        field: MemoryBookTextField? = nil
    ) -> MemoryBookTextReadabilityAssessment {
        let migrated = migratedLegacyTextFields()
        let migratedPage = migrated.pages.first(where: { $0.id == page.id }) ?? page
        let probe = MemoryBookElement(
            kind: .text,
            text: "Readability",
            normalizedFrame: normalizedFrame,
            zIndex: zIndex,
            textStyle: style,
            textFontScale: fontScale,
            textColor: color,
            textCustomColor: customColor,
            textField: field
        )
        let plan = MemoryBookPageRenderPlan(page: migratedPage, document: migrated, pageSize: MemoryBookPageRenderPlan.points(for: pageSize))
        let layout = MemoryBookPageRenderPlan.makeTextLayout(
            element: probe,
            pageKind: migratedPage.kind,
            pageSize: plan.pageSize,
            paperRect: plan.paperRect,
            safeRect: plan.safeRect,
            style: plan.style,
            watermarked: false
        )
        return Self.readabilityAssessment(element: probe, layout: layout, plan: plan)
    }

    private static func readabilityAssessment(
        element: MemoryBookElement,
        layout: MemoryBookTextLayoutSnapshot,
        plan: MemoryBookPageRenderPlan
    ) -> MemoryBookTextReadabilityAssessment {
        let fallback = plan.fontToken(for: element) == .display ? plan.style.ink : plan.style.secondary
        let foreground = element.textCustomColor ?? element.textColor.rgb(fallback: fallback)
        let coordinatedInk = plan.style.ink
        let black = MemoryBookRGB(red: 0, green: 0, blue: 0)
        let white = MemoryBookRGB(red: 1, green: 1, blue: 1)
        let candidates = [coordinatedInk, black, white]
        let recommended = candidates.max { lhs, rhs in
            lhs.contrastRatio(with: plan.paperColor) < rhs.contrastRatio(with: plan.paperColor)
        } ?? coordinatedInk
        return .init(
            fontSize: layout.spec.fontSize,
            contrastRatio: foreground.contrastRatio(with: plan.paperColor),
            foreground: foreground,
            background: plan.paperColor,
            recommendedForeground: coordinatedInk.contrastRatio(with: plan.paperColor) >= MemoryBookTextReadabilityAssessment.minimumContrastRatio
                ? coordinatedInk
                : recommended
        )
    }

    /// Measures an in-progress editor draft using the same TextLayoutSpec that
    /// Preview/PDF put into their render plan.  A sheet must never fall back to
    /// a character-count estimate while the saved book uses true line boxes.
    func textMeasurement(
        text: String,
        style: MemoryBookTextStyle,
        fontScale: CGFloat = 1,
        typography: MemoryBookTextTypographyAdjustments = .default,
        normalizedFrame: CGRect,
        on page: MemoryBookPage,
        zIndex: Int = 20,
        field: MemoryBookTextField? = nil
    ) -> MemoryBookTextMeasurement {
        textLayout(
            text: text,
            style: style,
            fontScale: fontScale,
            typography: typography,
            normalizedFrame: normalizedFrame,
            on: page,
            zIndex: zIndex,
            field: field
        ).measurement
    }

    func textDraftValidation(
        text: String,
        style: MemoryBookTextStyle,
        fontScale: CGFloat = 1,
        typography: MemoryBookTextTypographyAdjustments = .default,
        normalizedFrame: CGRect,
        on page: MemoryBookPage,
        zIndex: Int,
        field: MemoryBookTextField
    ) -> MemoryBookTextDraftValidation {
        MemoryBookTextDraftValidation(
            characterLimit: field.characterLimit,
            characterCount: text.count,
            measurement: textLayout(text: text, style: style, fontScale: fontScale, typography: typography, normalizedFrame: normalizedFrame, on: page, zIndex: zIndex, field: field).measurement
        )
    }

    /// Old `MemoryBookElement` records did not include an editable field role.
    /// This non-destructive migration assigns only roles that can be established
    /// from the page's title/subtitle template; any remaining user text survives
    /// as `legacyUserNote`. B2 will persist this normalized result after a user
    /// opens the editor, and C will include it in full repository migration.
    func migratedLegacyTextFields() -> MemoryBookDocument {
        var copy = self
        copy.migrateLegacyTextFields()
        return copy
    }

    mutating func migrateLegacyTextFields() {
        for pageIndex in pages.indices {
            let page = pages[pageIndex]
            var primaryAssigned = false
            var secondaryAssigned = false
            for elementIndex in pages[pageIndex].elements.indices where pages[pageIndex].elements[elementIndex].kind == .text {
                guard pages[pageIndex].elements[elementIndex].textField == nil else { continue }
                let text = pages[pageIndex].elements[elementIndex].text ?? ""
                let primary = MemoryBookBuilder.primaryTextField(for: page.kind)
                let secondary = MemoryBookBuilder.secondaryTextField(for: page.kind)
                if !primaryAssigned, let primary, text == page.title {
                    pages[pageIndex].elements[elementIndex].textField = primary
                    primaryAssigned = true
                } else if !secondaryAssigned, let secondary, text == page.subtitle {
                    pages[pageIndex].elements[elementIndex].textField = secondary
                    secondaryAssigned = true
                } else if pages[pageIndex].elements[elementIndex].origin == .user, page.kind != .contents {
                    pages[pageIndex].elements[elementIndex].textField = .legacyUserNote
                }
            }
        }
    }

    func editableTextFields(on page: MemoryBookPage) -> [MemoryBookTextField] {
        MemoryBookTextField.allowed(on: page.kind)
    }

    func layoutChangeSummary(pageID: UUID, layout: MemoryBookLayout) -> MemoryBookLayoutChangeSummary? {
        guard let page = pages.first(where: { $0.id == pageID }),
              !page.isLocked,
              page.kind == .photoSelection,
              page.layout.canonical != .note else { return nil }
        let images = page.elements.filter { $0.kind == .image && $0.assetID != nil }
        let lockedCount = images.filter(\.isLayoutLocked).count
        let unlockedCount = images.count - lockedCount
        let capacity = layout.canonical.photoCapacity
        // A locked image is a user-owned piece of geometry. It remains on the
        // source page even when that means the requested template has no free
        // automatic slots left.
        let retained = lockedCount + min(unlockedCount, max(0, capacity - lockedCount))
        let moved = max(0, unlockedCount - max(0, capacity - lockedCount))
        // A Note page has no image slots, so all unlocked photos are moved to
        // ordinary 3×2 photo pages. The summary must use this same migration
        // capacity as applyLayoutChange rather than claiming one page for every
        // Note conversion.
        let migrationCapacity = layout.canonical == .note ? MemoryBookLayout.grid3x2.photoCapacity : capacity
        let pagesNeeded = moved == 0 ? 0 : Int(ceil(Double(moved) / Double(migrationCapacity)))
        return MemoryBookLayoutChangeSummary(pageID: pageID, layout: layout.canonical, retainedPhotoCount: retained, movedPhotoCount: moved, newPageCount: pagesNeeded, lockedPhotoCount: lockedCount)
    }

    mutating func applyLayoutChange(pageID: UUID, layout: MemoryBookLayout) -> MemoryBookLayoutChangeSummary? {
        guard let index = pages.firstIndex(where: { $0.id == pageID }),
              let summary = layoutChangeSummary(pageID: pageID, layout: layout) else { return nil }
        let canonical = layout.canonical
        let original = pages[index]
        let imageElements = original.elements.filter { $0.kind == .image && $0.assetID != nil }
        let lockedImages = imageElements.filter(\.isLayoutLocked)
        let unlockedImages = imageElements.filter { !$0.isLayoutLocked }
        let availableAutomaticSlots = max(0, canonical.photoCapacity - lockedImages.count)
        let retainedUnlocked = Array(unlockedImages.prefix(availableAutomaticSlots))
        let overflowImages = Array(unlockedImages.dropFirst(retainedUnlocked.count))
        let overflowIDs = overflowImages.compactMap(\.assetID)
        let retainedAssetIDs = Set((lockedImages + retainedUnlocked).compactMap(\.assetID))
        let retainedIDs = imageElements.compactMap(\.assetID).filter { retainedAssetIDs.contains($0) }
        var updated = original
        updated.layout = canonical
        updated.photoIDs = retainedIDs
        let retainedText = original.elements.filter { $0.kind == .text }
        // Preserve the complete locked element, not only its asset identifier:
        // frame, crop, rotation and z-index are all intentional user edits.
        let automatic = MemoryBookBuilder.elements(kind: updated.kind, title: updated.title, subtitle: updated.subtitle, photos: retainedUnlocked.compactMap(\.assetID), layout: canonical)
            .filter { $0.kind == .image }
        updated.elements = retainedText + lockedImages + automatic
        pages[index] = updated

        if !overflowIDs.isEmpty {
            let migrationLayout: MemoryBookLayout = canonical == .note ? .grid3x2 : canonical
            let migrationCapacity = max(1, migrationLayout.photoCapacity)
            let chunks = stride(from: 0, to: overflowImages.count, by: migrationCapacity).map { offset in
                Array(overflowImages[offset..<min(offset + migrationCapacity, overflowImages.count)])
            }
            let created = chunks.enumerated().map { offset, images in
                let ids = images.compactMap(\.assetID)
                // User-positioned image elements travel as the original
                // element instance; automatic images are reflowed for the new
                // template. This preserves crop/rotation/layer/user geometry
                // without leaving a generated duplicate behind.
                let preserved = images.filter { $0.origin == .user || $0.isLayoutLocked }
                let generatedIDs = images.filter { !($0.origin == .user || $0.isLayoutLocked) }.compactMap(\.assetID)
                let generated = MemoryBookBuilder.elements(kind: .photoSelection, title: original.title, subtitle: original.subtitle, photos: generatedIDs, layout: migrationLayout)
                    .filter { $0.kind == .image }
                return MemoryBookPage(kind: .photoSelection, title: original.title, subtitle: original.subtitle, chapterID: original.chapterID, photoIDs: ids, layout: migrationLayout, pageNumber: index + offset + 2, elements: preserved + generated)
            }
            pages.insert(contentsOf: created, at: index + 1)
        }
        renumberPages()
        return summary
    }

    mutating func fitText(pageID: UUID, elementID: UUID) -> Bool {
        guard let pageIndex = pages.firstIndex(where: { $0.id == pageID }),
              let elementIndex = pages[pageIndex].elements.firstIndex(where: { $0.id == elementID && $0.kind == .text }) else { return false }
        var element = pages[pageIndex].elements[elementIndex]
        let styles: [MemoryBookTextStyle]
        switch element.textStyle {
        case .large: styles = [.standard, .small]
        case .standard: styles = [.small]
        case .small: styles = []
        }
        for style in styles {
            element.textStyle = style
            pages[pageIndex].elements[elementIndex] = element
            if textMeasurement(for: element, on: pages[pageIndex])?.overflows == false {
                updatedAt = .now
                return true
            }
        }
        // Fit text is intentionally typography-only. A text frame may be
        // carefully placed against a photo; silently enlarging it violates the
        // editor contract and can cover another element.
        return false
    }

    /// Applies the same no-blank crop invariant used by the crop canvas. The
    /// crop view keeps a local draft until Done, then commits through this
    /// method; Cancel therefore cannot modify the persisted book.
    @discardableResult
    mutating func applyCrop(pageID: UUID, elementID: UUID, scale: CGFloat, offset: CGSize, sourceAspect: CGFloat? = nil) -> Bool {
        guard let pageIndex = pages.firstIndex(where: { $0.id == pageID }),
              let elementIndex = pages[pageIndex].elements.firstIndex(where: { $0.id == elementID && $0.kind == .image }) else { return false }
        let element = pages[pageIndex].elements[elementIndex]
        let aspect = sourceAspect ?? element.assetID.flatMap { id in photos.first(where: { $0.id == id })?.aspectRatio } ?? 1
        let constraint = FillCropConstraint(
            sourceAspect: aspect,
            containerAspect: element.normalizedFrame.width / max(0.01, element.normalizedFrame.height),
            rotationDegrees: element.rotationDegrees + element.imageTransformAdjustments.straightenDegrees
        )
        let transform = constraint.normalized(scale: scale, offset: offset)
        pages[pageIndex].elements[elementIndex].cropScale = transform.scale
        pages[pageIndex].elements[elementIndex].cropOffset = transform.offset
        pages[pageIndex].elements[elementIndex].isLayoutLocked = true
        pages[pageIndex].elements[elementIndex].origin = .user
        updatedAt = .now
        return true
    }

    mutating func apply(layout: MemoryBookLayout, to pageID: UUID) {
        _ = applyLayoutChange(pageID: pageID, layout: layout)
    }

    mutating func autoArrange(pageIDs: Set<UUID>) {
        for index in pages.indices where pageIDs.contains(pages[index].id) && !pages[index].isLocked && pages[index].kind == .photoSelection && pages[index].layout.canonical != .note {
            let page = pages[index]
            let unlockedImages = page.elements.filter { $0.kind == .image && !$0.isLayoutLocked }.compactMap(\.assetID)
            if !unlockedImages.isEmpty {
                let retained = page.elements.filter { $0.kind == .text || $0.isLayoutLocked || $0.origin == .user }
                let automaticImages = MemoryBookBuilder.elements(kind: page.kind, title: page.title, subtitle: page.subtitle, photos: unlockedImages, layout: page.layout)
                    .filter { $0.kind == .image }
                pages[index].elements = retained + automaticImages
            }
        }
        updatedAt = .now
    }

    /// Applies a coordinated look only to eligible pages. Element geometry,
    /// custom backgrounds and every locked page stay byte-for-byte unchanged;
    /// callers can therefore offer page/chapter scope as one safe Undo step.
    @discardableResult
    mutating func applyStyleOverride(_ style: AlbumStyle?, to pageIDs: Set<UUID>) -> Int {
        var changed = 0
        for index in pages.indices where pageIDs.contains(pages[index].id) && !pages[index].isLocked && pages[index].styleOverride != style {
            pages[index].styleOverride = style
            changed += 1
        }
        if changed > 0 { updatedAt = .now }
        return changed
    }

    /// Applies a conservative first crop only to untouched automatic images.
    /// User geometry and crop decisions are never recalculated when metadata
    /// changes or when a document is reopened.
    @discardableResult
    mutating func applyAutomaticFocalCrops() -> Int {
        var changed = 0
        let photosByID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        let paperSize = MemoryBookPageRenderPlan.points(for: pageSize)
        for pageIndex in pages.indices {
            for elementIndex in pages[pageIndex].elements.indices {
                let element = pages[pageIndex].elements[elementIndex]
                guard element.kind == .image,
                      element.origin == .automatic,
                      element.imageContentMode == .fill,
                      element.cropScale == 1,
                      element.cropOffset == .zero,
                      element.rotationDegrees == 0,
                      element.imageTransformAdjustments == .default,
                      let assetID = element.assetID,
                      let photo = photosByID[assetID],
                      let subjectRegion = photo.subjectRegion else { continue }
                let frame = element.normalizedFrame
                let offset = FocalCropPolicy.recommendedOffset(
                    subjectRegion: subjectRegion,
                    sourceAspect: photo.aspectRatio,
                    // `normalizedFrame` is expressed in page fractions, not
                    // square pixels. Include the selected paper's physical
                    // aspect so the initial crop matches Editor/Reader/PDF.
                    containerAspect: (frame.width * paperSize.width) / max(0.01, frame.height * paperSize.height)
                )
                guard abs(offset.width) > 0.0001 || abs(offset.height) > 0.0001 else { continue }
                pages[pageIndex].elements[elementIndex].cropOffset = offset
                changed += 1
            }
        }
        if changed > 0 { updatedAt = .now }
        return changed
    }

    /// The app supplies the same predicate used by the canvas and exporter.
    /// The default keeps model-only tests independent of a real Photos library.
    func checkBook(assetIsAvailable: (ArchivePhoto) -> Bool = { _ in true }) -> [MemoryBookIssue] {
        // Book Check must inspect the same migrated text roles that Preview and
        // PDF render. Otherwise a legacy caption can look editable on canvas
        // yet evade the character-limit and overflow blocker path.
        let document = migratedLegacyTextFields()
        var issues: [MemoryBookIssue] = []
        let validIDs = Set(document.eligiblePhotos.map(\.id))
        var placements = [UUID: [UUID]]()
        for page in document.pages {
            let plan = MemoryBookPageRenderPlan(
                page: page,
                document: document,
                pageSize: MemoryBookPageRenderPlan.points(for: document.pageSize)
            )
            for element in page.elements where element.kind == .image && !element.isHidden {
                if let assetID = element.assetID,
                   let photo = document.photos.first(where: { $0.id == assetID }),
                   (!validIDs.contains(assetID) || !assetIsAvailable(photo)) {
                    issues.append(MemoryBookIssue(severity: .blocking, pageID: page.id, elementID: element.id, message: "A photo is no longer available. Replace it before export."))
                } else if let assetID = element.assetID, !validIDs.contains(assetID) {
                    issues.append(MemoryBookIssue(severity: .blocking, pageID: page.id, elementID: element.id, message: "A photo is no longer available. Replace it before export."))
                }
                if let assetID = element.assetID,
                   let photo = document.photos.first(where: { $0.id == assetID }),
                   let ppi = MemoryBookPrintQuality.effectivePPI(
                    container: plan.rect(for: element.normalizedFrame),
                    photo: photo,
                    element: element
                   ), ppi < MemoryBookPrintQuality.preferredPPI {
                    let rounded = Int(ppi.rounded())
                    let message = "This photo provides about \(rounded) PPI at its current print size. Use a higher-resolution photo or make the frame smaller for a sharper print."
                    issues.append(MemoryBookIssue(
                        severity: ppi < MemoryBookPrintQuality.minimumPPI ? .blocking : .suggestion,
                        pageID: page.id,
                        elementID: element.id,
                        message: message
                    ))
                }
                if element.origin == .automatic,
                   element.imageContentMode == .fill,
                   element.cropScale == 1,
                   element.cropOffset == .zero,
                   element.imageTransformAdjustments == .default,
                   let assetID = element.assetID,
                   let photo = document.photos.first(where: { $0.id == assetID }),
                   photo.subjectRegion == nil {
                    let container = plan.rect(for: element.normalizedFrame)
                    let visibleFraction = MemoryBookCropQuality.visibleSourceFraction(
                        sourceAspect: photo.aspectRatio,
                        containerAspect: container.width / max(1, container.height)
                    )
                    if visibleFraction < MemoryBookCropQuality.minimumUnreviewedVisibleFraction {
                        let croppedPercent = Int(((1 - visibleFraction) * 100).rounded())
                        issues.append(MemoryBookIssue(
                            severity: .blocking,
                            pageID: page.id,
                            elementID: element.id,
                            message: "This automatic frame crops about \(croppedPercent)% of the photo and no subject focus is available. Open Crop and confirm the framing before export."
                        ))
                    }
                }
                if let assetID = element.assetID { placements[assetID, default: []].append(page.id) }
            }
            if page.kind == .photoSelection && !page.isLocked && !page.elements.contains(where: { $0.kind == .image && !$0.isHidden }) {
                issues.append(MemoryBookIssue(severity: .suggestion, pageID: page.id, message: "This photo page is empty. Add a photo, keep it as a note page, or remove it."))
            }
            for element in page.elements where element.kind == .text && !element.isHidden {
                if (element.text ?? "").count > document.textCharacterLimit(for: element, on: page) {
                    issues.append(MemoryBookIssue(severity: .blocking, pageID: page.id, elementID: element.id, field: element.textField, message: "Text is longer than this page allows. Shorten it before export."))
                }
                if document.textMeasurement(for: element, on: page)?.overflows == true {
                    issues.append(MemoryBookIssue(severity: .blocking, pageID: page.id, elementID: element.id, field: element.textField, message: "Text overflows its frame. Use Fit text before export."))
                }
                if let readability = document.textReadability(for: element, on: page) {
                    if !readability.isPrintSizeReadable {
                        issues.append(MemoryBookIssue(severity: .blocking, pageID: page.id, elementID: element.id, field: element.textField, message: "Text is too small for reliable print. Increase its size before export."))
                    }
                    let hasAuthoredColorCombination = page.backgroundColor != nil || element.textCustomColor != nil || element.textColor != .ink
                    if !readability.hasSufficientContrast, hasAuthoredColorCombination {
                        issues.append(MemoryBookIssue(
                            severity: .suggestion,
                            pageID: page.id,
                            elementID: element.id,
                            field: element.textField,
                            message: String(format: "Text contrast is low (%.1f:1). Use a clearer color for more readable print.", readability.contrastRatio),
                            repair: element.isInteractionLocked ? nil : .textColor(readability.recommendedForeground)
                        ))
                    }
                }
            }
            issues.append(contentsOf: document.compositionIssues(on: page))
        }
        for (_, pageIDs) in placements.sorted(by: { $0.key.uuidString < $1.key.uuidString }) where pageIDs.count > 1 {
            let uniquePageIDs = Array(Set(pageIDs)).sorted(by: { $0.uuidString < $1.uuidString })
            issues.append(MemoryBookIssue(
                severity: .suggestion,
                pageID: uniquePageIDs.first,
                message: "This photo appears more than once (on \(uniquePageIDs.count) pages). Keep the repetition only if it is intentional."
            ))
        }
        if !document.pages.contains(where: { $0.elements.contains(where: { $0.kind == .image && !$0.isHidden }) }) {
            issues.append(MemoryBookIssue(severity: .blocking, pageID: nil, message: "Add at least one photo before exporting."))
        }
        return issues
    }

    /// Conservative beauty rules: automatic template geometry is trusted and
    /// only user-owned, unlocked layers are candidates for movement. This
    /// avoids turning Book Check into a subjective auto-layout engine while
    /// still catching the common "almost aligned" and uneven-spacing mistakes
    /// created during direct manipulation.
    func compositionIssues(on page: MemoryBookPage) -> [MemoryBookIssue] {
        guard !page.isLocked else { return [] }
        let visible = page.elements.filter { !$0.isHidden }
        let movable = visible.filter { $0.origin == .user && !$0.isInteractionLocked }
        var issues: [MemoryBookIssue] = []

        for element in movable {
            let normalizedRotation = ((element.rotationDegrees + 180).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) - 180
            if abs(normalizedRotation) > 20, element.kind != .shape {
                issues.append(.init(
                    severity: .suggestion,
                    pageID: page.id,
                    elementID: element.id,
                    field: element.textField,
                    message: String(format: "This %@ is rotated %.0f°. Straighten it for a calmer composition, or keep the angle intentionally.", element.kind == .text ? "text" : "photo", abs(normalizedRotation)),
                    repair: .elementRotation(0)
                ))
            }

            let frame = element.normalizedFrame
            let xAnchors = [frame.minX, frame.midX, frame.maxX]
            let yAnchors = [frame.minY, frame.midY, frame.maxY]
            var best: (delta: CGFloat, axis: String)?
            for peer in visible where peer.id != element.id && (element.groupID == nil || peer.groupID != element.groupID) {
                let other = peer.normalizedFrame
                let peerX = [other.minX, other.midX, other.maxX]
                let peerY = [other.minY, other.midY, other.maxY]
                for index in 0..<3 {
                    let dx = peerX[index] - xAnchors[index]
                    if abs(dx) >= 0.004, abs(dx) <= 0.018, best == nil || abs(dx) < abs(best!.delta) { best = (dx, "vertical") }
                    let dy = peerY[index] - yAnchors[index]
                    if abs(dy) >= 0.004, abs(dy) <= 0.018, best == nil || abs(dy) < abs(best!.delta) { best = (dy, "horizontal") }
                }
            }
            if let best {
                var aligned = frame
                if best.axis == "vertical" {
                    aligned.origin.x = min(1 - aligned.width, max(0, aligned.minX + best.delta))
                } else {
                    aligned.origin.y = min(1 - aligned.height, max(0, aligned.minY + best.delta))
                }
                issues.append(.init(
                    severity: .suggestion,
                    pageID: page.id,
                    elementID: element.id,
                    field: element.textField,
                    message: "This layer is almost aligned with a nearby layer. Snap it onto the shared \(best.axis) guide for a cleaner edge.",
                    repair: .elementFrames([.init(elementID: element.id, frame: aligned)])
                ))
            }
        }

        let protected = visible.filter { $0.origin == .user && $0.isInteractionLocked }
        if let spacingIssue = spacingIssue(on: page, elements: movable, protectedElements: protected, horizontally: true) { issues.append(spacingIssue) }
        if let spacingIssue = spacingIssue(on: page, elements: movable, protectedElements: protected, horizontally: false) { issues.append(spacingIssue) }
        if let balanceIssue = whitespaceBalanceIssue(on: page, visibleElements: visible) { issues.append(balanceIssue) }
        issues.append(contentsOf: captionRelationshipIssues(on: page, visibleElements: visible))
        return issues
    }

    /// Only a fully user-authored, unlocked content group is eligible for an
    /// automatic balance repair. Mixed template/user pages can be intentionally
    /// asymmetric, so Book Check leaves them alone instead of second-guessing
    /// the selected design system.
    private func whitespaceBalanceIssue(on page: MemoryBookPage, visibleElements: [MemoryBookElement]) -> MemoryBookIssue? {
        let content = visibleElements.filter {
            ($0.kind == .image || ($0.kind == .text && !($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        }
        guard content.count >= 2,
              content.allSatisfy({ $0.origin == .user && !$0.isInteractionLocked }) else { return nil }
        let union = content.dropFirst().reduce(content[0].normalizedFrame) { $0.union($1.normalizedFrame) }
        guard union.width * union.height < 0.58 else { return nil }
        let rawDX = 0.5 - union.midX
        let rawDY = 0.5 - union.midY
        guard abs(rawDX) > 0.16 || abs(rawDY) > 0.16 else { return nil }
        let dx = min(0.94 - union.maxX, max(0.06 - union.minX, rawDX))
        let dy = min(0.94 - union.maxY, max(0.06 - union.minY, rawDY))
        guard abs(dx) > 0.04 || abs(dy) > 0.04 else { return nil }
        let repairs = content.map { element -> MemoryBookElementFrameRepair in
            var frame = element.normalizedFrame
            frame.origin.x += dx
            frame.origin.y += dy
            return .init(elementID: element.id, frame: frame)
        }
        let horizontal = rawDX > 0.16 ? "left" : rawDX < -0.16 ? "right" : nil
        let vertical = rawDY > 0.16 ? "top" : rawDY < -0.16 ? "bottom" : nil
        let direction = [horizontal, vertical].compactMap { $0 }.joined(separator: " and ")
        return .init(
            severity: .suggestion,
            pageID: page.id,
            elementID: content[0].id,
            field: content[0].textField,
            message: "The authored content is weighted toward the \(direction) edge, leaving accidental-looking whitespace. Rebalance the group while preserving its internal layout.",
            repair: .recenterElementFrames(repairs)
        )
    }

    private func captionRelationshipIssues(on page: MemoryBookPage, visibleElements: [MemoryBookElement]) -> [MemoryBookIssue] {
        let photos = visibleElements.filter { $0.kind == .image }
        return visibleElements.compactMap { caption in
            guard caption.kind == .text,
                  caption.textField == .photoCaption,
                  caption.origin == .user,
                  !(caption.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            guard !photos.isEmpty else {
                return .init(
                    severity: .suggestion,
                    pageID: page.id,
                    elementID: caption.id,
                    field: caption.textField,
                    message: "This caption has no photo on the page. Add a photo, convert it to a note, or remove the caption."
                )
            }
            let distance = photos.map { photo -> CGFloat in
                let dx = max(0, max(photo.normalizedFrame.minX - caption.normalizedFrame.maxX, caption.normalizedFrame.minX - photo.normalizedFrame.maxX))
                let dy = max(0, max(photo.normalizedFrame.minY - caption.normalizedFrame.maxY, caption.normalizedFrame.minY - photo.normalizedFrame.maxY))
                return hypot(dx, dy)
            }.min() ?? 0
            guard distance > 0.18 else { return nil }
            return .init(
                severity: .suggestion,
                pageID: page.id,
                elementID: caption.id,
                field: caption.textField,
                message: "This caption is visually detached from every photo. Move it closer to the image it describes."
            )
        }
    }

    private func spacingIssue(on page: MemoryBookPage, elements: [MemoryBookElement], protectedElements: [MemoryBookElement], horizontally: Bool) -> MemoryBookIssue? {
        guard elements.count >= 3 else { return nil }
        let sorted = elements.sorted {
            horizontally ? $0.normalizedFrame.minX < $1.normalizedFrame.minX : $0.normalizedFrame.minY < $1.normalizedFrame.minY
        }
        let crossCenters = sorted.map { horizontally ? $0.normalizedFrame.midY : $0.normalizedFrame.midX }
        guard (crossCenters.max() ?? 0) - (crossCenters.min() ?? 0) <= 0.045 else { return nil }
        let rowCrossMin = (crossCenters.min() ?? 0) - 0.045
        let rowCrossMax = (crossCenters.max() ?? 0) + 0.045
        let rowMainMin = horizontally ? sorted[0].normalizedFrame.minX : sorted[0].normalizedFrame.minY
        let rowMainMax = horizontally ? sorted[sorted.count - 1].normalizedFrame.maxX : sorted[sorted.count - 1].normalizedFrame.maxY
        let containsProtectedLayer = protectedElements.contains { element in
            let frame = element.normalizedFrame
            let crossCenter = horizontally ? frame.midY : frame.midX
            let mainMin = horizontally ? frame.minX : frame.minY
            let mainMax = horizontally ? frame.maxX : frame.maxY
            return crossCenter >= rowCrossMin && crossCenter <= rowCrossMax && mainMax >= rowMainMin && mainMin <= rowMainMax
        }
        guard !containsProtectedLayer else { return nil }
        let gaps = zip(sorted, sorted.dropFirst()).map { lhs, rhs in
            horizontally ? rhs.normalizedFrame.minX - lhs.normalizedFrame.maxX : rhs.normalizedFrame.minY - lhs.normalizedFrame.maxY
        }
        guard gaps.allSatisfy({ $0 > 0.005 }), let minimum = gaps.min(), let maximum = gaps.max(), maximum - minimum > 0.025 else { return nil }
        let first = sorted[0].normalizedFrame
        let last = sorted[sorted.count - 1].normalizedFrame
        let occupied = sorted.reduce(CGFloat.zero) { $0 + (horizontally ? $1.normalizedFrame.width : $1.normalizedFrame.height) }
        let span = horizontally ? last.maxX - first.minX : last.maxY - first.minY
        let equalGap = max(0.005, (span - occupied) / CGFloat(sorted.count - 1))
        var cursor = horizontally ? first.minX : first.minY
        let repairs = sorted.map { element -> MemoryBookElementFrameRepair in
            var frame = element.normalizedFrame
            if horizontally { frame.origin.x = cursor; cursor += frame.width + equalGap }
            else { frame.origin.y = cursor; cursor += frame.height + equalGap }
            return .init(elementID: element.id, frame: frame)
        }
        return .init(
            severity: .suggestion,
            pageID: page.id,
            elementID: sorted[1].id,
            message: "These \(sorted.count) layers have uneven \(horizontally ? "horizontal" : "vertical") spacing. Distribute them evenly for a steadier rhythm.",
            repair: .elementFrames(repairs)
        )
    }

    @discardableResult
    mutating func applyBookCheckRepair(_ issue: MemoryBookIssue) -> Bool {
        guard let pageID = issue.pageID,
              let pageIndex = pages.firstIndex(where: { $0.id == pageID }),
              let repair = issue.repair else { return false }
        switch repair {
        case .elementFrames(let repairs), .recenterElementFrames(let repairs):
            guard repairs.allSatisfy({ repair in pages[pageIndex].elements.contains(where: { $0.id == repair.elementID && !$0.isInteractionLocked }) }) else { return false }
            for repair in repairs {
                guard let index = pages[pageIndex].elements.firstIndex(where: { $0.id == repair.elementID }) else { continue }
                pages[pageIndex].elements[index].normalizedFrame = repair.frame
                pages[pageIndex].elements[index].isLayoutLocked = true
                pages[pageIndex].elements[index].origin = .user
                pages[pageIndex].elements[index].updatedAt = .now
            }
        case .elementRotation(let value):
            guard let elementID = issue.elementID,
                  let index = pages[pageIndex].elements.firstIndex(where: { $0.id == elementID && !$0.isInteractionLocked }) else { return false }
            pages[pageIndex].elements[index].rotationDegrees = value
            pages[pageIndex].elements[index].isLayoutLocked = true
            pages[pageIndex].elements[index].origin = .user
            pages[pageIndex].elements[index].updatedAt = .now
        case .textColor(let value):
            guard let elementID = issue.elementID,
                  let index = pages[pageIndex].elements.firstIndex(where: { $0.id == elementID && $0.kind == .text && !$0.isInteractionLocked }) else { return false }
            pages[pageIndex].elements[index].textCustomColor = value
            pages[pageIndex].elements[index].origin = .user
            pages[pageIndex].elements[index].updatedAt = .now
        }
        updatedAt = .now
        return true
    }

    mutating func movePage(from source: Int, to destination: Int) {
        guard pages.indices.contains(source), pages.indices.contains(destination), source != destination else { return }
        let page = pages.remove(at: source)
        pages.insert(page, at: destination)
        renumberPages()
    }

    mutating func duplicatePage(id: UUID) -> UUID? {
        guard let index = pages.firstIndex(where: { $0.id == id }), !pages[index].isLocked else { return nil }
        var duplicate = pages[index]
        duplicate.id = UUID()
        duplicate.pageNumber = index + 2
        var groupMap: [UUID: UUID] = [:]
        duplicate.elements = duplicate.elements.map { element in
            var copy = element
            copy.id = UUID()
            if let groupID = copy.groupID {
                copy.groupID = groupMap[groupID, default: UUID()]
                groupMap[groupID] = copy.groupID
            }
            copy.updatedAt = .now
            return copy
        }
        pages.insert(duplicate, at: index + 1)
        renumberPages()
        return duplicate.id
    }

    /// Production replacement operation.  The user owns the composition
    /// frame, rotation and stacking order; a replacement only swaps the asset
    /// and starts a legal crop state for the new source.
    @discardableResult
    mutating func replacePhoto(pageID: UUID, elementID: UUID, with photoID: UUID) -> Bool {
        guard let pageIndex = pages.firstIndex(where: { $0.id == pageID }),
              let elementIndex = pages[pageIndex].elements.firstIndex(where: { $0.id == elementID }),
              let replacement = photos.first(where: { $0.id == photoID }) else { return false }
        var element = pages[pageIndex].elements[elementIndex]
        guard element.kind == .image else { return false }
        element.assetID = photoID
        // Finishing values describe the source photograph, unlike the frame,
        // mask and border which describe the composition slot.
        element.imageAdjustments = .default
        element.imageTransformAdjustments = .default
        if element.imageContentMode == .fit {
            element.cropScale = 1
            element.cropOffset = .zero
        } else {
            let constraint = FillCropConstraint(
                sourceAspect: replacement.aspectRatio,
                containerAspect: element.normalizedFrame.width / max(0.01, element.normalizedFrame.height),
                rotationDegrees: element.rotationDegrees
            )
            let normalized = constraint.normalized(scale: 1, offset: .zero)
            element.cropScale = normalized.scale
            element.cropOffset = normalized.offset
        }
        element.updatedAt = .now
        pages[pageIndex].elements[elementIndex] = element
        _ = normalizeFitImageFramesToAssetAspect()
        if !pages[pageIndex].photoIDs.contains(photoID) { pages[pageIndex].photoIDs.append(photoID) }
        updatedAt = .now
        return true
    }
}

/// A crop sheet cannot silently disappear while it owns an uncommitted draft.
/// The UI maps this state to Keep editing / Save and leave / Discard, including
/// a scene becoming inactive in the middle of a gesture.
enum MemoryBookCropExitPolicy: Equatable, Sendable {
    case dismissImmediately
    case requireDecision

    static func policy(hasDraft: Bool) -> MemoryBookCropExitPolicy {
        hasDraft ? .requireDecision : .dismissImmediately
    }
}

/// Exit sources are intentionally modelled rather than left as ad-hoc view
/// callbacks. A dirty crop draft receives the same explicit decision whether
/// the user taps Cancel, attempts a page change, or backgrounds the app.
enum MemoryBookCropExitSource: CaseIterable, Equatable, Sendable {
    case cancel
    case pageChange
    case sceneInactive
}

enum MemoryBookCropExitState: Equatable, Sendable {
    case editing
    case awaitingDecision(MemoryBookCropExitSource)
    case dismissed

    mutating func requestExit(_ source: MemoryBookCropExitSource, hasDraft: Bool) {
        self = hasDraft ? .awaitingDecision(source) : .dismissed
    }

    mutating func keepEditing() {
        if case .awaitingDecision = self { self = .editing }
    }
}

enum MemoryBookBuilder {
    static func optionalTextFields(for kind: MemoryBookPageKind) -> [MemoryBookTextField] {
        switch kind {
        case .chapterOpener: [.chapterNote]
        case .photoSelection: [.photoCaption]
        case .milestone: [.milestoneNote]
        default: []
        }
    }

    static func defaultTextFrame(for field: MemoryBookTextField) -> CGRect {
        switch field {
        case .photoCaption: CGRect(x: 0.10, y: 0.73, width: 0.72, height: 0.10)
        case .chapterNote, .milestoneNote: CGRect(x: 0.10, y: 0.64, width: 0.72, height: 0.14)
        default: CGRect(x: 0.10, y: 0.60, width: 0.72, height: 0.12)
        }
    }

    static func primaryTextField(for kind: MemoryBookPageKind) -> MemoryBookTextField? {
        switch kind {
        case .cover: .coverPetName
        case .dedication: .dedicationMessage
        case .contents: nil
        case .chapterOpener: .chapterTitle
        case .photoSelection: .photoTitle
        case .milestone: .milestoneDate
        case .closing: .closingMessage
        }
    }

    static func secondaryTextField(for kind: MemoryBookPageKind) -> MemoryBookTextField? {
        switch kind {
        case .cover: .coverSubtitle
        case .dedication, .contents, .closing: nil
        case .chapterOpener: .chapterDateRange
        case .photoSelection: .photoCaption
        case .milestone: .milestoneNote
        }
    }

    static func elements(kind: MemoryBookPageKind, title: String, subtitle: String, photos: [UUID], layout: MemoryBookLayout) -> [MemoryBookElement] {
        var result = [MemoryBookElement(kind: .text, text: title, normalizedFrame: CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.10), zIndex: 10, textField: primaryTextField(for: kind))]
        if !subtitle.isEmpty { result.append(MemoryBookElement(kind: .text, text: subtitle, normalizedFrame: CGRect(x: 0.08, y: 0.17, width: 0.84, height: 0.06), zIndex: 9, textField: secondaryTextField(for: kind))) }
        guard !photos.isEmpty else { return result }
        if kind == .cover || kind == .chapterOpener || kind == .milestone {
            result.append(MemoryBookElement(kind: .image, assetID: photos[0], normalizedFrame: CGRect(x: 0.08, y: 0.27, width: 0.84, height: 0.40)))
        } else if kind == .photoSelection, layout != .note {
            let columns: Int
            switch layout.canonical {
            case .single: columns = 1
            case .diptych: columns = 2
            case .grid2x2: columns = 2
            case .grid3x2, .mosaic: columns = 3
            case .note: columns = 1
            }
            let gap: CGFloat = 0.02
            let width = (0.84 - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let rows = max(1, Int(ceil(Double(photos.count) / Double(columns))))
            let height = min(0.40, (0.48 - gap * CGFloat(rows - 1)) / CGFloat(rows))
            for (index, photo) in photos.prefix(layout.photoCapacity).enumerated() {
                let row = index / columns; let column = index % columns
                result.append(MemoryBookElement(kind: .image, assetID: photo, normalizedFrame: CGRect(x: 0.08 + CGFloat(column) * (width + gap), y: 0.27 + CGFloat(row) * (height + gap), width: width, height: height)))
            }
        }
        return result
    }

    static func build(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], style: AlbumStyle, pageSize: PDFPageSize) -> MemoryBookDocument {
        let eligibleIDs = Set(photos.filter(\.isEligibleForArchive).map(\.id))
        let visible = chapters.filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }.map { chapter -> Chapter in
            var copy = chapter
            copy.photoIDs = chapter.photoIDs.filter { eligibleIDs.contains($0) }
            return copy
        }
        var pages: [MemoryBookPage] = []
        func append(_ kind: MemoryBookPageKind, _ title: String, _ subtitle: String = "", chapter: Chapter? = nil, photos: [UUID] = [], layout: MemoryBookLayout = .note) {
            let pageElements = MemoryBookBuilder.elements(kind: kind, title: title, subtitle: subtitle, photos: photos, layout: layout)
            let structural = kind == .cover || kind == .dedication || kind == .contents || kind == .chapterOpener || kind == .closing
            pages.append(MemoryBookPage(kind: kind, title: title, subtitle: subtitle, chapterID: chapter?.id, photoIDs: photos, layout: layout, pageNumber: pages.count + 1, elements: pageElements, isLocked: structural))
        }
        let coverPhoto = photos.first(where: { $0.isEligibleForArchive }).map(\.id)
        append(.cover, profile.name, "A life in moments", photos: coverPhoto.map { [$0] } ?? [], layout: .single)
        append(.dedication, "For \(profile.name)", "Made privately from the photographs you chose.")
        append(.contents, "Contents", visible.map(\.dateLabel).joined(separator: "  ·  "))
        for chapter in visible {
            let photos = chapter.photoIDs
            append(.chapterOpener, chapter.title, "\(chapter.dateLabel) · A season together", chapter: chapter, photos: Array(photos.prefix(1)), layout: .single)
            // Keep every user-approved photograph. Pages are chunked so a large
            // chapter remains printable instead of silently truncating at six.
            let chunks = stride(from: 0, to: photos.count, by: 6).map { Array(photos[$0..<min($0 + 6, photos.count)]) }
            for chunk in chunks {
                let layout: MemoryBookLayout = switch chunk.count {
                case 0...1: .single
                case 2: .diptych
                case 4: .grid2x2
                default: .grid3x2
                }
                append(.photoSelection, chapter.title, chapter.note.isEmpty ? "Selected moments from \(chapter.dateLabel)." : chapter.note, chapter: chapter, photos: chunk, layout: layout)
            }
        }
        if let arrivalYear = profile.arrivalYear,
           let milestone = visible.flatMap(\.photoIDs).first(where: { id in photos.first(where: { $0.id == id })?.createdAt.map { Calendar.current.component(.year, from: $0) == arrivalYear } ?? false }) {
            append(.milestone, "A year we remember", "A quiet marker from \(arrivalYear).", photos: [milestone], layout: .single)
        }
        append(.closing, "Kept with care.", "Tailor never changes your original photos.")
        var document = MemoryBookDocument(profile: profile, photos: photos, chapters: visible, pages: pages, style: style, pageSize: pageSize)
        document.applyAutomaticFocalCrops()
        return document
    }
}

struct ScanProgress: Codable, Equatable, Sendable { var completedAssets: Int; var totalAssets: Int }
/// Local-only aggregate scan diagnostics. No photo identifiers, names, image
/// data, feature vectors, or text leave the device through this structure.
struct ScanAuditMetrics: Codable, Equatable, Sendable {
    var processed = 0
    var referenceFailures = 0
    var imageUnavailable = 0
    var animalVisionFailures = 0
    var speciesRejected = 0
    var identityRejected = 0
    var candidates = 0
    var needsReview = 0
    var autoSelected = 0
    var duplicateGrouped = 0
    var duplicateSuppressed = 0
    var lowPower = 0
    var thermal = 0
    var interrupted = 0
}
struct ScanCheckpoint: Codable, Equatable, Sendable {
    var nextAssetIndex: Int
    var totalAssets: Int
    var candidates: [ArchivePhoto]
    /// Hash of the ordered, in-scope PHAsset local identifiers. Resuming by a
    /// count alone is unsafe: a user can add/delete photos without changing it.
    var assetCatalogFingerprint: String?
    var auditMetrics: ScanAuditMetrics
    /// Locally persisted scan coverage. A completed archive uses this to
    /// compare a later explicit refresh against only new Photos assets.
    var processedAssetIdentifiers: [String]

    init(nextAssetIndex: Int, totalAssets: Int, candidates: [ArchivePhoto], assetCatalogFingerprint: String? = nil, auditMetrics: ScanAuditMetrics = .init(), processedAssetIdentifiers: [String] = []) {
        self.nextAssetIndex = nextAssetIndex
        self.totalAssets = totalAssets
        self.candidates = candidates
        self.assetCatalogFingerprint = assetCatalogFingerprint
        self.auditMetrics = auditMetrics
        self.processedAssetIdentifiers = processedAssetIdentifiers
    }

    var progress: ScanProgress { ScanProgress(completedAssets: nextAssetIndex, totalAssets: totalAssets) }

    private enum CodingKeys: String, CodingKey { case nextAssetIndex, totalAssets, candidates, assetCatalogFingerprint, auditMetrics, processedAssetIdentifiers }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        nextAssetIndex = try values.decode(Int.self, forKey: .nextAssetIndex)
        totalAssets = try values.decode(Int.self, forKey: .totalAssets)
        candidates = try values.decode([ArchivePhoto].self, forKey: .candidates)
        assetCatalogFingerprint = try values.decodeIfPresent(String.self, forKey: .assetCatalogFingerprint)
        auditMetrics = try values.decodeIfPresent(ScanAuditMetrics.self, forKey: .auditMetrics) ?? .init()
        processedAssetIdentifiers = try values.decodeIfPresent([String].self, forKey: .processedAssetIdentifiers) ?? []
    }
}

/// Keeps a rescan additive. Matching metadata may improve, but the user's
/// choices, chapter membership, editable book and export history never become
/// collateral damage of a library refresh.
enum ScanArchiveMergePolicy {
    static func checkpointForIncrementalRescan(document: ArchiveDocument) -> ScanCheckpoint {
        ScanCheckpoint(nextAssetIndex: 0, totalAssets: 0, candidates: document.photos)
    }

    static func mergedPhotos(existing: [ArchivePhoto], scanned: [ArchivePhoto]) -> [ArchivePhoto] {
        let existingByIdentifier = Dictionary(uniqueKeysWithValues: existing.map { ($0.assetLocalIdentifier, $0) })
        var result = existing
        var knownIdentifiers = Set(existing.map(\.assetLocalIdentifier))
        for candidate in scanned {
            if let preserved = existingByIdentifier[candidate.assetLocalIdentifier],
               let index = result.firstIndex(where: { $0.id == preserved.id }) {
                // Keep explicit decisions and the stable UUID referenced by
                // chapters/editor pages, while refreshing scanner metadata.
                var merged = candidate
                merged.id = preserved.id
                merged.decision = preserved.decision
                merged.sensitivityState = preserved.sensitivityState
                merged.excludedReason = preserved.excludedReason
                merged.visualHash = candidate.visualHash ?? preserved.visualHash
                merged.subjectRegion = candidate.subjectRegion ?? preserved.subjectRegion
                result[index] = merged
            } else if knownIdentifiers.insert(candidate.assetLocalIdentifier).inserted {
                result.append(candidate)
            }
        }
        return result.sorted {
            if $0.createdAt != $1.createdAt { return ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
            return $0.assetLocalIdentifier < $1.assetLocalIdentifier
        }
    }

    static func completing(document: ArchiveDocument, profile: PetProfile, scanned: [ArchivePhoto]) -> ArchiveDocument {
        let merged = mergedPhotos(existing: document.photos, scanned: scanned)
        var completedCheckpoint = document.scanCheckpoint
        if completedCheckpoint != nil {
            completedCheckpoint?.candidates = merged
        }
        return ArchiveDocument(
            profile: profile,
            photos: merged,
            chapters: document.chapters,
            // Keep completed local coverage for a future explicit delta scan.
            // Restore only treats a checkpoint as resumable when lifecycle is
            // `.scanning`, so this never reopens a completed archive on the
            // scan screen.
            scanCheckpoint: completedCheckpoint,
            scanAuditMetrics: document.scanCheckpoint?.auditMetrics ?? document.scanAuditMetrics,
            memoryBook: document.memoryBook,
            exportRecords: document.exportRecords,
            updatedAt: .now
        )
    }
}
enum ScanFailure: Error, Equatable, Sendable { case interrupted, unavailable, insufficientAccess, insufficientReferences, lowPower, thermal }
enum ScanState: Equatable, Sendable { case idle, running(ScanProgress), paused(ScanProgress), interrupted(ScanProgress), failed(ScanFailure, ScanProgress?), complete }
enum PurchaseState: Equatable, Sendable { case idle, purchasing, pending, cancelled, failed(String), restored, entitled }
enum ExportState: Equatable, Sendable { case idle, choosingPageSize, rendering(Double), failed(String), complete(URL) }
