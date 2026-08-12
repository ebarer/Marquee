//
//  ShowListActions.swift
//  MovieTracker
//

import SwiftUI

// MARK: - TV swipe buttons

/// Leading swipe for a Watch List / custom-list season row: completes the displayed season.
/// Funnels through the coordinator's id-only entry point, which resolves the show and marks
/// the season — reconcile then advances the row to the next incomplete season, or moves the
/// show to the Watched list when it was the last.
struct SeasonWatchedSwipeButton: View {
    let showID: Int
    let seasonNumber: Int
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    /// A full swipe fires this action and THEN springs the row back to its starting
    /// position. The row keeps its identity across the change (it re-titles to the next
    /// season), so the list cross-fades its contents in place — start that while the cell
    /// is still travelling and the swipe reads as cut short. Hold the write until the row
    /// is home. Tuned to the spring-back; the exact figure isn't API.
    private static let rowSettleDelay: Duration = .milliseconds(450)

    var body: some View {
        Button {
            guard let store else { return }
            // Detached from this row's lifetime on purpose — the write must land even if
            // reconcile moves the row out from under us.
            Task { @MainActor in
                try? await Task.sleep(for: Self.rowSettleDelay)
                await store.setSeasonWatched(true, showID: showID, seasonNumber: seasonNumber)
            }
        } label: {
            Image(systemName: "checkmark")
        }
        .tint(.appAccent)
    }
}

/// Leading swipe for an untracked TV show row (e.g. a fully-watched show on a custom list):
/// toggles the whole show through the episode model, so the icon and action reflect real TV
/// progress rather than the movie `watchedAt` flag.
struct ShowWatchedSwipeButton: View {
    let showID: Int
    /// Receives the intended new watched value so the caller can confirm first. Nil applies
    /// the change immediately.
    var onRequest: ((Bool) -> Void)? = nil
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var isWatched: Bool {
        guard let store else { return false }
        _ = store.revision
        return store.isShowWatchedCached(showID: showID)
    }

    var body: some View {
        Button {
            guard let store else { return }
            let watched = isWatched
            if let onRequest {
                onRequest(!watched)
            } else {
                Task { @MainActor in
                    await store.setShowWatched(!watched, showID: showID)
                }
            }
        } label: {
            if isWatched {
                Image("checkmark.slashed")
            } else {
                Image(systemName: "checkmark")
            }
        }
        .tint(.appAccent)
    }
}

#Preview("TV swipe buttons") {
    NavigationStack {
        List {
            ShowRow(show: .preview, showsSeasonCount: false)
                .swipeActions(edge: .leading) {
                    SeasonWatchedSwipeButton(showID: Show.preview.id, seasonNumber: 1)
                }
            ShowRow(show: .preview, showsSeasonCount: false)
                .swipeActions(edge: .leading) {
                    ShowWatchedSwipeButton(showID: Show.preview.id)
                }
        }
        .listStyle(.plain)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
