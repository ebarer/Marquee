//
//  CollapsingBackdropHeader.swift
//  MovieTracker
//

import SwiftUI

/// A collapsing, pinning backdrop header shared by the movie and show detail screens.
///
/// It owns all the scroll geometry — the backdrop fills from the top (into the safe area),
/// its frame shrinks on scroll-up so `scaledToFill` eases the image out, it stretches on
/// pull-down, and the bar rides up and then pins under the nav bar with the page scrolling
/// underneath. The bar itself is supplied by the caller via `bar(progress, width)`, where
/// `progress` (0 → 1) drives the compaction. See ``DetailHeaderBar``.
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

    /// Fades the bottom of the backdrop into transparency. Applied as a mask so the fade
    /// lives IN the image itself — its bottom edge is soft at any crossfade opacity, so no
    /// hard image edge ever peeks through during the collapse.
    private var backdropFade: LinearGradient {
        LinearGradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white, location: 0.55),
            .init(color: .clear, location: 1.0)
        ], startPoint: .top, endPoint: .bottom)
    }

    /// A gentler fade for the behind-glass tint: it only softens the very bottom edge, so the
    /// backdrop color carries across the compact bar (which sits low in the header) instead of
    /// fading out right where the bar is.
    private var tintFade: LinearGradient {
        LinearGradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white, location: 0.85),
            .init(color: .clear, location: 1.0)
        ], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let scrolled = max(0, -proxy.frame(in: .named("scroll")).minY)
            // Linear compaction: 100% at the top, transient through the collapse, clamped
            // (static) once complete.
            let p = min(1, scrolled / collapseDist)
            // Backdrop zoom-down is a FRAME-HEIGHT shrink (not a scaleEffect, which gaps
            // below fill): the frame shrinks imageHeight → minImageHeight so scaledToFill
            // eases the image out. `overscroll` grows it on pull-down.
            let minImageHeight = width * 1.25 * 9.0 / 16.0
            let collapseDistance = max(0, imageHeight - minImageHeight)
            let shrink = min(scrolled, collapseDistance)
            let currentImageHeight = imageHeight + overscroll - shrink
            // The header shrinks with the image (constant solid extension) so the bar rises
            // with it — no drift, and the image stays top-anchored (fills the safe area).
            let currentHeaderHeight = currentImageHeight + (headerRest - imageHeight)
            // The glass reveal is held off until the final stretch of the collapse, so the
            // backdrop zoom reads crisply on the way up and only crossfades to glass as it
            // sticks. 0 until p passes 0.7, then ramps to 1 at the pin.
            let glassReveal = min(1, max(0, (p - 0.7) / 0.3))
            // Pinned-glass tuning knobs.
            let glassDim = 0.35     // black scrim strength → overall darkness
            let glassTint = 0.9     // backdrop image placed BEHIND the material, so the material
                                    // blurs the image tint and the live page together — colors
                                    // come through without a static overlay masking the movement.

            ZStack(alignment: .bottomLeading) {
                // Backdrop tint BEHIND the glass: the material blurs this together with the live
                // page scrolling behind the header, so the bar picks up the image's colors while
                // the page still reads through. Faded in only as it pins.
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: currentHeaderHeight, maxHeight: currentHeaderHeight)
                    .overlay { PosterImage(url: backgroundURL) }
                    .clipped()
                    .mask { tintFade }
                    .opacity(Double(glassReveal) * glassTint)
                    .allowsHitTesting(false)

                // Thin glass base — hidden at rest behind the opaque backdrop, it takes over as
                // that backdrop fades so the page reads through the pinned bar (like the nav bar).
                // Pin the dark colorScheme: like PosterDetailView, the material otherwise falls
                // back to its light (pale) variant in this context.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(maxWidth: .infinity, minHeight: currentHeaderHeight, maxHeight: currentHeaderHeight)

                // The opaque backdrop (image + gradient over the app background). Fades out
                // over the last of the collapse so the glass base shows through when pinned.
                ZStack {
                    Color.appBackground

                    // `Color.clear` pins a definite full-width frame (maxWidth: .infinity — NOT
                    // proxy.size.width, which is the safe-area-inset width inside a ScrollView and
                    // leaves a trailing gutter). The image fills it as a CENTERED overlay: a bare
                    // scaledToFill image would size the frame to its own width and left-align it.
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: currentImageHeight, maxHeight: currentImageHeight)
                        .overlay { PosterImage(url: backgroundURL) }
                        .clipped()
                        // The fade is a mask on the image itself: its bottom eases to clear,
                        // revealing the app-background base below (which keeps the title legible
                        // over a bright backdrop) with no hard image edge at any point in scroll.
                        .mask { backdropFade }
                        .frame(maxWidth: .infinity, minHeight: currentHeaderHeight,
                               maxHeight: currentHeaderHeight, alignment: .top)
                }
                .frame(maxWidth: .infinity, minHeight: currentHeaderHeight,
                       maxHeight: currentHeaderHeight, alignment: .top)
                .opacity(1 - glassReveal)

                // Dimming layer beneath the tint (per Apple's guidance for glass) so the bar
                // defaults to the deep tone of a dark-mode toolbar rather than a pale frost.
                Color.black.opacity(Double(glassReveal) * glassDim)
                    .frame(maxWidth: .infinity, minHeight: currentHeaderHeight, maxHeight: currentHeaderHeight)
                    .allowsHitTesting(false)

                // Bottom gradient — grounds the header's lower edge into the app background at
                // rest and through the transition (hiding the seam while the image is present),
                // then fades out as it finishes pinning so the compact bar becomes clean glass
                // with the page reading through it (the hairline marks the edge when pinned).
                LinearGradient(colors: [.clear, .appBackground], startPoint: .top, endPoint: .bottom)
                    .frame(maxWidth: .infinity)
                    .frame(height: min(220, currentHeaderHeight))
                    .opacity(Double(1 - glassReveal))
                    .allowsHitTesting(false)

                bar(p, width)
            }
            .frame(maxWidth: .infinity, minHeight: currentHeaderHeight, maxHeight: currentHeaderHeight)
            .clipped()
            .overlay(alignment: .bottom) {
                // Nav-bar-style hairline, revealed once the bar is stuck.
                Divider().opacity(Double(p))
            }
            // Pull-down shifts up so the grown image fills the exposed top; on scroll-up shift
            // DOWN by `shrink` so the shrinking header's bar stays flush with the page (the
            // sliver this opens at the top sits under the nav bar).
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
            return content.offset(y: max(0, scrolled - collapseDist))
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
