//
//  FeaturedView.swift
//  MovieTracker
//

import SwiftUI

/// The Browse tab: a `FeaturedGridView` whose collection is chosen from the title menu.
struct FeaturedView: View {
    @State private var collection: FeaturedCollection = .popular

    var body: some View {
        FeaturedGridView(collection: collection)
            .toolbarTitleMenu {
                Picker("Collection", selection: $collection) {
                    ForEach(FeaturedCollection.allCases) { option in
                        Label(option.title, systemImage: option.symbol).tag(option)
                    }
                }
                .tint(.primary)
            }
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
