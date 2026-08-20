//
//  ListIcon.swift
//  MovieTracker
//

import SwiftUI
import UIKit

/// Resolves a stored symbol name to the right glyph for a given context.
enum ListSymbol {
    static func canonical(_ symbol: String) -> String {
        symbol.hasSuffix(".fill") ? String(symbol.dropLast(5)) : symbol
    }

    static func solid(_ symbol: String) -> String {
        let filled = canonical(symbol) + ".fill"
        return UIImage(systemName: filled) != nil ? filled : canonical(symbol)
    }

    static func outline(_ symbol: String) -> String {
        canonical(symbol)
    }

    // A stored symbol is an emoji when it isn't a valid SF Symbol name.
    static func isEmoji(_ symbol: String) -> Bool {
        !symbol.isEmpty && UIImage(systemName: symbol) == nil
    }

    static func menuImage(_ symbol: String, pointSize: CGFloat = 22) -> UIImage? {
        isEmoji(symbol) ? emojiImage(symbol, pointSize: pointSize) : nil
    }

    // A menu's icon slot accepts only images, so an emoji has to be rasterized.
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
    var size: CGFloat = 30
    var symbolSize: CGFloat?
    var opticalGlyph: Bool = false

    var body: some View {
        Group {
            if ListSymbol.isEmoji(symbol) {
                // Emoji glyphs carry their own padding, so size them to the circle
                // (not the SF `symbolSize`) to fill it like the reference.
                Text(symbol)
                    .font(.system(size: size * 0.72))
            } else if opticalGlyph {
                Image(systemName: ListSymbol.solid(symbol))
                    .font(.system(size: glyphExtent, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
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

    private var glyphExtent: CGFloat {
        symbolSize ?? size * 0.44
    }

    private var gradient: LinearGradient {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let top = Color(hue: hue, saturation: max(saturation - 0.14, 0),
                        brightness: min(brightness + 0.14, 1))
        let bottom = Color(hue: hue, saturation: min(saturation + 0.06, 1),
                           brightness: max(brightness - 0.10, 0))
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}

extension ListIcon {
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
