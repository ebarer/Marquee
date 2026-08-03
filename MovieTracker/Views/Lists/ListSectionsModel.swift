//
//  ListSectionsModel.swift
//  MovieTracker
//

import SwiftUI

/// Holds the Lists screen's month/year section snapshots and asks the coordinator
/// to (re)build them, so `ListsView` stays layout.
@MainActor
@Observable
final class ListSectionsModel {
    private(set) var sections: [SectionSnapshot] = []
    /// The input the current `sections` were built for. Lets the view suppress the
    /// empty state during the async rebuild after a selection change (so it doesn't flash).
    private(set) var loadedInput: Input?

    /// Everything a build depends on. Bumping `version` forces a rebuild after a
    /// silent edit (e.g. a watched-date change) that doesn't alter `count`.
    struct Input: Equatable {
        var source: SectionSource?
        var count: Int
        var ascending: Bool
        var filter: String
        var version: Int
    }

    func rebuild(for input: Input, store: PersistenceCoordinator?) async {
        guard let source = input.source, let store else {
            sections = []
            loadedInput = input
            return
        }
        let result = await store.sections(for: source, ascending: input.ascending, filter: input.filter)
        guard !Task.isCancelled else { return }
        // Animate row inserts/removals only when the *same* list's contents changed
        // (a delete, completion, or edit). Switching selections or the first load
        // replace the rows outright, which shouldn't fade every row in.
        if loadedInput?.source == source {
            withAnimation { sections = result }
        } else {
            sections = result
        }
        loadedInput = input
    }

    /// Clears the rows immediately (e.g. on a selection change) so stale rows don't
    /// linger while the next build runs.
    func clear() { sections = [] }
}
