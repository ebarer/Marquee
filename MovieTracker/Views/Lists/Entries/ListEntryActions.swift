//
//  ListEntryActions.swift
//  MovieTracker
//

import SwiftUI

/// Every store write a list entry can make, and the confirmations some of them raise first.
/// The rows and the grid share it, so a swipe means the same thing in both.
@MainActor
struct ListEntryActions {
    let store: PersistenceCoordinator?
    let context: ListEntryContext
    /// Owned by the container: the dialog presents from the entry that raised it.
    let pending: Binding<ListEntryConfirmation?>

    // MARK: - Requests

    /// Removing an in-progress show from the Watch List can't just drop its `ListEntry` —
    /// watched episodes re-add it on the next reconcile — so confirm, then opt out.
    func requestDelete(_ entry: MediaSnapshot) {
        if context.isWatchList, entry.mediaType == .tv,
           store?.hasWatchedEpisodes(entry.show()) == true {
            pending.wrappedValue = .removeFromWatchList(entry)
        } else {
            delete(entry)
        }
    }

    /// Marking a whole show sweeps every episode of every season, so confirm first.
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

    /// Persist the manual Watch List opt-out. Resolve the show so reconcile keeps an accurate
    /// tracked season; fall back to the snapshot's show so the removal sticks offline.
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

    /// Clear a completed season, then reconcile: un-watching an earlier season makes the show
    /// in-progress again, so it returns to the Watch List now, not on next open.
    private func unwatchSeason(_ entry: MediaSnapshot, season: Int) {
        guard let store else { return }
        store.unwatchSeason(showID: entry.tmdbID, seasonNumber: season)
        Task { @MainActor in await store.reconcile(showID: entry.tmdbID, editedSeason: season) }
    }
}
