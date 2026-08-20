//
//  ShowRowActions.swift
//  MovieTracker
//

import SwiftUI

// MARK: - TV swipe buttons

// A full swipe fires the action and then springs the row back. The row keeps its identity, so hold
// the write until it is home or the in-place crossfade cuts the swipe short.
private let rowSettleDelay: Duration = .milliseconds(450)

/// Leading swipe for a tracked-season row: marks the next unwatched episode, advancing the row by one.
struct EpisodeWatchedSwipeButton: View {
    let showID: Int
    let seasonNumber: Int
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        Button {
            guard let store else { return }
            // Detached from this row's lifetime on purpose: the write must land even if reconcile moves the
            // row out from under us.
            Task { @MainActor in
                try? await Task.sleep(for: rowSettleDelay)
                await store.markNextEpisodeWatched(showID: showID, seasonNumber: seasonNumber)
            }
        } label: {
            Image(systemName: "checkmark")
        }
        .tint(.appAccent)
    }
}

/// Secondary leading swipe: completes the displayed season, so reconcile advances the row to the next one.
struct SeasonWatchedSwipeButton: View {
    let showID: Int
    let seasonNumber: Int
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        Button {
            guard let store else { return }
            Task { @MainActor in
                try? await Task.sleep(for: rowSettleDelay)
                await store.setSeasonWatched(true, showID: showID, seasonNumber: seasonNumber)
            }
        } label: {
            Image(systemName: "checkmark.rectangle.stack")
        }
        .tint(ListDestination.watchedColor)
    }
}

/// Leading swipe for an untracked show: toggles the whole show through the episode model, not `watchedAt`.
struct ShowWatchedSwipeButton: View {
    let showID: Int
    var onRequest: ((Bool) -> Void)? = nil
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var isWatched: Bool {
        store?.badges.isShowWatched(showID: showID) ?? false
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
                    EpisodeWatchedSwipeButton(showID: Show.preview.id, seasonNumber: 1)
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
