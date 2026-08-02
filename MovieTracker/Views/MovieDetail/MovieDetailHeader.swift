//
//  MovieDetailHeader.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The parallax backdrop header: a top-pinned image that stretches on pull-down
/// and collapses to a floor on scroll-up, with the poster, title, and action bar
/// anchored to its bottom edge.
struct MovieDetailHeader: View {
    let movie: Movie
    let tint: Color
    let lists: [MediaList]
    let context: ModelContext
    let imageHeight: CGFloat
    let headerHeight: CGFloat
    let width: CGFloat
    let navBarBottom: CGFloat
    @Binding var showNavTitle: Bool
    @Binding var isSeen: Bool

    @Namespace private var zoomNamespace
    @State private var showPoster = false

    private static let posterHeight: CGFloat = 150
    private static let padding: CGFloat = 16

    var body: some View {
        parallax
            .fullScreenCover(isPresented: $showPoster) {
                // The zoom transition lives inside PosterDetailView, so the poster
                // morphs into the enlarged image rather than the whole screen.
                PosterDetailView(imageURL: movie.posterURL(.orig), tint: tint,
                                 zoomSourceID: movie.id, zoomNamespace: zoomNamespace)
            }
    }

    private var parallax: some View {
        // The image keeps its natural height; the header extends below it with solid
        // background (the gradient blends the two) so the poster lands near mid-screen
        // without enlarging the image. The floor stays taller than the poster/title.
        let minImageHeight = width * 1.25 * 9.0 / 16.0
        let collapseDistance = max(0, imageHeight - minImageHeight)
        let solidExtension = max(0, headerHeight - imageHeight)

        return GeometryReader { proxy in
            let minY = proxy.frame(in: .named("scroll")).minY
            let stretch = max(0, minY)                          // pull-down over-scroll
            let shrink = min(max(0, -minY), collapseDistance)   // scroll-up collapse (capped)
            let currentImageHeight = imageHeight + stretch - shrink
            let currentHeaderHeight = currentImageHeight + solidExtension
            let pinOffset = minY > 0 ? -minY : shrink           // pin top edge until collapsed

            ZStack(alignment: .bottomLeading) {
                Color.appBackground

                PosterImage(url: movie.backgroundURL())
                    .frame(width: width, height: currentImageHeight)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .appBackground],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: min(220, currentImageHeight))
                            .allowsHitTesting(false)
                    }
                    .frame(width: width, height: currentHeaderHeight, alignment: .top)

                overlay
                    .padding(Self.padding)
            }
            .frame(width: width, height: currentHeaderHeight)
            .clipped()
            .offset(y: pinOffset)
        }
        .frame(height: headerHeight)
    }

    private var overlay: some View {
        HStack(alignment: .bottom, spacing: 12) {
            PosterImage(url: movie.posterURL(.w342))
                .frame(width: 100, height: Self.posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
                .matchedTransitionSource(id: movie.id, in: zoomNamespace)
                .onTapGesture { showPoster = true }

            VStack(alignment: .leading, spacing: 8) {
                titleView
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .onGeometryChange(for: Bool.self) { proxy in
                        // Reveal the nav-bar title once the on-page title has scrolled
                        // fully behind the bar, so the two are never both visible.
                        proxy.frame(in: .global).maxY <= navBarBottom
                    } action: { crossed in
                        withAnimation(.easeInOut(duration: 0.2)) { showNavTitle = crossed }
                    }

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(tint)
                }

                MovieActionBar(movie: movie, lists: lists, context: context,
                               tint: tint, isSeen: $isSeen)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
    }

    /// Breaks a "Subtitle: Title" name after the colon when it can't fit one line,
    /// rather than wrapping mid-phrase.
    @ViewBuilder
    private var titleView: some View {
        if let colon = movie.title.range(of: ": ") {
            let broken = movie.title.replacingCharacters(in: colon, with: ":\n")
            ViewThatFits(in: .horizontal) {
                Text(movie.title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(broken)
            }
        } else {
            Text(movie.title)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let date = movie.releaseDate?.toString() { parts.append(date) }
        if let duration = movie.duration { parts.append(duration) }
        return parts.joined(separator: "  •  ")
    }
}

#Preview {
    ScrollView {
        MovieDetailHeader(movie: .preview, tint: .appAccent, lists: [],
                          context: previewModelContainer.mainContext,
                          imageHeight: 340, headerHeight: 400, width: 393, navBarBottom: 100,
                          showNavTitle: .constant(false), isSeen: .constant(false))
    }
    .coordinateSpace(name: "scroll")
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
