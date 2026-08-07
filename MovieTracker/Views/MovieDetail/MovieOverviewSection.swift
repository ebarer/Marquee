//
//  MovieOverviewSection.swift
//  MovieTracker
//

import SwiftUI

/// The movie description, collapsed to three lines with a tap-to-expand "More" pill.
struct MovieOverviewSection: View {
    let overview: String

    @State private var expanded = false
    @State private var limitedHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var moreBaselineNudge: CGFloat = 2

    private var font: Font { .system(size: fontSize) }
    private var truncated: Bool { fullHeight > limitedHeight + 1 }

    // The text is always laid out in full (so wrapping never changes) and only
    // its clip height toggles; nil until measured, so the first frame isn't clamped to 0.
    private var clipHeight: CGFloat? {
        guard limitedHeight > 0 else { return nil }
        return expanded ? max(fullHeight, limitedHeight) : limitedHeight
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(overview)
                .font(font)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: clipHeight, alignment: .top)
                .clipped()
                .opacity(limitedHeight > 0 ? 1 : 0)
                .background { truncationProbe }

            if truncated && !expanded {
                morePill
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut) { expanded.toggle() }
        }
    }

    private var morePill: some View {
        Text("More")
            .textCase(.uppercase)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.12), in: .capsule)
            .padding(.leading, 44)
            .background(
                LinearGradient(
                    colors: [Color.appBackground.opacity(0), .appBackground, .appBackground],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(y: moreBaselineNudge)
    }

    /// Hidden copies measured at the collapsed limit and full height; the
    /// difference decides whether the "More" pill is warranted.
    private var truncationProbe: some View {
        ZStack {
            Text(overview)
                .font(font)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { heightReader { limitedHeight = $0 } }
            Text(overview)
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { heightReader { fullHeight = $0 } }
        }
        .hidden()
    }

    private func heightReader(_ report: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { report(proxy.size.height) }
                .onChange(of: proxy.size.height) { _, new in report(new) }
        }
    }
}

#Preview("Long") {
    MovieOverviewSection(overview: Movie.preview.overview ?? "")
        .background(Color.appBackground)
}

#Preview("Short") {
    MovieOverviewSection(overview: "A brief synopsis.")
        .background(Color.appBackground)
}
