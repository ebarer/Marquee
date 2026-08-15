//
//  FeaturedView.swift
//  MovieTracker
//

import SwiftUI

/// The Browse tab: a `FeaturedGridView` whose collection is chosen from the title menu.
struct FeaturedView: View {
    @State private var collection: FeaturedCollection = .popularMovies

    var body: some View {
        FeaturedGridView(collection: collection)
            .toolbarTitleMenu {
                // Two pickers over one binding, not one picker: a Divider inside a single
                // Picker doesn't render, so this is what separates movies from shows.
                collectionPicker("Movies", FeaturedCollection.movieCases)
                Divider()
                collectionPicker("Shows", FeaturedCollection.showCases)
            }
    }

    private func collectionPicker(_ label: String,
                                  _ options: [FeaturedCollection]) -> some View {
        Picker(label, selection: $collection) {
            ForEach(options) { option in
                option.label.tag(option)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    NavigationStack {
        FeaturedView()
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
