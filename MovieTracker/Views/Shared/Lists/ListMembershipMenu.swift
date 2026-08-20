//
//  ListMembershipMenu.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Watch List and Watched, then the custom lists. The menu stays open across taps.
struct ListMembershipMenu: View {
    let movie: Movie
    let watchList: MediaList?
    let customLists: [MediaList]
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    var onChange: () -> Void = {}

    var body: some View {
        Group {
            Section {
                ListMembershipToggles(lists: [watchList].compactMap { $0 },
                                      isMember: isMember, toggle: toggle)
                WatchedMenuToggle(movie: movie, onChange: onChange)
            }
            ListMembershipToggles(lists: customLists, isMember: isMember, toggle: toggle)
        }
        .tint(.primary)
        .menuActionDismissBehavior(.disabled)
    }

    private func isMember(_ list: MediaList) -> Bool { list.contains(movie.id) }

    private func toggle(_ list: MediaList) {
        store?.toggle(movie, in: list)
        onChange()
    }
}

/// Its own view so the checkmark tracks the store: watched state comes from a fetch, which nothing observes.
private struct WatchedMenuToggle: View {
    let movie: Movie
    let onChange: () -> Void
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var isWatched: Bool {
        store?.badges.isWatched(movie.id) ?? false
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isWatched },
            set: { watched in
                store?.afterCommit { store?.setWatched(watched, for: movie); onChange() }
            }
        )) {
            Label {
                Text("Watched")
            } icon: {
                // Tinted like the rows around it; the menu's `.primary` would draw it white.
                Image(systemName: "checkmark.rectangle.stack")
                    .tint(ListDestination.watchedColor)
            }
        }
    }
}

#Preview {
    let context = previewModelContainer.mainContext
    return Menu("Add to List") {
        ListMembershipMenu(
            movie: .preview,
            watchList: MediaList.watchList(in: context),
            customLists: MediaList.customLists(in: context)
        )
    }
    .padding()
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(context))
}
