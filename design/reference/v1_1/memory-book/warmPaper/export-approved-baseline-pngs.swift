import AppKit
import Foundation

let root = URL(fileURLWithPath: "design/reference/v1_1/memory-book/warmPaper")
let papers: [(name: String, width: Int, height: Int)] = [
    ("letter", 612, 792),
    ("a4", 595, 842)
]
let pages = ["cover", "dedication", "contents", "chapterOpener", "photoSelection", "milestone", "closing"]
let scale = 3

func export(svgURL: URL, pngURL: URL, width: Int, height: Int) throws {
    guard let image = NSImage(contentsOf: svgURL) else {
        throw NSError(domain: "WarmPaperBaselineExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read SVG: \(svgURL.path)"])
    }

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width * scale,
        pixelsHigh: height * scale,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "WarmPaperBaselineExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot allocate bitmap"])
    }

    bitmap.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: CGRect(x: 0, y: 0, width: width, height: height),
               from: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
               operation: .copy,
               fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "WarmPaperBaselineExport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot encode PNG: \(pngURL.path)"])
    }
    try data.write(to: pngURL, options: .atomic)
}

for paper in papers {
    for page in pages {
        let dir = root.appendingPathComponent(paper.name)
        let svgURL = dir.appendingPathComponent("\(page).svg")
        let pngURL = dir.appendingPathComponent("\(page).png")
        try export(svgURL: svgURL, pngURL: pngURL, width: paper.width, height: paper.height)
        print("exported \(pngURL.path)")
    }
}

