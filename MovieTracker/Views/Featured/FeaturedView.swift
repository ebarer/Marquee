//
//  FeaturedView.swift
//  MovieTracker
//

import SwiftUI

/// The Browse tab: a `FeaturedGridView` whose collection is chosen from the title menu.
struct FeaturedView: View {
    @State private var collection: FeaturedCollection = .popularMovies

    var body: some View {
        FeaturedGridView(collection: collection, switcher: $collection)
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
