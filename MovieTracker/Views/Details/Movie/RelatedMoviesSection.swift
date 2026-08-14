//
//  RelatedMoviesSection.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A collapsible poster strip of the movie's franchise (its TMDB collection).
struct RelatedMoviesSection: View {
    let collection: [Movie]
    let lists: [MediaList]
    var tint: Color = .appAccent

    @State private var expanded = true

    var body: some View {
        if !collection.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                CollapsibleSectionHeader(title: "Related", tint: tint, isExpanded: expanded) {
                    withAnimation(.easeInOut) { expanded.toggle() }
                }
                if expanded {
                    PosterStrip(movies: collection, lists: lists, showsYear: true)
                        .transition(.opacity)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            RelatedMoviesSection(collection: Movie.previewSeriesCollection, lists: [])
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
