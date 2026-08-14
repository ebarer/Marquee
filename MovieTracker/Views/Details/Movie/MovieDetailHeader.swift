//
//  MovieDetailHeader.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Movie adapter over the shared ``CollapsingBackdropHeader``: maps the movie's backdrop,
/// poster, title, and subtitle onto the shared bar and supplies the movie action bar.
struct MovieDetailHeader: View {
    let movie: Movie
    let tint: Color
    let lists: [MediaList]
    let navBarBottom: CGFloat
    let imageHeight: CGFloat
    let headerRest: CGFloat
    var overscroll: CGFloat = 0
    @Binding var headerPinned: Bool
    @Binding var isSeen: Bool

    var body: some View {
        CollapsingBackdropHeader(
            backgroundURL: movie.backgroundURL(),
            navBarBottom: navBarBottom, imageHeight: imageHeight,
            headerRest: headerRest, overscroll: overscroll,
            headerPinned: $headerPinned
        ) { progress, width in
            DetailHeaderBar(
                posterThumbURL: movie.posterURL(.w342),
                posterFullURL: movie.posterURL(.orig),
                tint: tint, zoomID: movie.id,
                title: movie.title, subtitle: subtitle,
                pendingDuration: pendingDuration,
                progress: progress, width: width
            ) {
                MovieActionBar(movie: movie, lists: lists, tint: tint, isSeen: $isSeen)
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let date = movie.releaseDate?.toString() { parts.append(date) }
        if let duration = movie.duration { parts.append(duration) }
        return parts.joined(separator: "  •  ")
    }

    /// Runtime rides in on the detail payload, so a list or search record doesn't have it yet.
    private var pendingDuration: Bool { movie.duration == nil && !movie.isDetailPayload }
}

#Preview {
    GeometryReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                MovieDetailHeader(movie: .preview, tint: .appAccent, lists: [],
                                  navBarBottom: 100, imageHeight: proxy.size.height * 0.41,
                                  headerRest: proxy.size.height * 0.5,
                                  headerPinned: .constant(false), isSeen: .constant(false))
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
