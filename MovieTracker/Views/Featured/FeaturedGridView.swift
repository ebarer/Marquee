//
//  FeaturedGridView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The poster grid for one `FeaturedCollection`; the host chooses the collection.
struct FeaturedGridView: View {
    let collection: FeaturedCollection
    var switcher: Binding<FeaturedCollection>? = nil

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = FeaturedModel()
    @State private var scrollPosition = ScrollPosition()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scrollTopToken) private var scrollTopToken

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
            // One grid per loaded collection, dissolving as a whole: animating the cells instead
            // makes each new poster slide in from where it was inserted.
            ZStack(alignment: .top) {
                grid
                    .id(model.loadedCollection)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
            .frame(maxWidth: .infinity)
        }
        .scrollPosition($scrollPosition)
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .title) { title }
        }
        .overlay {
            if model.isLoading, model.movies.isEmpty, model.shows.isEmpty {
                ProgressView()
            }
        }
        // The outgoing cards hold their place until the swap, so the top has to be taken back
        // before it: scrolling after the crossfade would drag the new cards up through it.
        .onChange(of: collection) { scrollPosition.scrollTo(edge: .top) }
        .onChange(of: scrollTopToken) {
            withAnimation(.easeOut(duration: 0.3)) { scrollPosition.scrollTo(edge: .top) }
        }
        // Idempotent for an unchanged collection, so leaving and returning keeps the loaded movies and
            // scroll position instead of reloading.
        .task(id: collection) { await model.load(collection) }
    }

    // MARK: - Cards

    // Reads the loaded collection, not the chosen one, so cards change only once its first page lands.
    private var grid: some View {
        LazyVGrid(columns: columns, spacing: isRegularWidth ? 24 : 16) {
            if model.loadedCollection.isShow {
                ForEach(model.shows, id: \.id) { show in
                    DetailLink(value: show) {
                        ShowPosterCard(show: show)
                    }
                    .buttonStyle(.posterPress)
                    .task {
                        await model.loadMoreIfNeeded(currentShow: show)
                    }
                }
            } else {
                ForEach(model.movies, id: \.id) { movie in
                    DetailLink(value: movie) {
                        MoviePosterCard(movie: movie)
                    }
                    .buttonStyle(.posterPress)
                    .movieContextMenu(for: movie, lists: lists)
                    .task {
                        await model.loadMoreIfNeeded(currentItem: movie)
                    }
                }
            }
        }
        .padding(isRegularWidth ? 20 : 10)
    }

    // MARK: - Title

    @ViewBuilder
    private var title: some View {
        if let switcher {
            Menu {
                // Two pickers over one binding, not one picker: a Divider inside a single
                // Picker doesn't render, so this is what separates movies from shows.
                collectionPicker("Movies", FeaturedCollection.movieCases, switcher)
                Divider()
                collectionPicker("Shows", FeaturedCollection.showCases, switcher)
            } label: {
                titleLabel(showsChevron: true)
            }
        } else {
            titleLabel(showsChevron: false)
        }
    }

    private func titleLabel(showsChevron: Bool) -> some View {
        HStack(spacing: 5) {
            // A hidden twin balances the visible chevron so the name stays centred.
            if showsChevron { chevron.hidden() }
            Text(collection.title)
                .font(.headline)
                .foregroundStyle(Color.appAccent)
            if showsChevron { chevron }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(5)
            .background(Color(.tertiarySystemFill), in: Circle())
            .offset(y: 1)
    }

    private func collectionPicker(_ label: String, _ options: [FeaturedCollection],
                                  _ selection: Binding<FeaturedCollection>) -> some View {
        Picker(label, selection: selection) {
            ForEach(options) { option in
                option.label.tag(option)
            }
        }
        .tint(.primary)
    }
}

#Preview("Now Playing") {
    NavigationStack {
        FeaturedGridView(collection: .nowPlaying)
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

// A `.constant` binding, not `@Previewable @State`: the latter runs the view's `@Query` before
// `.modelContainer` attaches, crashing with "No eligible connection available".
#Preview("Switcher title") {
    NavigationStack {
        FeaturedGridView(collection: .popularMovies, switcher: .constant(.popularMovies))
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
