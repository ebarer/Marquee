//
//  StickyHeaderBackground.swift
//  MovieTracker
//

import SwiftUI

/// The glass a pinned header and a search field share.
struct SectionHeaderGlass: View {
    /// Puts the glass's own bright edge outside the view's bounds, for the caller to clip.
    private static let bleed: CGFloat = 24

    var body: some View {
        Color.clear
            .glassEffect(.regular.tint(Color.appBackground.opacity(0.55)), in: .rect)
            .padding(.vertical, -Self.bleed)
    }
}

/// The view's bounds extended upward, so a pinned header's glass can reach the scroll view's
/// top edge.
struct HeaderSlabClip: Shape {
    let extraTop: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - extraTop,
                    width: rect.width, height: rect.height + extraTop))
    }
}

/// Chrome for a header pinned in a scroll view: the page colour at rest, and glass reaching the
/// top edge once it is pinned with content scrolled under it, so bar and header read as one slab.
struct StickyHeaderBackground: ViewModifier {
    /// The scroll content's coordinate space, in which the pin line is measured.
    let space: String
    /// Where a pinned header comes to rest — the scroll view's top content inset.
    let pinLine: CGFloat
    let scrolled: Bool
    var onPinnedChange: (Bool) -> Void = { _ in }

    @State private var pinned = false
    @State private var height: CGFloat = 0

    private var wearsGlass: Bool { pinned && scrolled }

    func body(content: Content) -> some View {
        content
            .background(alignment: .bottom) {
                if wearsGlass {
                    SectionHeaderGlass().frame(height: pinLine + height)
                } else {
                    Color.appBackground
                }
            }
            .clipShape(HeaderSlabClip(extraTop: wearsGlass ? pinLine : 0))
            .animation(.easeOut(duration: 0.15), value: wearsGlass)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .named(space)).minY <= pinLine + 0.5
            } action: { isPinned in
                pinned = isPinned
                onPinnedChange(isPinned)
            }
    }
}

extension View {
    func stickyHeaderBackground(space: String, pinLine: CGFloat, scrolled: Bool,
                                onPinnedChange: @escaping (Bool) -> Void = { _ in }) -> some View {
        modifier(StickyHeaderBackground(space: space, pinLine: pinLine, scrolled: scrolled,
                                        onPinnedChange: onPinnedChange))
    }
}

#Preview("At rest and pinned") {
    VStack(spacing: 40) {
        SectionHeader(title: "August 2026", color: .appAccent)
            .stickyHeaderBackground(space: "preview", pinLine: 0, scrolled: false)
        SectionHeader(title: "Pinned over content", color: .appAccent)
            .stickyHeaderBackground(space: "preview", pinLine: 0, scrolled: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
        PosterImage(url: Movie.preview.posterURL(.w342))
            .ignoresSafeArea()
    }
    .preferredColorScheme(.dark)
}
