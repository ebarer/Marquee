//
//  ListMembershipMenu.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Shared context-menu content: a Watched toggle on top, then the Watch List and
/// any custom lists. Each row shows the list's icon plus a checkmark when the movie
/// is already on it.
struct ListMembershipMenu: View {
    let movie: Movie
    let watchList: MediaList?
    let customLists: [MediaList]
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    /// Called after any change (e.g. to refresh derived UI state).
    var onChange: () -> Void = {}

    var body: some View {
        Group {
            Section {
                Toggle(isOn: Binding(
                    get: { store?.isWatched(movie) ?? false },
                    set: { store?.setWatched($0, for: movie); onChange() }
                )) {
                    Label("Watched", systemImage: "checkmark.rectangle.stack")
                }
            }
            Group {
                if let watchList {
                    toggle(for: watchList)
                }
                ForEach(customLists) { list in
                    toggle(for: list)
                }
            }
        }
        .tint(.primary)
    }

    private func toggle(for list: MediaList) -> some View {
        Toggle(isOn: Binding(
            get: { list.contains(movie.id) },
            set: { _ in store?.toggle(movie, in: list); onChange() }
        )) {
            Label {
                Text(list.name)
            } icon: {
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
