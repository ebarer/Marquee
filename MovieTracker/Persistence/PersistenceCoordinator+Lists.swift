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

    /// Drops duplicates; the canonical Watch List is the oldest copy, UUID breaking ties.
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
    func toggleWatchList(_ movie: Movie) { watchList.toggle(movie); save() }
    func addToWatchList(_ movie: Movie) { watchList.add(movie); save() }

    /// Unlike `watchList`, never creates the list — safe to call from a view body.
    func isInWatchList(_ movie: Movie) -> Bool {
        MediaList.watchList(in: context)?.contains(movie.id) ?? false
    }

    // MARK: - Deletion

    func deleteList(_ list: MediaList) { context.delete(list); save() }

    func deleteEntry(_ id: PersistentIdentifier) {
        if let entry = context.model(for: id) as? ListEntry { delete(entry) }
    }

    // MARK: - Grouped sections (Lists screen)

    func sections(for source: SectionSource, ascending: Bool, filter: String) async -> [SectionSnapshot] {
        let builder = SectionBuilder(modelContainer: context.container)
        return await builder.build(source: source, ascending: ascending, filter: filter)
    }
}
