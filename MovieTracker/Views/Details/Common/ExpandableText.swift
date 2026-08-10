//
//  ExpandableText.swift
//  MovieTracker
//

import SwiftUI

/// Text truncated to `lineLimit` with a tap-to-expand "More" pill. The single
/// truncated-text control shared by movie/show/episode descriptions and person bios.
struct ExpandableText: View {
    let text: String
    var lineLimit: Int = 3
    var font: Font? = nil
    var onCollapse: () -> Void = {}

    @State private var expanded = false
    @State private var limitedHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var moreBaselineNudge: CGFloat = 2

    private var resolvedFont: Font { font ?? .system(size: fontSize) }
    private var truncated: Bool { fullHeight > limitedHeight + 1 }

    // Full layout is always used (so wrapping never changes) and only the clip
    // height toggles; nil until measured so the first frame isn't clamped to 0.
    private var clipHeight: CGFloat? {
        guard limitedHeight > 0 else { return nil }
        return expanded ? max(fullHeight, limitedHeight) : limitedHeight
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(text)
                .font(resolvedFont)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: clipHeight, alignment: .top)
                .clipped()
                .opacity(limitedHeight > 0 ? 1 : 0)
                .background { probe }

            if truncated && !expanded {
                morePill
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let collapsing = expanded
            withAnimation(.easeInOut) { expanded.toggle() }
            if collapsing { onCollapse() }
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

    // Hidden copies measured at the collapsed limit and at full height; the
    // difference decides whether the "More" pill is warranted.
    private var probe: some View {
        ZStack {
            Text(text)
                .font(resolvedFont)
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { heightReader { limitedHeight = $0 } }
            Text(text)
                .font(resolvedFont)
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

// Long (shows the More pill), short (no pill), and a 5-line .body bio.
#Preview {
    VStack(alignment: .leading, spacing: 24) {
        ExpandableText(text: Movie.preview.overview ?? "")
        ExpandableText(text: "A brief synopsis.")
        ExpandableText(text: Person.preview.bio ?? "", lineLimit: 5, font: .body)
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
