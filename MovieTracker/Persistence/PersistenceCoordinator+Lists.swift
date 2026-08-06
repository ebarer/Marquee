//
//  PersistenceCoordinator+Lists.swift
//  MovieTracker
//
//  List behaviour: the canonical list providers, Watch List / custom-list
//  membership, and list deletion. Cross-list rules (adding to the Watch List
//  un-marks Watched, etc.) live on the models; this applies + persists them.
//

import SwiftUI
import SwiftData

extension PersistenceCoordinator {

    // MARK: - Providers (the coordinator owns which lists are canonical)

    /// The Watch List, lazily created if it doesn't exist yet. The single place
    /// that lazy-creation happens — callers just express intent (add/remove/toggle).
    var watchList: MediaList { MediaList.ensureWatchList(in: context) }

    /// Every canonical list in display order (custom lists plus the one Watch List).
    var lists: [MediaList] { MediaList.all(in: context) }
    var customLists: [MediaList] { MediaList.customLists(in: context) }

    /// Collapses a live `@Query` result to the canonical display set — duplicates
    /// dropped and any duplicate Watch List merged to the oldest copy (UUID breaks
    /// ties, matching `watchList`). Screens keep `@Query` for reactivity but defer
    /// the "which copy is canonical" decision to here rather than deciding themselves.
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

    /// Read-only Watch List membership. Unlike `watchList`, this never creates the
    /// list, so it's safe to call from a view body (e.g. the grid poster badge).
    func isInWatchList(_ movie: Movie) -> Bool {
        MediaList.watchList(in: context)?.contains(movie.id) ?? false
    }

    // MARK: - Deletion

    func deleteList(_ list: MediaList) { context.delete(list); save() }

    /// Removes a list entry by its row-snapshot id. No-op if the model is gone.
    func deleteEntry(_ id: PersistentIdentifier) {
        if let entry = context.model(for: id) as? ListEntry { delete(entry) }
    }

    // MARK: - Grouped sections (Lists screen)

    /// Builds the month/year section snapshots for a list view off the main actor.
    /// Callers ask the coordinator instead of holding a `ModelContainer` or building
    /// a `SectionBuilder` themselves. The builder runs its fetches on its own
    /// `@ModelActor` context, off the main actor.
    func sections(for source: SectionSource, ascending: Bool, filter: String) async -> [SectionSnapshot] {
        let builder = SectionBuilder(modelContainer: context.container)
        return await builder.build(source: source, ascending: ascending, filter: filter)
    }
}
