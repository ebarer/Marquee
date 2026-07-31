//
//  ListMembershipMenu.swift
//  MovieTracker
//
//  Shared long-press / context-menu content for toggling a movie's list
//  membership: the Watch List first, a separator, then any custom lists. Each
//  row shows the list's icon plus a checkmark when the movie is already on it.
//

import SwiftUI
import SwiftData

struct ListMembershipMenu: View {
    let movie: Movie
    let watchList: MovieList?
    let watchedList: MovieList?
    let customLists: [MovieList]
    let context: ModelContext
    /// Called after any membership change (e.g. to refresh derived UI state).
    var onChange: () -> Void = {}

    var body: some View {
        Group {
            // Watched sits on its own at the top, separated by a divider.
            if let watchedList {
                Section {
                    toggle(for: watchedList)
                }
            }
            Group {
                if let watchList {
                    toggle(for: watchList)
                }
                if !customLists.isEmpty {
                    ForEach(customLists) { list in
                        toggle(for: list)
                    }
                }
            }
        }
        .tint(.primary)
    }

    // A menu Toggle shows a checkmark for the "on" state while keeping the
    // label's list icon — giving "checkmark in addition to the symbol".
    private func toggle(for list: MovieList) -> some View {
        Toggle(isOn: Binding(
            get: { WatchListStore.isMember(movie.id, of: list) },
            set: { _ in
                WatchListStore.toggle(movie, in: list, in: context)
                onChange()
            }
        )) {
            Label {
                Text(list.name)
            } icon: {
                // Emoji and the flip-prone smiley need a prebuilt image; ordinary
                // symbols render fine via `systemName`.
                if let image = ListSymbol.menuImage(list.symbol) {
                    Image(uiImage: image)
                } else {
                    Image(systemName: ListSymbol.outline(list.symbol))
                }
            }
        }
    }
}

#Preview {
    let context = previewModelContainer.mainContext
    Menu("Add to List") {
        ListMembershipMenu(
            movie: .preview,
            watchList: WatchListStore.list(kind: .toWatch, in: context),
            watchedList: WatchListStore.list(kind: .watched, in: context),
            customLists: WatchListStore.allLists(in: context).filter { $0.kind == .custom },
            context: context
        )
    }
    .padding()
    .modelContainer(previewModelContainer)
}
