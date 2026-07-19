import AppKit

let root = "/Users/lijian15/iosWork/Tailor"
let baseURL = URL(fileURLWithPath: root + "/design/reference/v1_1/01-welcome-default.png")
let heroURL = URL(fileURLWithPath: root + "/design/assets/01_Welcome_hero.png")
let outputURL = baseURL
guard let base = NSImage(contentsOf: baseURL), let hero = NSImage(contentsOf: heroURL) else { fatalError("Reference image missing") }
let size = NSSize(width: 390, height: 844)
let image = NSImage(size: size)
image.lockFocus()
base.draw(in: NSRect(origin: .zero, size: size))
let target = NSRect(x: 24, y: 353, width: 342, height: 286)
hero.draw(in: target, from: NSRect(origin: .zero, size: hero.size), operation: .sourceOver, fraction: 1)
NSColor(calibratedWhite: 0.1, alpha: 0.35).setFill()
NSBezierPath(rect: NSRect(x: 24, y: 353, width: 342, height: 74)).fill()
let text = "MADE FROM THE MOMENTS YOU ALREADY HAVE" as NSString
let style = NSMutableParagraphStyle(); style.alignment = .left
text.draw(in: NSRect(x: 45, y: 373, width: 300, height: 16), withAttributes: [.font: NSFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: NSColor(calibratedWhite: 1, alpha: 1), .paragraphStyle: style, .kern: 0.8])
image.unlockFocus()
guard let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data), let png = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode PNG") }
try png.write(to: outputURL)
