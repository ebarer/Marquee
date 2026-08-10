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
                    $0.isWatchList ? "Movies & TV you want to watch will appear here."
                                   : "Movies & TV you add to “\($0.name)” will appear here."
                } ?? "",
                list: list)
        case .watched:
            return ListDestination(
                selection: selection, name: "Watched", color: watchedColor,
                symbol: "checkmark.rectangle.stack",
                emptyDescription: "Movies & TV you mark watched will appear here.", list: nil)
        case .viewed:
            return ListDestination(
                selection: selection, name: "Viewed", color: viewedColor,
                symbol: "clock.arrow.circlepath",
                emptyDescription: "Movies & TV you browse will appear here.", list: nil)
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

    func listRequest(watchedSort: WatchedSortKey, listByDateAdded: Bool, listFoldOlder: Bool) -> ListRequest? {
        switch selection {
        case .list(let uuid): return list != nil ? .list(uuid, byDateAdded: listByDateAdded, foldOlder: listFoldOlder) : nil
        case .watched: return .watched(sort: watchedSort)
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
            // Neutral "Title" since lists now mix movies, shows, and seasons.
            Text("^[\(count) Title](inflect: true)")
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
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        Picker("List", selection: $selection) {
            if let watchList {
                Label {
                    titleText(watchList.name, watchList.entries?.count ?? 0)
                } icon: {
                    Image(systemName: ListSymbol.outline(watchList.symbol))
                }
                .tag(ListSelection.list(watchList.uuid))
            }
            Label {
                titleText("Watched", store?.watchedCount ?? 0)
            } icon: {
                Image(systemName: "checkmark.rectangle.stack")
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
            Label {
                titleText("Viewed", store?.viewedCount ?? 0)
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .tag(ListSelection.viewed)
        }
    }

    /// The list name with its count trailing.
    private func titleText(_ name: String, _ count: Int) -> Text {
        Text("\(name) (\(count))")
    }
}

struct ListSortMenu: View {
    @Binding var ascending: Bool
    var watchedSortKey: Binding<WatchedSortKey>?
    var listSortKey: Binding<ListSortKey>?
    var foldOlder: Binding<Bool>?
    var mediaFilter: Binding<MediaTypeFilter>?

    var body: some View {
        Menu {
            // Sort key — the primary choices, each with its own symbol.
            if let watchedSortKey {
                Picker("Sort", selection: watchedSortKey) {
                    label(WatchedSortKey.dateWatched).tag(WatchedSortKey.dateWatched)
                    label(WatchedSortKey.releaseDate).tag(WatchedSortKey.releaseDate)
                    label(WatchedSortKey.rating).tag(WatchedSortKey.rating)
                }
                .labelsHidden()
            }

            if let listSortKey {
                Picker("Sort", selection: listSortKey) {
                    label(ListSortKey.releaseDate).tag(ListSortKey.releaseDate)
                    label(ListSortKey.dateAdded).tag(ListSortKey.dateAdded)
                }
                .labelsHidden()
            }

            // Order — nested so it reads as a single row with the current value as subtitle.
            Menu {
                Picker("Order", selection: $ascending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
                .labelsHidden()
            } label: {
                Text("Order")
                Text(ascending ? "Ascending" : "Descending")
            }
            .menuActionDismissBehavior(.disabled)

            // View — Movies / TV / Both; the row's subtitle reflects the current choice.
            if let mediaFilter {
                Menu {
                    viewButton(.all, filter: mediaFilter, subtitle: "Movies & TV Shows")
                    viewButton(.movies, filter: mediaFilter)
                    viewButton(.tv, filter: mediaFilter)
                } label: {
                    Text("View")
                    Text(mediaFilter.wrappedValue.title)
                }
                .menuActionDismissBehavior(.disabled)
            }

            if let foldOlder {
                Section {
                    Toggle("Hide Old Titles", isOn: foldOlder)
                }
            }
        } label: {
            Label("List Options", systemImage: "line.3.horizontal.decrease")
        }
        .menuActionDismissBehavior(.disabled)
    }

    private func label(_ key: WatchedSortKey) -> some View { Label(key.title, systemImage: key.symbol) }
    private func label(_ key: ListSortKey) -> some View { Label(key.title, systemImage: key.symbol) }
    private func label(_ filter: MediaTypeFilter) -> some View { Label(filter.title, systemImage: filter.symbol) }

    /// A View-menu option as a Button (Pickers don't render option subtitles): title,
    /// optional subtitle, and a leading symbol that becomes a checkmark when selected.
    @ViewBuilder
    private func viewButton(_ option: MediaTypeFilter, filter: Binding<MediaTypeFilter>,
                            subtitle: String? = nil) -> some View {
        let selected = filter.wrappedValue == option
        Button {
            filter.wrappedValue = option
        } label: {
            Text(option.title)
            if let subtitle { Text(subtitle) }
            Image(systemName: selected ? "checkmark" : option.symbol)
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
    @Previewable @State var key: WatchedSortKey = .rating
    @Previewable @State var mediaFilter: MediaTypeFilter = .all
    ListSortMenu(ascending: $ascending, watchedSortKey: $key, mediaFilter: $mediaFilter)
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

#Preview("Sort menu — Watch List") {
    @Previewable @State var ascending = true
    @Previewable @State var key: ListSortKey = .releaseDate
    @Previewable @State var fold = true
    ListSortMenu(ascending: $ascending, listSortKey: $key, foldOlder: $fold)
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
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
