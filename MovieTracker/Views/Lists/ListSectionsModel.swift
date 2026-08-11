//
//  ListSectionsModel.swift
//  MovieTracker
//

import SwiftUI

/// Builds the Lists screen's month/year section snapshots off the main actor.
@MainActor
@Observable
final class ListSectionsModel {
    private(set) var sections: [SectionSnapshot] = []
    /// The input the current `sections` were built for; lets the view suppress the empty-state flash.
    private(set) var loadedInput: Input?

    /// Bumping `version` forces a rebuild after a silent edit that doesn't alter `count`.
    struct Input: Equatable {
        var request: ListRequest?
        var count: Int
        var ascending: Bool
        var filter: String
        var mediaFilter: MediaTypeFilter
        var version: Int
    }

    func rebuild(for input: Input, store: PersistenceCoordinator?) async {
        guard let request = input.request, let store else {
            sections = []
            loadedInput = input
            return
        }
        let result = await store.sections(for: request, ascending: input.ascending,
                                           filter: input.filter, mediaFilter: input.mediaFilter)
        guard !Task.isCancelled else { return }
        // A selection switch replaces rows outright (no animation). Within the same list,
        // animate only *structural* changes (rows added/removed/reordered) so they slide. A
        // pure in-place content change — e.g. a tracked season advancing after a swipe —
        // must NOT animate, or it crossfades over the row instead of letting the swipe spring
        // back first and then swap the content.
        if loadedInput?.request == request, structure(of: result) != structure(of: sections) {
            withAnimation { sections = result }
        } else {
            sections = result
        }
        loadedInput = input
    }

    func clear() { sections = [] }

    /// The row layout signature (section ids + their entry ids, in order). Unchanged when only
    /// a row's contents change; differs when rows are added, removed, or reordered.
    private func structure(of sections: [SectionSnapshot]) -> [AnyHashable] {
        sections.flatMap { section in
            [AnyHashable(section.id)] + section.entries.map { AnyHashable($0.id) }
        }
    }
}
