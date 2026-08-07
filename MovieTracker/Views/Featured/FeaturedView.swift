//
//  FeaturedView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The poster grid for one `FeaturedCollection`; the host chooses the collection.
struct FeaturedGridView: View {
    let collection: FeaturedCollection

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = FeaturedModel()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    private var columns: [GridItem] {
        if isRegularWidth {
            return [GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 16)]
        } else {
            return [GridItem(.adaptive(minimum: 110), spacing: 10)]
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: isRegularWidth ? 24 : 16) {
                ForEach(model.movies, id: \.id) { movie in
                    DetailLink(value: movie) {
                        MoviePosterCard(movie: movie)
                    }
                    .buttonStyle(.plain)
                    .movieContextMenu(for: movie, lists: lists)
                    .task {
                        await model.loadMoreIfNeeded(currentItem: movie)
                    }
                }
            }
            .padding(isRegularWidth ? 20 : 10)
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if model.isLoading && model.movies.isEmpty {
                ProgressView()
            }
        }
        // Idempotent for an unchanged collection, so a push → pop reappear keeps the
        // loaded movies (and scroll position) instead of reloading.
        .task(id: collection) { await model.load(collection) }
    }
}

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
