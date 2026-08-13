//
//  Color+ProjectColors.swift
//  MovieTracker
//

import SwiftUI
import UIKit

extension Color {
    init(red255: Int, green255: Int, blue255: Int) {
        self.init(
            red: Double(red255) / 255.0,
            green: Double(green255) / 255.0,
            blue: Double(blue255) / 255.0
        )
    }

    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, let value = UInt64(digits, radix: 16) else { return nil }
        self.init(
            red255: Int((value >> 16) & 0xFF),
            green255: Int((value >> 8) & 0xFF),
            blue255: Int(value & 0xFF)
        )
    }

    var hexString: String? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255)))
    }

    static let appBackground = Color(red255: 12, green255: 12, blue255: 12)
    static let appSeparator = Color(red255: 35, green255: 35, blue255: 35)
    static let appAccent = Color(red255: 200, green255: 180, blue255: 130)

    static func whiteFaded(_ level: Double = 0.75) -> Color {
        let clamped = (level < 0 || level > 1) ? 0.75 : level
        return Color(red: clamped, green: clamped, blue: clamped)
    }

    static let listPalette: [Color] = [
        Color(red255: 235, green255: 85, blue255: 69),    // red
        Color(red255: 241, green255: 163, blue255: 59),   // orange
        Color(red255: 248, green255: 215, blue255: 74),   // yellow
        Color(red255: 103, green255: 206, blue255: 105),  // green
        Color(red255: 137, green255: 193, blue255: 249),  // light blue
        Color(red255: 58, green255: 130, blue255: 246),   // blue
        Color(red255: 235, green255: 92, blue255: 122),   // pink
        Color(red255: 201, green255: 131, blue255: 238),  // purple
        Color(red255: 195, green255: 167, blue255: 123),  // tan
        Color(red255: 116, green255: 125, blue255: 134),  // gray
        Color(red255: 226, green255: 183, blue255: 175),  // light pink
    ]

    static func listColor(_ index: Int) -> Color {
        let palette = listPalette
        return palette[((index % palette.count) + palette.count) % palette.count]
    }
}
