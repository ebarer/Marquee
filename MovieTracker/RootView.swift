//
//  RootView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

struct RootView: View {
    /// Shared SwiftData container for the Watch List, synced through the app's
    /// private CloudKit database. Built once and attached to the whole scene.
    static let sharedContainer: ModelContainer = {
        let configuration = ModelConfiguration(cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(
                for: MediaItem.self, MediaList.self, ListEntry.self,
                configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// Tracks CloudKit sync activity so the Lists screen can show a sync indicator.
    @State private var syncMonitor = CloudSyncMonitor()

    /// The single writer for the store, shared with the whole scene.
    @State private var store = PersistenceCoordinator(RootView.sharedContainer.mainContext)

    // Search state is shared with the search tab. The query lives on the model
    // so tapping a recent search can repopulate the field.
    @State private var searchModel = SearchModel()

    // Path for the search tab's stack. Watched so that opening a result (which
    // pushes a detail) records the current query as a recent search.
    @State private var searchPath = NavigationPath()

    var body: some View {
        TabView {
            Tab("Discover", systemImage: "film") {
                NavigationStack {
                    FeaturedView()
                        .detailDestinations()
                }
            }

            Tab("Lists", systemImage: "checklist") {
                NavigationStack {
                    ListsView()
                        .detailDestinations()
                }
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack(path: $searchPath) {
                    SearchView(model: searchModel)
                        .detailDestinations()
                }
                // Declare the search field only on the search tab, so it never
                // appears above the Discover or Lists content.
                .searchable(text: $searchModel.query, prompt: searchModel.scope.placeholder)
                // The system scope bar (.searchScopes) isn't reliably shown by
                // the bottom-docked tab search field, so SearchView renders its
                // own scope picker. Scope changes still re-run the search below.
                .onChange(of: searchModel.query) { _, newValue in
                    searchModel.search(newValue)
                }
                .onChange(of: searchModel.scope) { _, _ in
                    searchModel.search(searchModel.query)
                }
                .onChange(of: searchPath) { oldPath, newPath in
                    // Opening a result (pushing onto the stack) counts as
                    // committing the current query to recent searches.
                    if newPath.count > oldPath.count {
                        searchModel.commit()
                    }
                }
                .onSubmit(of: .search) {
                    searchModel.commit()
                }
            }
        }
        // Selecting the search tab activates its search field (and dismissing
        // search returns to the previously selected tab).
        .tabViewSearchActivation(.searchTabSelection)
        .tint(.appAccent)
        .preferredColorScheme(.dark)
        .modelContainer(Self.sharedContainer)
        .environment(syncMonitor)
        .environment(store)
        // Seed, deduplicate, and reconcile the store for the lifetime of the scene.
        .task {
            await store.bootstrap()
        }
    }
}

extension View {
    /// Registers the shared movie/person detail destinations on a stack.
    func detailDestinations() -> some View {
        self
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie)
            }
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person)
            }
    }
}

#Preview {
    RootView()
}
