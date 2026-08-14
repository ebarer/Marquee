//
//  ListMembershipMenu.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

struct ListMembershipMenu: View {
    let movie: Movie
    let watchList: MediaList?
    let customLists: [MediaList]
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    var onChange: () -> Void = {}

    var body: some View {
        Group {
            Section {
                Toggle(isOn: Binding(
                    get: { store?.isWatched(movie) ?? false },
                    set: { store?.setWatched($0, for: movie); onChange() }
                )) {
                    Label {
                        Text("Watched")
                    } icon: {
                        // Tinted like the rows below it; the menu's `.primary` would draw it white.
                        Image(systemName: "checkmark.rectangle.stack")
                            .tint(.appAccent)
                    }
                }
            }
            ListMembershipToggles(
                lists: [watchList].compactMap { $0 } + customLists,
                isMember: { $0.contains(movie.id) },
                toggle: { store?.toggle(movie, in: $0); onChange() }
            )
        }
        .tint(.primary)
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
