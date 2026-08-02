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
            // MediaItem/MediaList/ListEntry are the live schema; WatchListEntry +
            // MovieList remain only so the one-shot launch migration can read them.
            return try ModelContainer(
                for: MediaItem.self, MediaList.self, ListEntry.self,
                WatchListEntry.self, MovieList.self,
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
            let context = Self.sharedContainer.mainContext
            SyncLog.snapshot("launch", in: context)

            // On a brand-new local store (e.g. a fresh install for an existing
            // iCloud account), wait briefly for the first CloudKit import before
            // seeding the Watch List, so we don't duplicate one we're about to
            // receive. Devices that already have it locally seed/reconcile at once.
            if MediaList.watchList(in: context) == nil {
                SyncLog.logger.log("🌱 empty local store — waiting up to 6s for initial import before seeding")
                let imported = await Self.waitForInitialImport(timeout: .seconds(6))
                SyncLog.logger.log("🌱 initial wait ended (\(imported ? "import arrived" : "timed out", privacy: .public))")
            } else {
                SyncLog.logger.log("🌱 existing local store — seeding/reconciling immediately")
            }
            MediaList.ensureWatchList(in: context)
            try? context.save()
            Self.migrateLegacyDataIfNeeded(in: context)
            SyncLog.snapshot("after seed", in: context)

            // CloudKit imports from another device arrive after launch and can
            // bring duplicate built-in lists. Reconcile whenever remote changes
            // land, debounced so we act once a burst of imported records settles
            // rather than on every partial notification.
            var debounce: Task<Void, Never>?
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                debounce?.cancel()
                debounce = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    SyncLog.logger.log("🔁 remote change settled — reconciling")
                    MediaList.deduplicateWatchList(in: context)
                    MediaItem.deduplicate(in: context)
                    try? context.save()
                    SyncLog.snapshot("after reconcile", in: context)
                }
            }
        }
    }
}

extension RootView {
    /// Waits for the first remote store change (a CloudKit import landing) or the
    /// timeout, whichever comes first. Used to give a fresh device a chance to
    /// receive existing lists before it seeds its own. Returns `true` if a remote
    /// change arrived, `false` if it timed out.
    static func waitForInitialImport(timeout: Duration) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }
}

// MARK: - One-shot legacy migration

extension RootView {
    private static let migrationFlag = "didMigrateToMediaSchema.v1"

    /// Converts pre-restructure `WatchListEntry` rows into the new schema once, on
    /// device: Watched → `MediaItem.watchedAt` (+rating), Viewed → `lastViewedAt`,
    /// Watch List/custom → `ListEntry`. Guarded by a `UserDefaults` flag; single
    /// device, local, idempotent (the CloudKit dev schema is reset separately, so
    /// there's no cross-device convergence to solve).
    static func migrateLegacyDataIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationFlag) else { return }

        let legacyEntries = (try? context.fetch(FetchDescriptor<WatchListEntry>())) ?? []
        guard !legacyEntries.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationFlag)
            return
        }
        SyncLog.logger.log("🔀 migrating \(legacyEntries.count) legacy entries to the new schema")

        let watchList = MediaList.ensureWatchList(in: context)
        var customLists: [UUID: MediaList] = [:]

        func movie(_ entry: WatchListEntry) -> Movie {
            let movie = Movie(id: entry.movieID, title: entry.title)
            movie.poster = entry.posterPath
            movie.releaseDate = entry.releaseDate
            movie.runtime = entry.runtime
            return movie
        }

        func customList(mirroring legacy: MovieList) -> MediaList {
            if let existing = customLists[legacy.uuid] { return existing }
            let list = MediaList(name: legacy.name, symbol: legacy.symbol,
                                 sortOrder: legacy.sortOrder, colorIndex: legacy.colorIndex)
            list.uuid = legacy.uuid
            list.createdAt = legacy.createdAt
            context.insert(list)
            customLists[legacy.uuid] = list
            return list
        }

        func addEntry(_ entry: WatchListEntry, to list: MediaList) {
            guard !list.contains(entry.movieID) else { return }
            let member = ListEntry(movie: movie(entry))
            member.list = list
            context.insert(member)
        }

        for entry in legacyEntries {
            switch entry.list?.kind {
            case .watched:
                let item = MediaItem.upsert(movie(entry), in: context)
                if item.watchedAt == nil {
                    item.watchedAt = entry.dateWatched ?? MediaItem.floatingDay(from: Date())
                }
                if item.userRating == nil { item.userRating = entry.userRating }
            case .viewed:
                let item = MediaItem.upsert(movie(entry), in: context)
                if item.lastViewedAt == nil { item.lastViewedAt = entry.dateAdded }
            case .toWatch:
                addEntry(entry, to: watchList)
            case .custom:
                if let legacy = entry.list { addEntry(entry, to: customList(mirroring: legacy)) }
            case .none:
                break
            }
        }

        MediaItem.deduplicate(in: context)
        MediaList.deduplicateWatchList(in: context)
        try? context.save()
        UserDefaults.standard.set(true, forKey: migrationFlag)
        SyncLog.snapshot("after migration", in: context)
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
