//
//  ListsToolbar.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Which list-like view is showing: a real `MediaList` (Watch List or custom) or
/// the derived Watched / Viewed queries.
enum ListSelection: Hashable {
    case list(UUID)
    case watched
    case viewed
}

/// The navigation title: the name (tinted with the list color) over a title count,
/// flanked by a menu chevron.
struct ListTitleLabel: View {
    let name: String
    let color: Color
    let count: Int

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 5) {
                chevron.hidden()
                Text(name)
                    .font(.headline)
                    .foregroundStyle(color)
                chevron
            }
            Text("^[\(count) Movie](inflect: true)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(5)
            .background(Color(.tertiarySystemFill), in: Circle())
            .offset(y: 1)
    }
}

/// The title-menu switcher: Watch List + Watched on top, custom lists next, Viewed
/// last.
struct ListTitleMenu: View {
    @Binding var selection: ListSelection
    let watchList: MediaList?
    let customLists: [MediaList]

    var body: some View {
        Picker("List", selection: $selection) {
            if let watchList {
                Label(watchList.name, systemImage: ListSymbol.outline(watchList.symbol))
                    .tag(ListSelection.list(watchList.uuid))
            }
            Label("Watched", systemImage: "checkmark.rectangle.stack")
                .tag(ListSelection.watched)
        }

        if !customLists.isEmpty {
            Divider()
            Picker("Custom List", selection: $selection) {
                ForEach(customLists) { list in
                    Label {
                        Text(list.name)
                    } icon: {
                        if let image = ListSymbol.menuImage(list.symbol) {
                            Image(uiImage: image)
                        } else {
                            Image(systemName: ListSymbol.outline(list.symbol))
                                .foregroundStyle(list.color)
                        }
                    }
                    .tag(ListSelection.list(list.uuid))
                }
            }
        }

        Divider()
        Picker("Viewed", selection: $selection) {
            Label("Viewed", systemImage: "clock.arrow.circlepath")
                .tag(ListSelection.viewed)
        }
    }
}

/// The trailing sort menu: (on Watched) release vs. watched date, with the order
/// direction at the bottom.
struct ListSortMenu: View {
    @Binding var ascending: Bool
    @Binding var watchedSortKey: WatchedSortKey
    let showsWatchedSortKey: Bool

    var body: some View {
        Menu {
            if showsWatchedSortKey {
                Picker("Sort By", selection: $watchedSortKey) {
                    Text(WatchedSortKey.releaseDate.title).tag(WatchedSortKey.releaseDate)
                    Text(WatchedSortKey.dateWatched.title).tag(WatchedSortKey.dateWatched)
                }
            }

            Picker("Order", selection: $ascending) {
                Text("Ascending").tag(true)
                Text("Descending").tag(false)
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }
}

#Preview("Title label") {
    VStack(spacing: 20) {
        ListTitleLabel(name: "Watch List", color: .appAccent, count: 12)
        ListTitleLabel(name: "Watched",
                       color: Color(red255: 90, green255: 200, blue255: 250), count: 1)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

#Preview("Sort menu — Watched") {
    @Previewable @State var ascending = false
    @Previewable @State var key: WatchedSortKey = .dateWatched
    ListSortMenu(ascending: $ascending, watchedSortKey: $key, showsWatchedSortKey: true)
        .tint(.appAccent)
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
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
    .preferredColorScheme(.dark)
}
