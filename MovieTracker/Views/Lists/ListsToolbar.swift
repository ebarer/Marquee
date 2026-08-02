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

/// The leading ellipsis menu: create/manage lists, then import/export the library.
struct ListActionsMenu: View {
    let canEditLists: Bool
    let canClearViewed: Bool
    let onNewList: () -> Void
    let onEditLists: () -> Void
    let onClearViewed: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void

    var body: some View {
        Menu {
            Button {
                onNewList()
            } label: {
                Label("New List", systemImage: "plus")
            }

            if canEditLists {
                Button {
                    onEditLists()
                } label: {
                    Label("Edit Lists", systemImage: "pencil")
                }
            }

            if canClearViewed {
                Divider()
                Button(role: .destructive) {
                    onClearViewed()
                } label: {
                    Label("Clear Viewed", systemImage: "trash")
                }
                .tint(.red)
            }

            Divider()

            Button {
                onImport()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }

            Button {
                onExport()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            Section {
                Text(appInfo)
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    private var appInfo: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (version?, build?): return "\(version) (\(build))"
        case let (version?, nil): return version
        case let (nil, build?): return build
        default: return ""
        }
    }
}

/// The trailing sort menu: order direction, plus (on Watched) release vs. watched
/// date.
struct ListSortMenu: View {
    @Binding var ascending: Bool
    @Binding var watchedSortKey: WatchedSortKey
    let showsWatchedSortKey: Bool

    var body: some View {
        Menu {
            Picker("Order", selection: $ascending) {
                Text("Ascending").tag(true)
                Text("Descending").tag(false)
            }

            if showsWatchedSortKey {
                Picker("Sort By", selection: $watchedSortKey) {
                    Text(WatchedSortKey.releaseDate.title).tag(WatchedSortKey.releaseDate)
                    Text(WatchedSortKey.dateWatched.title).tag(WatchedSortKey.dateWatched)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }
}
