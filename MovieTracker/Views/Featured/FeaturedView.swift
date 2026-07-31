//
//  FeaturedView.swift
//  MovieTracker
//
//  Featured movies grid. A toolbar button toggles between the
//  Now Playing and Coming Soon collections. Replaces FeaturedViewController.
//

import SwiftUI
import SwiftData

struct FeaturedView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var lists: [MovieList]
    @State private var model = FeaturedModel()
    @State private var collection: FeaturedCollection = .nowPlaying

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(model.movies, id: \.id) { movie in
                    NavigationLink(value: movie) {
                        MoviePosterCard(movie: movie)
                    }
                    .buttonStyle(.plain)
                    .movieContextMenu(for: movie, lists: lists, context: context)
                    .task {
                        await model.loadMoreIfNeeded(currentItem: movie)
                    }
                }
            }
            .padding(10)
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            Picker("Collection", selection: $collection) {
                ForEach(FeaturedCollection.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
            .tint(.primary)
        }
        .overlay {
            if model.isLoading && model.movies.isEmpty {
                ProgressView()
            }
        }
        .onChange(of: collection) { _, newValue in
            Task { await model.change(to: newValue) }
        }
        .task {
            await model.start(collection)
        }
    }
}

#Preview {
    NavigationStack {
        FeaturedView()
            .movieTrackerDestinations()
    }
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}
