//
//  RootView.swift
//  MovieTracker
//
//  Root SwiftUI interface: a tabbed shell replacing the storyboard
//  TabBarController. Each tab is its own NavigationStack; movie and
//  person values pushed onto a stack resolve to the (currently bridged)
//  detail screens.
//

import SwiftUI
import SwiftData

struct RootView: View {
    /// Shared SwiftData container for the Watch List, synced through the app's
    /// private CloudKit database. Built once and attached to the whole scene.
    static let sharedContainer: ModelContainer = {
        let configuration = ModelConfiguration(cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: WatchListEntry.self, MovieList.self, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

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
                        .movieTrackerDestinations()
                }
            }

            Tab("Lists", systemImage: "checklist") {
                NavigationStack {
                    WatchListView()
                        .movieTrackerDestinations()
                }
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack(path: $searchPath) {
                    SearchView(model: searchModel)
                        .movieTrackerDestinations()
                }
                // Declare the search field only on the search tab, so it never
                // appears above the Discover or Lists content.
                .searchable(text: $searchModel.query, prompt: searchModel.scope.placeholder)
                .searchScopes($searchModel.scope) {
                    ForEach(SearchModel.Scope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
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
        .task {
            // Make sure the two built-in lists exist before any screen appears.
            WatchListStore.ensureDefaultLists(in: Self.sharedContainer.mainContext)
        }
    }
}

extension View {
    /// Registers the shared movie/person navigation destinations on a stack.
    func movieTrackerDestinations() -> some View {
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
