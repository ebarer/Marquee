//
//  RecommendationsSection.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A collapsible strip of TMDB recommendations, always the last section on a detail screen.
struct RecommendationsSection: View {
    let media: [MediaRef]
    let lists: [MediaList]
    var showsYear: Bool = false
    var tint: Color = .appAccent

    init(media: [MediaRef], lists: [MediaList] = [], showsYear: Bool = false,
         tint: Color = .appAccent) {
        self.media = media
        self.lists = lists
        self.showsYear = showsYear
        self.tint = tint
    }

    init(movies: [Movie], lists: [MediaList] = [], tint: Color = .appAccent) {
        self.init(media: movies.map(MediaRef.movie), lists: lists, showsYear: true, tint: tint)
    }

    init(shows: [Show], lists: [MediaList] = [], tint: Color = .appAccent) {
        self.init(media: shows.map(MediaRef.show), lists: lists, tint: tint)
    }

    @State private var expanded = true

    var body: some View {
        if !media.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                CollapsibleSectionHeader(title: "Recommendations", tint: tint,
                                        isExpanded: expanded) {
                    withAnimation(.easeInOut) { expanded.toggle() }
                }
                if expanded {
                    PosterStrip(media: Array(media.prefix(20)), lists: lists, showsYear: showsYear)
                        .transition(.opacity)
                }
            }
        }
    }
}

#Preview("Movies") {
    NavigationStack {
        ScrollView {
            RecommendationsSection(movies: Movie.previewList)
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Shows") {
    NavigationStack {
        ScrollView {
            RecommendationsSection(shows: Show.previewList)
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
