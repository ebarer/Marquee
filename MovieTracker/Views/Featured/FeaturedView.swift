//
//  FeaturedView.swift
//  MovieTracker
//
//  Featured movies grid. `FeaturedGridView` renders a single collection and is
//  reused by the iPad sidebar (which picks the collection). `FeaturedView` wraps
//  it with the compact (iPhone) title menu that flips between collections.
//

import SwiftUI
import SwiftData

/// The poster grid for one `FeaturedCollection`, with no collection switcher of
/// its own — the host decides which collection to show.
struct FeaturedGridView: View {
    let collection: FeaturedCollection

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = FeaturedModel()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Wider layouts (iPad, windowed) get larger, roomier posters by raising the
    /// adaptive minimum and spacing. The column count falls out of the available
    /// width — it's never hardcoded — and posters never drop below the iPhone size.
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    private var columns: [GridItem] {
        if isRegularWidth {
            // Cap the poster width so wider layouts add columns instead of
            // ballooning each poster; the floor keeps posters at least iPhone-sized.
            return [GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 16)]
        } else {
            return [GridItem(.adaptive(minimum: 110), spacing: 10)]
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: isRegularWidth ? 24 : 16) {
                ForEach(model.movies, id: \.id) { movie in
                    NavigationLink(value: movie) {
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
        // Reloads whenever the host switches collections (and on first appear).
        .task(id: collection) { await model.change(to: collection) }
    }
}

/// The compact Discover screen: the grid plus a title menu that flips collections.
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
