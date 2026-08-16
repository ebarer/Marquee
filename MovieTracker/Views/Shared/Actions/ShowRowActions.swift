//
//  ShowRowActions.swift
//  MovieTracker
//

import SwiftUI

// MARK: - TV swipe buttons

/// Leading swipe for a Watch List / custom-list season row: completes the displayed season
/// through the id-only entry point, so reconcile then advances the row to the next one.
struct SeasonWatchedSwipeButton: View {
    let showID: Int
    let seasonNumber: Int
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    /// A full swipe fires the action and THEN springs the row back. The row keeps its identity,
    /// so hold the write until it's home or the in-place crossfade cuts the swipe short.
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

/// Leading swipe for an untracked TV show row: toggles the whole show through the episode
/// model, so the icon reflects real TV progress rather than the movie `watchedAt` flag.
struct ShowWatchedSwipeButton: View {
    let showID: Int
    /// Receives the intended new watched value so the caller can confirm first. Nil applies
    /// the change immediately.
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
