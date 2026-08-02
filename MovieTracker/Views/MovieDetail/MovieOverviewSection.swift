//
//  MovieOverviewSection.swift
//  MovieTracker
//

import SwiftUI

/// The movie description, collapsed to two lines with a tap-to-expand "More" pill
/// that appears only when the text actually overflows.
struct MovieOverviewSection: View {
    let overview: String

    @State private var expanded = false
    @State private var limitedHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var moreBaselineNudge: CGFloat = 2

    private var font: Font { .system(size: fontSize) }
    private var truncated: Bool { fullHeight > limitedHeight + 1 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(overview)
                .font(font)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(expanded ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    /// A glass pill over a gradient that masks the truncated words behind it.
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
            // Sit on the description's baseline rather than the top of its line spacing.
            .offset(y: moreBaselineNudge)
    }

    /// Hidden copies measured at the collapsed limit and full height; the
    /// difference decides whether the "More" pill is warranted.
    private var truncationProbe: some View {
        ZStack {
            Text(overview)
                .font(font)
                .lineLimit(2)
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
