//
//  MovieMetadataStrip.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A horizontal strip of metadata cells; watched movies lead with the user's rating and date.
struct MovieMetadataStrip: View {
    /// What the cells render, held separately because `Movie`'s `==` is id-only (it doubles as a
    /// navigation value): handed the whole struct, SwiftUI never sees the payload replace a stub.
    struct Fields: Equatable {
        var certification: String?
        var bonus: String
        var rating: Double?
        var genres: [String]

        init(_ movie: Movie) {
            certification = movie.certification
            bonus = movie.bonusString
            rating = movie.rating
            genres = movie.genres ?? []
        }
    }

    let movie: Movie
    let fields: Fields
    var tint: Color = .appAccent
    var isWatched: Bool = false
    /// The detail payload is still in flight, so cells it fills read as placeholders.
    var isLoading: Bool = false

    init(movie: Movie, tint: Color = .appAccent, isWatched: Bool = false, isLoading: Bool = false) {
        self.movie = movie
        self.fields = Fields(movie)
        self.tint = tint
        self.isWatched = isWatched
        self.isLoading = isLoading
    }

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
                    MetadataCell(header: "RATING", minWidth: 60) {
                        value(known: fields.certification != nil, width: 26) { certBadge }
                    }
                    MetadataDivider()
                    MetadataCell(header: "CREDIT CLIPS") {
                        value(known: false, width: 40) { Text(fields.bonus) }
                    }
                    MetadataDivider()
                    MetadataCell(header: "TMDB.org") {
                        value(known: fields.rating != nil, width: 28) { tmdbScoreText(fields.rating) }
                    }
                    MetadataDivider()
                    MetadataCell(header: "GENRE", minWidth: 90) {
                        // Empty, not nil, is what a search stub carries: still unknown.
                        value(known: !fields.genres.isEmpty, width: 36) {
                            metadataText(movie.genresString)
                        }
                    }
                }
                .animation(.snappy, value: isWatched)
            }
            .scrollBounceBehavior(.always, axes: .horizontal)
            MetadataHairline()
        }
    }

    /// A value the caller's stub can't know yet stands in as a bar, not as an empty one.
    @ViewBuilder
    private func value<V: View>(known: Bool, width: CGFloat,
                                @ViewBuilder content: () -> V) -> some View {
        if isLoading, !known {
            MetadataPlaceholder(width: width)
        } else {
            content()
        }
    }

    @ViewBuilder
    private var certBadge: some View {
        if let cert = fields.certification, let image = UIImage(named: "Cert-\(cert)") {
            // Definite frame so the resizable badge can't expand to its native width.
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 24)
                .foregroundStyle(.white)
                .accessibilityLabel(cert)
        } else {
            metadataUnavailable
        }
    }
}

#Preview {
    MovieMetadataStrip(movie: .preview)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}

// Two genres, one genre, nothing at all (em dashes), and still pending (bars). The four must be
// the same height: the strip sits under the header and can't grow as cells fill in.
#Preview("Height across states") {
    var single = Movie.preview
    single.genres = ["Action"]
    let bare = Movie(id: 1, title: "Unknown")

    return ScrollView {
        VStack(spacing: 20) {
            MovieMetadataStrip(movie: .preview)
            MovieMetadataStrip(movie: single)
            MovieMetadataStrip(movie: bare)
            MovieMetadataStrip(movie: bare, isLoading: true)
        }
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
