//
//  Color+ProjectColors.swift
//  MovieTracker
//
//  SwiftUI equivalents of the project's UIColor palette
//  (see Extensions/UIColor+ProjectColors.swift).
//

import SwiftUI

extension Color {
    init(red255: Int, green255: Int, blue255: Int) {
        self.init(
            red: Double(red255) / 255.0,
            green: Double(green255) / 255.0,
            blue: Double(blue255) / 255.0
        )
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

    /// Selectable tints for custom movie lists (see `ListEditorView`).
    static let listPalette: [Color] = [
        .red, .orange, .yellow, .green, .teal, .blue,
        .indigo, .pink, .purple, .brown, .gray, .cyan
    ]

    /// The list palette color at an index, wrapping so an out-of-range stored
    /// value never traps.
    static func listColor(_ index: Int) -> Color {
        let palette = listPalette
        return palette[((index % palette.count) + palette.count) % palette.count]
    }
}
