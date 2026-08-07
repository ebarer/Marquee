//
//  MovieGridCard.swift
//  MovieTracker
//
//  A grid cell for the iPad list views: the same poster-left / details-right layout
//  as `MovieRow`, wrapped in a rounded-rect card so entries tile the wide content
//  column instead of stretching as full-width rows.
//

import SwiftUI

struct MovieGridCard: View {
    let movie: Movie
    var subtitle: String? = nil
    var showsSubtitle: Bool = true
    var duration: String? = nil
    var rating: Double? = nil
    var ratingTint: Color = .appAccent
    var status: PosterStatus? = nil

    var body: some View {
        MovieRow(movie: movie, subtitle: subtitle, showsSubtitle: showsSubtitle,
                 duration: duration, rating: rating, ratingTint: ratingTint, status: status)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
            MovieGridCard(movie: .preview, subtitle: "Watched Aug 2, 2026",
                          rating: 4.0, status: .watched)
            MovieGridCard(movie: Movie.previewList[1], duration: "2 hr 8 min",
                          status: .watchList)
            MovieGridCard(movie: .preview)
        }
        .padding()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
