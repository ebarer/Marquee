//
//  MovieMetadataStrip.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A horizontal strip of metadata cells; watched movies lead with the user's rating and date.
struct MovieMetadataStrip: View {
    let movie: Movie
    var tint: Color = .appAccent
    var isWatched: Bool = false

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            MetadataHairline()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if let store, isWatched {
                        HStack(alignment: .top, spacing: 0) {
                            MetadataCell(header: "MY RATING") {
                                StarRating(movie: movie, rating: store.rating(for: movie) ?? 0, tint: tint)
                            }
                            MetadataDivider()
                            MetadataCell(header: "WATCHED", minWidth: 80) {
                                WatchedDateButton(movie: movie, watchedDate: store.dateWatched(for: movie), tint: tint)
                            }
                            MetadataDivider()
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    MetadataCell(header: "RATING", minWidth: 60) { certBadge }
                    MetadataDivider()
                    MetadataCell(header: "CREDIT CLIPS") { Text(movie.bonusString) }
                    MetadataDivider()
                    MetadataCell(header: "TMDB.org") { tmdbScoreText(movie.rating) }
                    MetadataDivider()
                    MetadataCell(header: "GENRE", minWidth: 90) { Text(movie.genresString) }
                }
                .animation(.snappy, value: isWatched)
            }
            .scrollBounceBehavior(.always, axes: .horizontal)
            MetadataHairline()
        }
    }

    @ViewBuilder
    private var certBadge: some View {
        if let cert = movie.certification, let image = UIImage(named: "Cert-\(cert)") {
            // Definite frame so the resizable badge can't expand to its native width.
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 24)
                .foregroundStyle(.white)
        } else {
            Text("N/A")
        }
    }
}

#Preview {
    MovieMetadataStrip(movie: .preview)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
