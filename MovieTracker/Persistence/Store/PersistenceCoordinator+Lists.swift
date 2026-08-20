//
//  PersistenceCoordinator+Lists.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

extension PersistenceCoordinator {

    // MARK: - Providers

    var watchList: MediaList { MediaList.ensureWatchList(in: context) }

    var lists: [MediaList] { MediaList.all(in: context) }
    var customLists: [MediaList] { MediaList.customLists(in: context) }

    func canonicalLists(_ lists: [MediaList]) -> [MediaList] {
        let visible = lists.filter { !$0.isDeduplicated }
        guard let watch = visible.filter(\.isWatchList)
            .min(by: { ($0.createdAt, $0.uuid.uuidString) < ($1.createdAt, $1.uuid.uuidString) })
        else { return visible }
        return visible.filter { !$0.isWatchList || $0.uuid == watch.uuid }
    }

    // MARK: - Membership

    func toggle(_ movie: Movie, in list: MediaList) { list.toggle(movie); save() }
    func add(_ movie: Movie, to list: MediaList) { list.add(movie); save() }
    func toggleWatchList(_ movie: Movie) { parkWatchedDate(movie.mediaKey); watchList.toggle(movie); save() }
    func addToWatchList(_ movie: Movie) { parkWatchedDate(movie.mediaKey); watchList.add(movie); save() }

    func toggle(_ show: Show, in list: MediaList) { list.toggle(key: show.mediaKey); save() }
    func add(_ show: Show, to list: MediaList) { list.add(key: show.mediaKey); save() }
    func toggleWatchList(_ show: Show) { watchList.toggle(key: show.mediaKey); save() }
    func addToWatchList(_ show: Show) { watchList.add(key: show.mediaKey); save() }

    // The Watch List un-marks Watched, so park the date first; re-marking restores it.
    private func parkWatchedDate(_ key: MediaKey) {
        watchedMemory.remember(MediaItem.dateWatched(for: key, in: context), for: key)
    }

    // Unlike `watchList`, never creates the list, so it is safe to call from a view body.
    func isInWatchList(_ movie: Movie) -> Bool {
        MediaList.watchList(in: context)?.contains(movie.id) ?? false
    }
    func isInWatchList(_ show: Show) -> Bool {
        MediaList.watchList(in: context)?.contains(show.id, .tv) ?? false
    }

    func addToWatchList(forKey key: MediaKey) { parkWatchedDate(key); watchList.add(key: key); save() }

    // MARK: - Deletion

    func deleteList(_ list: MediaList) { context.delete(list); save() }

    func deleteEntry(_ id: PersistentIdentifier) {
        if let entry = context.model(for: id) as? ListEntry { delete(entry) }
    }

    // MARK: - Lists screen

    func list(for request: ListRequest, filter: String,
              mediaFilter: MediaTypeFilter = .all) async -> ListResult {
        await readingOffMain { $0.load(request: request, filter: filter, mediaFilter: mediaFilter) }
    }
}
