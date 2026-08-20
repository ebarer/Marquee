//
//  MetadataStrip.swift
//  MovieTracker
//

import SwiftUI

/// A single labelled metadata cell, uppercase caption over a value.
struct MetadataCell<Content: View>: View {
    let header: String
    var minWidth: CGFloat = 44
    @ViewBuilder let content: Content

    // A floor, so a cell filling in (a dash becoming a badge) can't resize the strip.
    private static var valueHeight: CGFloat { 34 }

    init(header: String, minWidth: CGFloat = 44, @ViewBuilder content: () -> Content) {
        self.header = header
        self.minWidth = minWidth
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(header)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                // Centred in the reserved space; the header above stays pinned to the top.
                .frame(minHeight: Self.valueHeight, alignment: .center)
                // Placeholders are hidden from accessibility, so this element existing means the cell has
                // disclosed a value, which is what the UI tests assert on.
                .accessibilityIdentifier("metadata-value-\(header)")
        }
        .fixedSize()
        .frame(minWidth: minWidth, alignment: .top)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// A bar standing in for a cell's value while the detail payload is in flight.
struct MetadataPlaceholder: View {
    var width: CGFloat = 44

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 11

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.12))
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

struct MetadataHairline: View {
    var body: some View {
        Rectangle().fill(Color.appSeparator).frame(height: 0.5)
    }
}

struct MetadataDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(width: 0.5)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 14)
    }
}

var metadataUnavailable: Text {
    Text("—").foregroundColor(.secondary)
}

func metadataText(_ value: String) -> Text {
    value.isEmpty || value == "N/A" ? metadataUnavailable : Text(value)
}

func tmdbScoreText(_ rating: Double?) -> Text {
    guard let rating, rating > 0 else { return metadataUnavailable }
    let score = (rating / 2 * 10).rounded() / 10
    let formatted = score == score.rounded()
        ? String(format: "%.0f", score)
        : String(format: "%.1f", score)
    return Text("\(formatted)\(Text(" / 5").foregroundColor(.secondary))")
}

#Preview {
    VStack(spacing: 0) {
        MetadataHairline()
        HStack(alignment: .top, spacing: 0) {
            MetadataCell(header: "TMDB.org") { tmdbScoreText(8.4).multilineTextAlignment(.center) }
            MetadataDivider()
            MetadataCell(header: "GENRE", minWidth: 90) { Text("Drama, Sci-Fi") }
        }
        MetadataHairline()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
