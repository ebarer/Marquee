//
//  PosterStrip.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A horizontally scrolling row of poster cards linking to each title.
struct PosterStrip: View {
    let media: [MediaRef]
    let lists: [MediaList]
    var showsYear: Bool = false
    /// Set by a person's Known For, where a show opens their episodes rather than the show.
    var showsEpisodeCredits: Bool = false

    init(media: [MediaRef], lists: [MediaList], showsYear: Bool = false,
         showsEpisodeCredits: Bool = false) {
        self.media = media
        self.lists = lists
        self.showsYear = showsYear
        self.showsEpisodeCredits = showsEpisodeCredits
    }

    init(movies: [Movie], lists: [MediaList], showsYear: Bool = false) {
        self.init(media: movies.map(MediaRef.movie), lists: lists, showsYear: showsYear)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Deliberately not lazy (strips top out at ~20 cards): a LazyHStack sizes the
            // strip from the cards on screen first, clipping taller ones that scroll in later.
            HStack(alignment: .top, spacing: 12) {
                ForEach(media) { ref in
                    VStack(spacing: 4) {
                        card(ref)
                        if showsYear, let year = releaseYear(ref) {
                            Text(year)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 90)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func card(_ ref: MediaRef) -> some View {
        switch ref {
        case .movie(let movie):
            NavigationLink(value: movie) {
                MoviePosterCard(movie: movie, titleLineLimit: 3,
                                reservesTitleSpace: false, posterWidth: 90)
            }
            .buttonStyle(.posterPress)
            .movieContextMenu(for: movie, lists: lists)
        case .show(let show):
            NavigationLink(value: destination(show)) {
                ShowPosterCard(show: show, titleLineLimit: 3,
                               reservesTitleSpace: false, posterWidth: 90)
            }
            .buttonStyle(.posterPress)
        }
    }

    /// A credit with no ids behind it has no episodes to list, so it opens the show.
    private func destination(_ show: Show) -> ShowCreditDestination {
        showsEpisodeCredits && !show.creditIDs.isEmpty
            ? .episodes(ShowEpisodeCredits(show: show))
            : .show(show)
    }

    private func releaseYear(_ ref: MediaRef) -> String? {
        guard let date = ref.date else { return nil }
        return String(Calendar.current.component(.year, from: date))
    }
}

#Preview {
    PosterStrip(movies: Movie.previewList, lists: [], showsYear: true)
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
}

#Preview("Movies & shows") {
    PosterStrip(media: Person.preview.knownFor, lists: [])
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

// The show scrolls in after the movies: its season count must not be clipped by a height
// the strip measured from the shorter cards on screen first.
#Preview("Show behind movies") {
    let media = (Movie.previewList + Movie.previewSeriesCollection).map(MediaRef.movie)
        + [MediaRef.show(Show.previewList[1])]
    return PosterStrip(media: media, lists: [])
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}
