//
//  CollapsingBackdropHeader.swift
//  MovieTracker
//

import SwiftUI

/// How far a pinned ``CollapsingBackdropHeader`` reaches below the navigation bar. Not nested in
/// it: a generic type's statics can't be reached without naming its parameter.
enum CollapsedHeader {
    static let posterHeight: CGFloat = 150
    static let padding: CGFloat = 16
    static let extent: CGFloat = padding + posterHeight * 0.75 + padding
}

/// The backdrop's zoom-down, and the glass it crossfades into as the header pins.
private enum Backdrop {
    /// The floor the image shrinks to: a 16:9 crop at 1.25× the page width, so it stays filled.
    static let zoom: CGFloat = 1.25
    static let aspect: CGFloat = 9.0 / 16.0
    /// Where the image's own fade to clear begins, as a fraction of its height.
    static let fadeStart: CGFloat = 0.55
    /// The gradient grounding the header's lower edge, at rest.
    static let groundingHeight: CGFloat = 220
    /// The last of the collapse, over which the backdrop crossfades into glass.
    static let glassSpan: CGFloat = 0.3
    /// Where the pinned glass settles. Full opacity reads as a grey pane rather than glass.
    static let glassPeak: CGFloat = 0.80
    /// How much of the backdrop copy beneath the pinned glass fades away.
    static let glassDimsBackdrop: CGFloat = 0.25
    static let glassTint = Color.black.opacity(0.35)
    static let glassBlur: CGFloat = 20
}

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

    private var minHeader: CGFloat { navBarBottom + CollapsedHeader.extent }

    /// Scroll distance over which the header collapses from full to pinned.
    private var collapseDistance: CGFloat { max(1, headerRest - minHeader) }

    /// The solid extension below the image: constant, so the bar rises with the shrinking image.
    private var solidExtent: CGFloat { headerRest - imageHeight }

    /// Fades the backdrop's bottom to clear. Applied as a mask so the fade lives IN the image
    /// — no hard image edge peeks through at any crossfade opacity.
    private var backdropFade: LinearGradient {
        LinearGradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white, location: Backdrop.fadeStart),
            .init(color: .clear, location: 1.0)
        ], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        // `visualEffect`'s closure is `@Sendable`, so read the main-actor value up front.
        let collapse = collapseDistance

        return GeometryReader { proxy in
            let width = proxy.size.width
            let scrolled = max(0, -proxy.frame(in: .named("scroll")).minY)
            // Linear compaction: 100% at the top, transient through the collapse, clamped
            // (static) once complete.
            let progress = min(1, scrolled / collapse)
            // Zoom-down is a FRAME-HEIGHT shrink, not a scaleEffect (which gaps below fill):
            // scaledToFill eases the image out. `overscroll` grows it on pull-down.
            let shrink = min(scrolled, max(0, imageHeight - width * Backdrop.zoom * Backdrop.aspect))
            let imageNow = imageHeight + overscroll - shrink
            let headerNow = imageNow + solidExtent
            // Glass is held off until the last stretch of the collapse, so the backdrop zoom
            // reads crisply on the way up and only crossfades to glass as it sticks.
            let reveal = min(1, max(0, (progress - (1 - Backdrop.glassSpan)) / Backdrop.glassSpan))
            let glass = reveal * Backdrop.glassPeak
            let backdrop = 1 - reveal * Backdrop.glassDimsBackdrop

            ZStack(alignment: .bottomLeading) {
                // The opaque backdrop (image + gradient over the app background). Fades out
                // over the last of the collapse so the glass base shows through when pinned.
                ZStack {
                    Color.appBackground

                    // maxWidth: .infinity, NOT proxy.size.width — that's the safe-area-inset
                    // width here. Overlay centers; a bare scaledToFill would left-align.
                    Color.clear
                        .headerLayer(imageNow)
                        // Bare RemoteImage, not PosterImage: its film-glyph placeholder would
                        // sit in the middle of the backdrop until the artwork lands.
                        .overlay { RemoteImage(url: backgroundURL, fadesIn: true) { Color.clear } }
                        .clipped()
                        .blur(radius: Backdrop.glassBlur * reveal)
                        // Masking the image eases its bottom to clear, revealing the
                        // app-background base that keeps the title legible over a bright shot.
                        .mask { backdropFade }
                        .headerLayer(headerNow, alignment: .top)
                }
                .headerLayer(headerNow, alignment: .top)
                .opacity(backdrop)

                // Liquid Glass base — the real refractive nav-bar glass, NOT a frosted grey
                // `Material`, which only ever thins to grey and never to clear.
                SectionHeaderGlass(tint: Backdrop.glassTint)
                    .headerLayer(headerNow)
                    .opacity(glass)

                // Bottom gradient grounds the header's lower edge into the app background,
                // then fades out as it pins so the compact bar becomes clean glass.
                LinearGradient(colors: [.clear, .appBackground], startPoint: .top, endPoint: .bottom)
                    .frame(maxWidth: .infinity)
                    .frame(height: min(Backdrop.groundingHeight, headerNow))
                    .opacity(1 - reveal)
                    .allowsHitTesting(false)

                bar(progress, width)
            }
            .headerLayer(headerNow)
            .clipped()
            // Pull-down shifts up so the grown image fills the exposed top; scroll-up shifts
            // DOWN by `shrink` so the shrinking header's bar stays flush with the page.
            .offset(y: shrink - overscroll)
            .onChange(of: scrolled >= collapse) { _, pinned in
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

private extension View {
    /// Full width at a definite height — the shape every layer of the header takes.
    func headerLayer(_ height: CGFloat, alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: alignment)
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
                ) { progress, width in
                    DetailHeaderBar(
                        posterThumbURL: Movie.preview.posterURL(.w342),
                        posterFullURL: Movie.preview.posterURL(.orig),
                        tint: .appAccent, zoomID: Movie.preview.id,
                        title: Movie.preview.title, subtitle: "2026  •  2 hr 25 min",
                        progress: progress, width: width
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
