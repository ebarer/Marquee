//
//  ListTitleMenu.swift
//  MovieTracker
//

import SwiftUI

/// The list switcher behind the navigation title, each entry with its live count.
struct ListTitleMenu: View {
    @Binding var selection: ListSelection
    let watchList: MediaList?
    let customLists: [MediaList]
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        Picker("List", selection: $selection) {
            if let watchList {
                Label {
                    titleText(watchList.name, watchList.entries?.count ?? 0)
                } icon: {
                    Image(systemName: ListSymbol.outline(watchList.symbol))
                        .tint(watchList.color)
                }
                .tag(ListSelection.list(watchList.uuid))
            }
            Label {
                titleText("Watched", store?.watchedCount ?? 0)
            } icon: {
                Image(systemName: "checkmark.rectangle.stack")
                    .tint(ListDestination.watchedColor)
            }
            .tag(ListSelection.watched)
        }

        if !customLists.isEmpty {
            Divider()
            Picker("Custom List", selection: $selection) {
                ForEach(customLists) { list in
                    Label {
                        titleText(list.name, list.entries?.count ?? 0)
                    } icon: {
                        if let image = ListSymbol.menuImage(list.symbol) {
                            Image(uiImage: image)
                                .tint(list.color)
                        } else {
                            Image(systemName: ListSymbol.outline(list.symbol))
                                .tint(list.color)
                        }
                    }
                    .tag(ListSelection.list(list.uuid))
                }
            }
        }

        Divider()
        Picker("Viewed", selection: $selection) {
            Label {
                titleText("Viewed", store?.viewedCount ?? 0)
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
                    .tint(ListDestination.viewedColor)
            }
            .tag(ListSelection.viewed)
        }
    }

    private func titleText(_ name: String, _ count: Int) -> Text {
        Text("\(name) (\(count))")
    }
}

#Preview("List switcher") {
    @Previewable @State var selection: ListSelection = .watched
    Menu {
        ListTitleMenu(
            selection: $selection,
            watchList: MediaList(name: "Watch List", symbol: "bookmark",
                                 sortOrder: 0, isWatchList: true),
            customLists: [MediaList(name: "Favorites", symbol: "heart",
                                    sortOrder: 1, colorIndex: 2)]
        )
    } label: {
        Text("Open list switcher")
    }
    .tint(.appAccent)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
