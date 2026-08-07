//
//  ListsToolbar.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A real `MediaList` (Watch List or custom) or the derived Watched / Viewed queries.
enum ListSelection: Hashable {
    case list(UUID)
    case watched
    case viewed
}

/// A `ListSelection` resolved to the identity and contents the Lists screen needs.
struct ListDestination {
    let selection: ListSelection
    let name: String
    let color: Color
    let symbol: String
    let emptyDescription: String
    let list: MediaList?

    static let watchedColor = Color(red255: 90, green255: 200, blue255: 250)
    static let viewedColor = Color.gray

    static func resolve(_ selection: ListSelection, lists: [MediaList]) -> ListDestination {
        switch selection {
        case .list(let uuid):
            let list = lists.first { $0.uuid == uuid }
            return ListDestination(
                selection: selection,
                name: list?.name ?? "Lists",
                color: list?.color ?? .appAccent,
                symbol: list?.symbol ?? "list.bullet",
                emptyDescription: list.map {
                    $0.isWatchList ? "Movies you want to watch will appear here."
                                   : "Movies you add to “\($0.name)” will appear here."
                } ?? "",
                list: list)
        case .watched:
            return ListDestination(
                selection: selection, name: "Watched", color: watchedColor,
                symbol: "checkmark.rectangle.stack",
                emptyDescription: "Movies you mark watched will appear here.", list: nil)
        case .viewed:
            return ListDestination(
                selection: selection, name: "Viewed", color: viewedColor,
                symbol: "clock.arrow.circlepath",
                emptyDescription: "Movies you browse will appear here.", list: nil)
        }
    }

    @MainActor
    func movieCount(using store: PersistenceCoordinator?) -> Int {
        switch selection {
        case .list: return (list?.entries ?? []).count
        case .watched: return store?.watchedCount ?? 0
        case .viewed: return store?.viewedCount ?? 0
        }
    }

    func sectionSource(watchedByDate: Bool, listByDateAdded: Bool) -> SectionSource? {
        switch selection {
        case .list(let uuid): return list != nil ? .list(uuid, byDateAdded: listByDateAdded) : nil
        case .watched: return .watched(byWatchedDate: watchedByDate)
        case .viewed: return .viewed
        }
    }
}

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

struct ListSortMenu: View {
    @Binding var ascending: Bool
    var watchedSortKey: Binding<WatchedSortKey>?
    var listSortKey: Binding<ListSortKey>?

    var body: some View {
        Menu {
            if let watchedSortKey {
                Picker("Sort By", selection: watchedSortKey) {
                    Text(WatchedSortKey.releaseDate.title).tag(WatchedSortKey.releaseDate)
                    Text(WatchedSortKey.dateWatched.title).tag(WatchedSortKey.dateWatched)
                }
            }

            if let listSortKey {
                Picker("Sort By", selection: listSortKey) {
                    Text(ListSortKey.releaseDate.title).tag(ListSortKey.releaseDate)
                    Text(ListSortKey.dateAdded.title).tag(ListSortKey.dateAdded)
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
        ListTitleLabel(name: "Watched", color: ListDestination.watchedColor, count: 1)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

#Preview("Sort menu — Watched") {
    @Previewable @State var ascending = false
    @Previewable @State var key: WatchedSortKey = .dateWatched
    ListSortMenu(ascending: $ascending, watchedSortKey: $key)
        .tint(.appAccent)
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}

#Preview("Sort menu — List") {
    @Previewable @State var ascending = true
    @Previewable @State var key: ListSortKey = .dateAdded
    ListSortMenu(ascending: $ascending, listSortKey: $key)
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
