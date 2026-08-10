//
//  ListEditorIcon.swift
//  MovieTracker
//

import SwiftUI

struct ListEditorIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        ListIcon(symbol: symbol, color: color, size: 90, symbolSize: 40, opticalGlyph: true)
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(["list.bullet", "flag", "theatermasks", "guitars"], id: \.self) { symbol in
            ListEditorIcon(symbol: symbol, color: .red)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
