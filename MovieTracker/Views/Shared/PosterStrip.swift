//
//  PosterStrip.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A horizontally scrolling row of poster cards linking to each movie, with an
/// optional release-year caption. Used by the Related and Known For sections.
struct PosterStrip: View {
    let movies: [Movie]
    let lists: [MovieList]
    let context: ModelContext
    var showsYear: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(movies, id: \.id) { movie in
                    NavigationLink(value: movie) {
                        VStack(spacing: 4) {
                            MoviePosterCard(movie: movie, titleLineLimit: 3,
                                            reservesTitleSpace: false, posterWidth: 90)
                            if showsYear, let year = releaseYear(movie) {
                                Text(year)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 90)
                    }
                    .buttonStyle(.plain)
                    .movieContextMenu(for: movie, lists: lists, context: context)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    private func releaseYear(_ movie: Movie) -> String? {
        guard let date = movie.releaseDate else { return nil }
        return String(Calendar.current.component(.year, from: date))
    }
}

#Preview {
    PosterStrip(movies: Movie.previewList, lists: [], context: previewModelContainer.mainContext,
                showsYear: true)
        .background(Color.appBackground)
}
