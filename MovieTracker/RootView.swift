//
//  RootView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData
import CoreData

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
    @State private var store = MediaStore(RootView.sharedContainer.mainContext)

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
                    ListsView()
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
        .task {
            let context = store.context
            SyncLog.snapshot("launch", in: context)

            // On a brand-new local store (e.g. a fresh install for an existing iCloud
            // account), wait for the Watch List specifically to sync down before
            // seeding, so we adopt the existing list instead of creating a duplicate.
            // Devices that already have it locally seed/reconcile at once.
            if MediaList.watchList(in: context) == nil {
                SyncLog.logger.log("🌱 empty local store — waiting up to 6s for the Watch List to sync before seeding")
                let arrived = await Self.waitForWatchList(in: context, timeout: .seconds(6))
                SyncLog.logger.log("🌱 wait ended (\(arrived ? "Watch List arrived" : "timed out — seeding", privacy: .public))")
            } else {
                SyncLog.logger.log("🌱 existing local store — seeding/reconciling immediately")
            }
            store.seedWatchList()
            // Prune any duplicates a prior session marked (past the grace period).
            store.deduplicate()
            SyncLog.snapshot("after seed", in: context)

            // CloudKit imports from another device arrive after launch and can bring
            // duplicate built-in lists. Reconcile whenever remote changes land,
            // debounced so we act once a burst of imported records settles.
            var debounce: Task<Void, Never>?
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                debounce?.cancel()
                debounce = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    SyncLog.logger.log("🔁 remote change settled — reconciling")
                    store.deduplicate()
                    SyncLog.snapshot("after reconcile", in: context)
                }
            }
        }
    }
}

extension RootView {
    /// Waits for the Watch List to sync down from CloudKit (polling as records import
    /// in the background), up to `timeout`, so a fresh device adopts the existing list
    /// instead of seeding a duplicate. Returns `true` if it arrived.
    ///
    /// We poll for the list rather than "prioritize lists over movies" because
    /// `NSPersistentCloudKitContainer` imports the whole zone and offers no way to
    /// pull one record type before another — so we simply wait for the one we need.
    @MainActor
    static func waitForWatchList(in context: ModelContext, timeout: Duration) async -> Bool {
        let start = ContinuousClock.now
        while ContinuousClock.now - start < timeout {
            if MediaList.watchList(in: context) != nil { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return MediaList.watchList(in: context) != nil
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
