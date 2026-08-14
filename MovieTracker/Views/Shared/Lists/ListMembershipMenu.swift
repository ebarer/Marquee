//
//  ListMembershipMenu.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Watch List and Watched, then the custom lists — the order the list switcher and sidebar use.
/// The menu stays open across taps, so several lists can be set in one visit.
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
                Toggle(isOn: Binding(
                    get: { store?.isWatched(movie) ?? false },
                    set: { store?.setWatched($0, for: movie); onChange() }
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
