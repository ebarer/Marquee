//
//  ShowDetailHeader.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Parallax backdrop header for a show: poster, title, year-range/status subtitle,
/// and the show action bar anchored to the bottom edge. Mirrors `MovieDetailHeader`.
struct ShowDetailHeader: View {
    let show: Show
    let tint: Color
    let lists: [MediaList]
    let imageHeight: CGFloat
    let headerHeight: CGFloat
    let width: CGFloat
    let navBarBottom: CGFloat
    /// Poster path for the selected season (falls back to the show poster when nil), so the
    /// header art follows the episodes picker.
    var seasonPosterPath: String? = nil
    @Binding var showNavTitle: Bool
    @Binding var isSeen: Bool
    var onChange: () -> Void = {}

    @Namespace private var zoomNamespace
    @State private var showPoster = false

    private static let posterHeight: CGFloat = 150
    private static let padding: CGFloat = 16

    var body: some View {
        parallax
            .fullScreenCover(isPresented: $showPoster) {
                PosterDetailView(imageURL: posterURL(.orig), tint: tint,
                                 zoomSourceID: show.id, zoomNamespace: zoomNamespace)
            }
    }

    /// The selected season's poster at `size`, falling back to the show poster.
    private func posterURL(_ size: Movie.PosterSize) -> URL? {
        if let seasonPosterPath {
            return TMDBWrapper.imageURL(path: seasonPosterPath, size: size.rawValue)
        }
        return show.posterURL(size)
    }

    private var parallax: some View {
        let minImageHeight = width * 1.25 * 9.0 / 16.0
        let collapseDistance = max(0, imageHeight - minImageHeight)
        let solidExtension = max(0, headerHeight - imageHeight)

        return GeometryReader { proxy in
            let minY = proxy.frame(in: .named("scroll")).minY
            let stretch = max(0, minY)
            let shrink = min(max(0, -minY), collapseDistance)
            let currentImageHeight = imageHeight + stretch - shrink
            let currentHeaderHeight = currentImageHeight + solidExtension
            let pinOffset = minY > 0 ? -minY : shrink

            ZStack(alignment: .bottomLeading) {
                Color.appBackground

                PosterImage(url: show.backgroundURL())
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
            PosterImage(url: posterURL(.w342))
                .frame(width: 100, height: Self.posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
                // New identity per season so the poster crossfades when the picker changes.
                .id(seasonPosterPath)
                .transition(.opacity)
                .matchedTransitionSource(id: show.id, in: zoomNamespace)
                .onTapGesture { showPoster = true }

            VStack(alignment: .leading, spacing: 8) {
                titleView
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .onGeometryChange(for: Bool.self) { proxy in
                        proxy.frame(in: .global).maxY <= navBarBottom
                    } action: { crossed in
                        withAnimation(.easeInOut(duration: 0.2)) { showNavTitle = crossed }
                    }

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(tint)
                }

                ShowActionBar(show: show, lists: lists, tint: tint, isSeen: $isSeen, onChange: onChange)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if let colon = show.name.range(of: ": ") {
            let broken = show.name.replacingCharacters(in: colon, with: ":\n")
            ViewThatFits(in: .horizontal) {
                Text(show.name)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(broken)
            }
        } else {
            Text(show.name)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if show.yearRange != "N/A" { parts.append(show.yearRange) }
        if let network = show.networks?.first { parts.append(network) }
        return parts.joined(separator: "  •  ")
    }
}

#Preview {
    ScrollView {
        ShowDetailHeader(show: .preview, tint: .appAccent, lists: [],
                         imageHeight: 340, headerHeight: 400, width: 393, navBarBottom: 100,
                         showNavTitle: .constant(false), isSeen: .constant(false))
    }
    .coordinateSpace(name: "scroll")
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
