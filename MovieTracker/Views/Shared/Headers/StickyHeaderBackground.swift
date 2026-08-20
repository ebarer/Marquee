//
//  StickyHeaderBackground.swift
//  MovieTracker
//

import SwiftUI

/// The glass a pinned header, a search field, and a collapsed detail header share.
struct SectionHeaderGlass: View {
    // Puts the glass's own refracting edge outside the view's bounds on all four sides, for the caller to clip.
    private static let bleed: CGFloat = 24

    var tint: Color = Color.appBackground.opacity(0.55)

    var body: some View {
        Color.clear
            .glassEffect(.regular.tint(tint), in: .rect)
            .padding(-Self.bleed)
    }
}

/// The view's bounds extended upward, so a pinned header's glass reaches the scroll view's top edge.
struct HeaderSlabClip: Shape {
    let extraTop: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - extraTop,
                    width: rect.width, height: rect.height + extraTop))
    }
}

/// Chrome for a pinned header: the page colour at rest, glass once content scrolls under it.
struct StickyHeaderBackground: ViewModifier {
    let space: String
    let pinLine: CGFloat
    let scrolled: Bool
    var glassTop: CGFloat = 0
    var onPinnedChange: (Bool) -> Void = { _ in }

    @State private var pinned = false
    @State private var height: CGFloat = 0

    private var wearsGlass: Bool { pinned && scrolled }

    func body(content: Content) -> some View {
        content
            .background(alignment: .bottom) {
                if wearsGlass {
                    SectionHeaderGlass().frame(height: glassTop + height)
                } else {
                    Color.appBackground
                }
            }
            .clipShape(HeaderSlabClip(extraTop: wearsGlass ? glassTop : 0))
            .animation(.easeOut(duration: 0.15), value: wearsGlass)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            // The reported frame carries the pin offset, so resting AT the line is what pinned
            // means: past it, the next section has pushed this header off.
            .onGeometryChange(for: Bool.self) { proxy in
                abs(proxy.frame(in: .named(space)).minY - pinLine) <= 1
            } action: { isPinned in
                pinned = isPinned
                onPinnedChange(isPinned)
            }
    }
}

extension View {
    func stickyHeaderBackground(space: String, pinLine: CGFloat, scrolled: Bool,
                                glassTop: CGFloat = 0,
                                onPinnedChange: @escaping (Bool) -> Void = { _ in }) -> some View {
        modifier(StickyHeaderBackground(space: space, pinLine: pinLine, scrolled: scrolled,
                                        glassTop: glassTop, onPinnedChange: onPinnedChange))
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
