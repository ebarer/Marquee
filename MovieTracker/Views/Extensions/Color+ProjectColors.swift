//
//  Color+ProjectColors.swift
//  MovieTracker
//
//  SwiftUI equivalents of the project's UIColor palette
//  (see Extensions/UIColor+ProjectColors.swift).
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

    /// Parses a `#RRGGBB` (or `RRGGBB`) hex string; returns `nil` if malformed.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red255: Int((value >> 16) & 0xFF),
            green255: Int((value >> 8) & 0xFF),
            blue255: Int(value & 0xFF)
        )
    }

    /// The color as an uppercase `#RRGGBB` string, for persisting a custom tint.
    var hexString: String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    /// App background (near-black).
    static let appBackground = Color(red255: 12, green255: 12, blue255: 12)
    /// Hairline separator / inactive / selection tone.
    static let appSeparator = Color(red255: 35, green255: 35, blue255: 35)
    /// Brand accent (gold).
    static let appAccent = Color(red255: 200, green255: 180, blue255: 130)

    /// Grayscale white at the given brightness, matching `UIColor.whiteFaded`.
    static func whiteFaded(_ a: Double = 0.75) -> Color {
        let c = (a < 0 || a > 1) ? 0.75 : a
        return Color(red: c, green: c, blue: c)
    }

    /// Selectable tints for custom movie lists (see `ListEditorView`), matching
    /// the system list palette exactly.
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

    /// The list palette color at an index, wrapping so an out-of-range stored
    /// value never traps.
    static func listColor(_ index: Int) -> Color {
        let palette = listPalette
        return palette[((index % palette.count) + palette.count) % palette.count]
    }
}
