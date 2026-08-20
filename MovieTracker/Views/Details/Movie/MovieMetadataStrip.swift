//
//  MovieMetadataStrip.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A horizontal strip of metadata cells; watched movies lead with the user's rating and date.
struct MovieMetadataStrip: View {
    /// Held apart because `Movie`'s `==` is id-only, so SwiftUI would never see the payload replace a stub.
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
    var isLoading: Bool = false
    var awards: AwardsDigest = AwardsDigest()
    var awardsResolved: Bool = true

    init(movie: Movie, tint: Color = .appAccent, isWatched: Bool = false, isLoading: Bool = false,
         awards: AwardsDigest = AwardsDigest(), awardsResolved: Bool = true) {
        self.movie = movie
        self.fields = Fields(movie)
        self.tint = tint
        self.isWatched = isWatched
        self.isLoading = isLoading
        self.awards = awards
        self.awardsResolved = awardsResolved
    }

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var showingAwards = false

    var body: some View {
        VStack(spacing: 0) {
            MetadataHairline()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if store != nil, isWatched {
                        HStack(alignment: .top, spacing: 0) {
                            MetadataCell(header: "MY RATING") {
                                StarRating(movie: movie, rating: userRating, tint: tint)
                            }
                            MetadataDivider()
                            MetadataCell(header: "WATCHED", minWidth: 80) {
                                WatchedDateButton(movie: movie, watchedDate: watchedDate, tint: tint)
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
                    AwardsMetadataCell(awards: awards, isResolved: awardsResolved,
                                       tint: tint) { showingAwards = true }
                }
                .animation(.snappy, value: isWatched)
                .animation(.snappy, value: awards)
            }
            .scrollBounceBehavior(.always, axes: .horizontal)
            MetadataHairline()
        }
        .sheet(isPresented: $showingAwards) {
            AwardsListView(title: movie.title, digest: awards, tint: tint)
        }
    }

    // A fact read takes no observation dependency, so `revision` is what re-renders these cells once
        // a write lands. A re-mark restoring a remembered date arrives a turn after the tap.
    private var watchedDate: Date? {
        guard let store else { return nil }
        _ = store.revision
        return store.dateWatched(for: movie)
    }

    private var userRating: Double {
        guard let store else { return 0 }
        _ = store.revision
        return store.rating(for: movie) ?? 0
    }

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
    MovieMetadataStrip(movie: .preview, awards: .preview)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}

#Preview("Awards cell") {
    // A strip's dividers are vertically greedy, so these need a ScrollView to size naturally.
    ScrollView {
        VStack(spacing: 20) {
            MovieMetadataStrip(movie: .preview, awardsResolved: false)
            MovieMetadataStrip(movie: .preview)
            MovieMetadataStrip(movie: .preview, awards: .preview)
        }
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

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
