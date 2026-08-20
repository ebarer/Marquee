//
//  LoadingParagraph.swift
//  MovieTracker
//

import SwiftUI

/// Bars standing in for a description, sized to the text they become so the page doesn't shift.
struct LoadingParagraph: View {
    var lines: Int = 3
    var lastLineWidth: CGFloat = 0.55

    @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var lineSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(0..<lines, id: \.self) { line in
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: line == lines - 1 ? proxy.size.width * lastLineWidth : nil)
                }
                .frame(height: lineHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        LoadingParagraph()
        ExpandableText(text: Movie.preview.overview ?? "")
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
