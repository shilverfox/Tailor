import SwiftUI

enum TailorColor {
    static let paper = Color(red: 248 / 255, green: 243 / 255, blue: 232 / 255)
    static let elevated = Color(red: 1, green: 252 / 255, blue: 246 / 255)
    static let ink = Color(red: 24 / 255, green: 58 / 255, blue: 49 / 255)
    static let secondaryInk = Color(red: 100 / 255, green: 117 / 255, blue: 108 / 255)
    static let clay = Color(red: 184 / 255, green: 86 / 255, blue: 57 / 255)
    static let mist = Color(red: 216 / 255, green: 223 / 255, blue: 203 / 255)
    static let line = Color(red: 222 / 255, green: 212 / 255, blue: 193 / 255)
    static let paperDeep = Color(red: 239 / 255, green: 228 / 255, blue: 209 / 255)
}

enum TailorFont {
    static func display(_ size: CGFloat) -> Font { .custom("Iowan Old Style", size: size, relativeTo: .largeTitle) }
}

enum TailorSpacing { static let xs: CGFloat = 8; static let s: CGFloat = 12; static let m: CGFloat = 16; static let l: CGFloat = 24; static let touchTarget: CGFloat = 48 }
