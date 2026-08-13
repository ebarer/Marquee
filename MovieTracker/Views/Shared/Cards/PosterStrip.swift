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

    init(media: [MediaRef], lists: [MediaList], showsYear: Bool = false) {
        self.media = media
        self.lists = lists
        self.showsYear = showsYear
    }

    init(movies: [Movie], lists: [MediaList], showsYear: Bool = false) {
        self.init(media: movies.map(MediaRef.movie), lists: lists, showsYear: showsYear)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
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
            .buttonStyle(.plain)
            .movieContextMenu(for: movie, lists: lists)
        case .show(let show):
            NavigationLink(value: show) {
                ShowPosterCard(show: show, titleLineLimit: 3,
                               reservesTitleSpace: false, posterWidth: 90)
            }
            .buttonStyle(.plain)
        }
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
