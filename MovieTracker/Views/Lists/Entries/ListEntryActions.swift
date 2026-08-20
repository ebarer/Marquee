//
//  ListEntryActions.swift
//  MovieTracker
//

import SwiftUI

/// Every store write a list entry can make, and the confirmations some of them raise first.
@MainActor
struct ListEntryActions {
    let store: PersistenceCoordinator?
    let context: ListEntryContext
    let pending: Binding<ListEntryConfirmation?>

    // MARK: - Requests

    // Watched episodes re-add the show on the next reconcile, so confirm, then opt out.
    func requestDelete(_ entry: MediaSnapshot) {
        if context.isWatchList, entry.mediaType == .tv,
           store?.hasWatchedEpisodes(entry.show()) == true {
            pending.wrappedValue = .removeFromWatchList(entry)
        } else {
            delete(entry)
        }
    }

    func requestShowWatched(_ watched: Bool, for entry: MediaSnapshot) {
        pending.wrappedValue = .showWatched(entry, watched: watched)
    }

    func confirm(_ confirmation: ListEntryConfirmation) {
        pending.wrappedValue = nil
        switch confirmation {
        case .removeFromWatchList(let entry): dismissFromWatchList(entry)
        case .showWatched(let entry, let watched): setShowWatched(watched, for: entry)
        }
    }

    // MARK: - Writes

    private func delete(_ entry: MediaSnapshot) {
        switch context.selection {
        case .watched:
            // A watched-season entry clears that whole season; a movie clears its watched fact.
            if let season = entry.seasonNumber {
                unwatchSeason(entry, season: season)
            } else {
                store?.unwatch(entry.persistentID)
            }
        case .list: store?.deleteEntry(entry.persistentID)
        case .viewed: store?.removeFromViewed(entry.persistentID)
        }
    }

    private func dismissFromWatchList(_ entry: MediaSnapshot) {
        guard let store else { return }
        let fallback = entry.show()
        Task { @MainActor in
            let show = await store.resolveShow(id: entry.tmdbID) ?? fallback
            store.dismissFromWatchList(show)
        }
    }

    private func setShowWatched(_ watched: Bool, for entry: MediaSnapshot) {
        guard let store else { return }
        Task { @MainActor in await store.setShowWatched(watched, showID: entry.tmdbID) }
    }

    private func unwatchSeason(_ entry: MediaSnapshot, season: Int) {
        guard let store else { return }
        store.unwatchSeason(showID: entry.tmdbID, seasonNumber: season)
        Task { @MainActor in await store.reconcile(showID: entry.tmdbID, editedSeason: season) }
    }
}
