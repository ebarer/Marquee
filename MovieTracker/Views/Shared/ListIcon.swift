//
//  ListIcon.swift
//  MovieTracker
//
//  A list's icon presented the same way the list creator previews it: the SF
//  Symbol in white on a filled circle of the list's color. Used wherever a list
//  is shown in fully custom UI (rows, the detail popover, empty states) — system
//  menus can't render it and fall back to a plain tinted symbol.
//

import SwiftUI
import UIKit

/// Resolves a stored symbol name to the right glyph for a given context: solid
/// (`heart.fill`) on colored circles, outline (`heart`) in menus. Emoji are
/// handled separately since they aren't SF Symbols.
enum ListSymbol {
    /// Strips a trailing `.fill` to get the base name.
    static func canonical(_ symbol: String) -> String {
        symbol.hasSuffix(".fill") ? String(symbol.dropLast(5)) : symbol
    }

    /// The solid glyph to draw on a colored circle (the `.fill` variant when one
    /// exists, otherwise the base name).
    static func solid(_ symbol: String) -> String {
        let filled = canonical(symbol) + ".fill"
        return UIImage(systemName: filled) != nil ? filled : canonical(symbol)
    }

    /// The outline glyph to show in menus and the symbol picker.
    static func outline(_ symbol: String) -> String {
        canonical(symbol)
    }

    /// A stored symbol is an emoji when it isn't a valid SF Symbol name.
    static func isEmoji(_ symbol: String) -> Bool {
        !symbol.isEmpty && UIImage(systemName: symbol) == nil
    }

    /// An image for a menu's icon slot when the symbol isn't a plain SF Symbol —
    /// i.e. an emoji, rasterized in color. `nil` for ordinary symbols, which
    /// menus render fine via `systemName`.
    static func menuImage(_ symbol: String, pointSize: CGFloat = 22) -> UIImage? {
        isEmoji(symbol) ? emojiImage(symbol, pointSize: pointSize) : nil
    }

    /// Rasterizes an emoji so it can sit in a menu's icon slot (which only accepts
    /// images), aligned with the SF Symbol rows and keeping its own colors.
    static func emojiImage(_ emoji: String, pointSize: CGFloat = 22) -> UIImage {
        let font = UIFont.systemFont(ofSize: pointSize)
        let string = emoji as NSString
        let size = string.size(withAttributes: [.font: font])
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            string.draw(at: .zero, withAttributes: [.font: font])
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}

struct ListIcon: View {
    let symbol: String
    let color: Color
    /// Diameter of the colored circle.
    var size: CGFloat = 30
    /// The glyph's bounding-box extent. Independent of `size` so the circle can
    /// grow without the symbol growing with it; defaults proportional to the
    /// circle, leaving even padding on all sides.
    var symbolSize: CGFloat?

    var body: some View {
        Group {
            if ListSymbol.isEmoji(symbol) {
                // Emoji glyphs carry their own padding, so size them to the circle
                // (not the SF `symbolSize`) to fill it like the reference.
                Text(symbol)
                    .font(.system(size: size * 0.72))
            } else {
                // Fit every symbol into the same square box regardless of its
                // intrinsic shape, so a tall `bookmark.fill` and a wide
                // `checkmark` share consistent padding inside the circle.
                Image(systemName: ListSymbol.solid(symbol))
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: glyphExtent, height: glyphExtent)
            }
        }
        .frame(width: size, height: size)
        .background(gradient, in: Circle())
    }

    /// The largest dimension the glyph may occupy inside the circle.
    private var glyphExtent: CGFloat {
        symbolSize ?? size * 0.44
    }

    /// A soft top-lit gradient derived from the single chosen color: a lighter,
    /// less saturated tint up top easing into a deeper shade at the bottom.
    private var gradient: LinearGradient {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let top = Color(hue: h, saturation: max(s - 0.14, 0), brightness: min(b + 0.14, 1))
        let bottom = Color(hue: h, saturation: min(s + 0.06, 1), brightness: max(b - 0.10, 0))
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}

extension ListIcon {
    /// Convenience for a stored list, using its palette color.
    init(_ list: MediaList, size: CGFloat = 30, symbolSize: CGFloat? = nil) {
        self.init(symbol: list.symbol, color: list.color, size: size, symbolSize: symbolSize)
    }
}

#Preview {
    HStack(spacing: 16) {
        ListIcon(symbol: "😂", color: .orange, size: 56)
        ListIcon(symbol: "theatermasks", color: .purple, size: 56)
        ListIcon(symbol: "heart", color: .pink, size: 56)
    }
    .padding()
    .preferredColorScheme(.dark)
}
