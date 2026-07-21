import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 5,
      let width = Int(CommandLine.arguments[3]),
      let height = Int(CommandLine.arguments[4]),
      width > 0,
      height > 0 else {
    FileHandle.standardError.write(Data("usage: render_pdf_exact.swift input.pdf output-directory width height\n".utf8))
    exit(2)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
guard let document = CGPDFDocument(input as CFURL) else {
    throw NSError(domain: "TailorPDFEvidence", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open PDF"])
}

for index in 1...document.numberOfPages {
    guard let page = document.page(at: index) else { continue }
    let media = page.getBoxRect(.mediaBox)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw NSError(domain: "TailorPDFEvidence", code: 2) }
    context.interpolationQuality = .high
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: CGFloat(width) / media.width, y: CGFloat(height) / media.height)
    context.drawPDFPage(page)
    guard let image = context.makeImage() else { throw NSError(domain: "TailorPDFEvidence", code: 3) }
    let destinationURL = output.appendingPathComponent(String(format: "pdf-raster-%02d.png", index))
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "TailorPDFEvidence", code: 4)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "TailorPDFEvidence", code: 5) }
}
