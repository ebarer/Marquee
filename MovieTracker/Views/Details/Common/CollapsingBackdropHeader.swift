//
//  CollapsingBackdropHeader.swift
//  MovieTracker
//

import SwiftUI

/// A collapsing, pinning backdrop header shared by the movie and show detail screens. It owns
/// all the scroll geometry; the caller supplies the bar via `bar(progress, width)`.
struct CollapsingBackdropHeader<Bar: View>: View {
    let backgroundURL: URL?
    let navBarBottom: CGFloat
    /// Backdrop height at rest; the header extends a little past it (solid + gradient).
    let imageHeight: CGFloat
    /// Header height at rest — the total the header occupies before any scrolling.
    let headerRest: CGFloat
    var overscroll: CGFloat = 0
    @Binding var headerPinned: Bool
    @ViewBuilder let bar: (_ progress: CGFloat, _ width: CGFloat) -> Bar

    private static var posterHeight: CGFloat { 150 }
    private static var padding: CGFloat { 16 }

    /// The collapsed height: a sliver of backdrop under the nav bar plus the compacted bar.
    private var minHeader: CGFloat {
        navBarBottom + Self.padding + Self.posterHeight * 0.75 + Self.padding
    }

    /// Scroll distance over which the header collapses from full to pinned.
    private var collapseDist: CGFloat { max(1, headerRest - minHeader) }

    /// Fades the backdrop's bottom to clear. Applied as a mask so the fade lives IN the image
    /// — no hard image edge peeks through at any crossfade opacity.
    private var backdropFade: LinearGradient {
        LinearGradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white, location: 0.55),
            .init(color: .clear, location: 1.0)
        ], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        // `visualEffect`'s closure is `@Sendable`, so read the main-actor value up front.
        let collapse = collapseDist

        return GeometryReader { proxy in
            let width = proxy.size.width
            let scrolled = max(0, -proxy.frame(in: .named("scroll")).minY)
            // Linear compaction: 100% at the top, transient through the collapse, clamped
            // (static) once complete.
            let p = min(1, scrolled / collapseDist)
            // Zoom-down is a FRAME-HEIGHT shrink, not a scaleEffect (which gaps below fill):
            // scaledToFill eases the image out. `overscroll` grows it on pull-down.
            let minImageHeight = width * 1.25 * 9.0 / 16.0
            let collapseDistance = max(0, imageHeight - minImageHeight)
            let shrink = min(scrolled, collapseDistance)
            let currentImageHeight = imageHeight + overscroll - shrink
            // The header shrinks with the image (constant solid extension) so the bar rises
            // with it — no drift, and the image stays top-anchored (fills the safe area).
            let currentHeaderHeight = currentImageHeight + (headerRest - imageHeight)
            // Glass is held off until the last stretch of the collapse, so the backdrop zoom
            // reads crisply on the way up and only crossfades to glass as it sticks.
            let glassReveal = min(1, max(0, (p - 0.7) / 0.3))
            let glassColor = 0.25    // how strongly the backdrop copy beneath the glass shows (inverted)

            ZStack(alignment: .bottomLeading) {
                // The opaque backdrop (image + gradient over the app background). Fades out
                // over the last of the collapse so the glass base shows through when pinned.
                ZStack {
                    Color.appBackground

                    // maxWidth: .infinity, NOT proxy.size.width — that's the safe-area-inset
                    // width here. Overlay centers; a bare scaledToFill would left-align.
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: currentImageHeight, maxHeight: currentImageHeight)
                        .overlay { PosterImage(url: backgroundURL) }
                        .clipped()
                        .blur(radius: 5 * glassReveal)
                        // Masking the image eases its bottom to clear, revealing the
                        // app-background base that keeps the title legible over a bright shot.
                        .mask { backdropFade }
                        .frame(maxWidth: .infinity, minHeight: currentHeaderHeight,
                               maxHeight: currentHeaderHeight, alignment: .top)
                }
                .frame(maxWidth: .infinity, minHeight: currentHeaderHeight,
                       maxHeight: currentHeaderHeight, alignment: .top)
                .opacity(1 - Double(glassReveal * glassColor))

                // Liquid Glass base — the real refractive nav-bar glass, NOT a frosted grey
                // `Material`, which only ever thins to grey and never to clear.
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: currentHeaderHeight, maxHeight: currentHeaderHeight)
                    .glassEffect(.regular.tint(.black.opacity(0.35)), in: Rectangle())
                    .opacity(glassReveal*0.80) /// TODO:EAB: Work this 75% multiple into the glassReveal calculation directly.

                // Bottom gradient grounds the header's lower edge into the app background,
                // then fades out as it pins so the compact bar becomes clean glass.
                LinearGradient(colors: [.clear, .appBackground], startPoint: .top, endPoint: .bottom)
                    .frame(maxWidth: .infinity)
                    .frame(height: min(220, currentHeaderHeight))
                    .opacity(Double(1 - glassReveal))
                    .allowsHitTesting(false)

                bar(p, width)
            }
            .frame(maxWidth: .infinity, minHeight: currentHeaderHeight, maxHeight: currentHeaderHeight)
            .clipped()
            // Pull-down shifts up so the grown image fills the exposed top; scroll-up shifts
            // DOWN by `shrink` so the shrinking header's bar stays flush with the page.
            .offset(y: shrink - overscroll)
            .onChange(of: scrolled >= collapseDist) { _, pinned in
                withAnimation(.easeInOut(duration: 0.2)) { headerPinned = pinned }
            }
        }
        .frame(height: headerRest)
        // Pin via render-time geometry (a GeometryReader-driven offset reads scroll a frame
        // late and the pinned bar vibrates against the page). Engages only past the collapse.
        .visualEffect { content, proxy in
            let scrolled = max(0, -proxy.frame(in: .named("scroll")).minY)
            return content.offset(y: max(0, scrolled - collapse))
        }
    }
}

#Preview {
    GeometryReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                CollapsingBackdropHeader(
                    backgroundURL: Movie.preview.backgroundURL(),
                    navBarBottom: 100,
                    imageHeight: proxy.size.height * 0.41,
                    headerRest: proxy.size.height * 0.5,
                    headerPinned: .constant(false)
                ) { p, width in
                    DetailHeaderBar(
                        posterThumbURL: Movie.preview.posterURL(.w342),
                        posterFullURL: Movie.preview.posterURL(.orig),
                        tint: .appAccent, zoomID: Movie.preview.id,
                        title: Movie.preview.title, subtitle: "2026  •  2 hr 25 min",
                        progress: p, width: width
                    ) {
                        Color.appAccent.frame(height: 44).clipShape(Capsule())
                    }
                }
                Color.appSeparator.frame(height: 1200)
            }
        }
        .coordinateSpace(name: "scroll")
        .ignoresSafeArea(edges: [.top, .horizontal])
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
