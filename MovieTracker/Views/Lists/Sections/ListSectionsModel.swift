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

    /// How long a store tick waits before rebuilding the same list — a save from a screen pushed
    /// over this one would otherwise rebuild inside that tap, costing it animation frames.
    private static let refreshDebounce = Duration.milliseconds(250)

    func rebuild(for input: Input, store: PersistenceCoordinator?) async {
        guard let request = input.request, let store else {
            sections = []
            loadedInput = input
            return
        }
        if isSilentRefresh(input) {
            try? await Task.sleep(for: Self.refreshDebounce)
            guard !Task.isCancelled else { return }
        }
        let result = await store.sections(for: request, ascending: input.ascending,
                                           filter: input.filter, mediaFilter: input.mediaFilter)
        guard !Task.isCancelled else { return }
        // Animate only *structural* changes (rows added/removed/reordered). A pure in-place
        // change must not, or it crossfades before the swipe has sprung back.
        if loadedInput?.request == request, !sameStructure(result, sections) {
            withAnimation { sections = result }
        } else {
            sections = result
        }
        loadedInput = input
    }

    func clear() {
        sections = []
        loadedInput = nil
    }

    /// True when only the store's revision (or the row count it implies) moved — the list, sort,
    /// and filter are what the visible rows were already built for, so this refresh can wait.
    private func isSilentRefresh(_ input: Input) -> Bool {
        guard var previous = loadedInput else { return false }
        previous.count = input.count
        previous.version = input.version
        return previous == input
    }

    /// Same row layout (section ids + entry ids, in order)? Walked in place rather than built into
    /// two comparable signatures: this runs on the main actor once per rebuild.
    private func sameStructure(_ lhs: [SectionSnapshot], _ rhs: [SectionSnapshot]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (left, right) in zip(lhs, rhs) {
            guard left.id == right.id, left.entries.count == right.entries.count else { return false }
            for (a, b) in zip(left.entries, right.entries) where a.id != b.id { return false }
        }
        return true
    }
}
