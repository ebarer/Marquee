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
    private(set) var loadedInput: Input?

    // Bumping `version` forces a rebuild after a silent edit that doesn't alter `count`.
    struct Input: Equatable {
        var request: ListRequest?
        var count: Int
        var ascending: Bool
        var filter: String
        var mediaFilter: MediaTypeFilter
        var streamable: StreamableFilter?
        var version: Int
    }

    // How long a store tick waits before rebuilding the same list. A save from a screen pushed over
    // this one would otherwise rebuild inside that tap, costing it animation frames.
    private static let refreshDebounce = Duration.milliseconds(250)

    // Typing rebuilds from scratch: a fresh `ModelContext` and a full scan. A keystroke waits.
    private static let filterDebounce = Duration.milliseconds(200)

    func rebuild(for input: Input, store: PersistenceCoordinator?) async {
        guard let request = input.request, let store else {
            sections = []
            loadedInput = input
            return
        }
        if isSilentRefresh(input) {
            try? await Task.sleep(for: Self.refreshDebounce)
            guard !Task.isCancelled else { return }
        } else if input.filter != loadedInput?.filter, !input.filter.isEmpty {
            try? await Task.sleep(for: Self.filterDebounce)
            guard !Task.isCancelled else { return }
        }
        var result = await store.sections(for: request, ascending: input.ascending,
                                         filter: input.filter, mediaFilter: input.mediaFilter)
        if let streamable = input.streamable {
            result = await Self.keepingStreamable(result, using: streamable)
        }
        guard !Task.isCancelled else { return }
        // Animate only structural changes: rows added, removed or reordered. A pure in-place change
        // crossfades before the swipe has sprung back.
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

    // Drops rows the offline cache can't confirm are streaming, and any section left empty.
    private static func keepingStreamable(_ sections: [SectionSnapshot],
                                          using filter: StreamableFilter) async -> [SectionSnapshot] {
        let identity = { (entry: MediaSnapshot) in
            MediaCacheTarget.Identity(tmdbID: entry.tmdbID, mediaType: entry.mediaType)
        }
        let streamable = await StreamableIndex.shared.streamable(
            sections.flatMap(\.entries).map(identity), using: filter)
        return sections.compactMap { section in
            let entries = section.entries.filter { streamable.contains(identity($0)) }
            guard !entries.isEmpty else { return nil }
            return SectionSnapshot(id: section.id, title: section.title, entries: entries,
                                   isCollapsible: section.isCollapsible,
                                   ratingStars: section.ratingStars)
        }
    }

    // True when only the store's revision, or the row count it implies, moved. The list, sort and
    // filter are what the visible rows were already built for.
    private func isSilentRefresh(_ input: Input) -> Bool {
        guard var previous = loadedInput else { return false }
        previous.count = input.count
        previous.version = input.version
        return previous == input
    }

    // Same row layout (section ids and entry ids, in order)? Walked in place rather than built into
    // two comparable signatures: this runs on the main actor once per rebuild.
    private func sameStructure(_ lhs: [SectionSnapshot], _ rhs: [SectionSnapshot]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (left, right) in zip(lhs, rhs) {
            guard left.id == right.id, left.entries.count == right.entries.count else { return false }
            for (a, b) in zip(left.entries, right.entries) where a.id != b.id { return false }
        }
        return true
    }
}
