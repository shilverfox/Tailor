import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 4,
      let pixelSize = Int(CommandLine.arguments[3]), pixelSize > 0,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
      let original = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let context = CGContext(data: nil, width: pixelSize, height: pixelSize,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL,
                                                        UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Unable to load or create icon image")
}
context.interpolationQuality = .high
context.draw(original, in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
guard let resized = context.makeImage() else { fatalError("Unable to resize icon") }
CGImageDestinationAddImage(destination, resized, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Unable to write icon") }
