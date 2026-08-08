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
        var source: SectionSource?
        var count: Int
        var ascending: Bool
        var filter: String
        var mediaFilter: MediaTypeFilter
        var version: Int
    }

    func rebuild(for input: Input, store: PersistenceCoordinator?) async {
        guard let source = input.source, let store else {
            sections = []
            loadedInput = input
            return
        }
        let result = await store.sections(for: source, ascending: input.ascending,
                                           filter: input.filter, mediaFilter: input.mediaFilter)
        guard !Task.isCancelled else { return }
        // Animate only when the same list's contents changed; a selection switch replaces rows outright.
        if loadedInput?.source == source {
            withAnimation { sections = result }
        } else {
            sections = result
        }
        loadedInput = input
    }

    func clear() { sections = [] }
}
