//
//  WatchListToolbar.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The navigation title: the list name (tinted with the list color) over a movie
/// count, flanked by a menu chevron.
struct WatchListTitleLabel: View {
    let name: String
    let color: Color
    let movieCount: Int

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 5) {
                // A hidden leading chevron balances the trailing one so the text
                // stays centered.
                chevron.hidden()
                Text(name)
                    .font(.headline)
                    .foregroundStyle(color)
                chevron
            }
            Text("^[\(movieCount) Movie](inflect: true)")
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

/// The title-menu list switcher: built-in lists on top, custom lists in the
/// middle, the Viewed history last.
struct WatchListTitleMenu: View {
    @Binding var selection: UUID?
    let topLists: [MovieList]
    let customLists: [MovieList]
    let viewedList: MovieList?

    var body: some View {
        Picker("List", selection: $selection) {
            ForEach(topLists) { list in
                Label(list.name, systemImage: ListSymbol.outline(list.symbol)).tag(Optional(list.uuid))
            }
        }

        if !customLists.isEmpty {
            Divider()
            Picker("Custom List", selection: $selection) {
                ForEach(customLists) { list in
                    Label {
                        Text(list.name)
                    } icon: {
                        // Emoji and the flip-prone smiley need a prebuilt image;
                        // ordinary symbols render fine via systemName.
                        if let image = ListSymbol.menuImage(list.symbol) {
                            Image(uiImage: image)
                        } else {
                            Image(systemName: ListSymbol.outline(list.symbol))
                                .foregroundStyle(list.color)
                        }
                    }
                    .tag(Optional(list.uuid))
                }
            }
        }

        if let viewedList {
            Divider()
            Picker("Viewed", selection: $selection) {
                Label(viewedList.name, systemImage: ListSymbol.outline(viewedList.symbol))
                    .tag(Optional(viewedList.uuid))
            }
        }
    }
}

/// The leading ellipsis menu: create/manage lists, then import/export the library.
struct WatchListActionsMenu: View {
    let canEditLists: Bool
    /// The Viewed list when it can be cleared (selected and non-empty); else nil.
    let clearableList: MovieList?
    let onNewList: () -> Void
    let onEditLists: () -> Void
    let onClear: (MovieList) -> Void
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

            if let clearableList {
                Divider()
                Button(role: .destructive) {
                    onClear(clearableList)
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

/// The trailing sort menu: order direction, plus (on lists that track a watched
/// date) the choice of release vs. watched date.
struct WatchListSortMenu: View {
    @Binding var ascending: Bool
    @Binding var watchedSortKey: WatchedSortKey
    let tracksWatchedDate: Bool

    var body: some View {
        Menu {
            Picker("Order", selection: $ascending) {
                Text("Ascending").tag(true)
                Text("Descending").tag(false)
            }

            if tracksWatchedDate {
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
