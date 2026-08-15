//
//  ListSortMenu.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

struct ListSortMenu: View {
    @Binding var ascending: Bool
    var watchedSortKey: Binding<WatchedSortKey>?
    var listSortKey: Binding<ListSortKey>?
    var foldOlder: Binding<Bool>?
    var mediaFilter: Binding<MediaTypeFilter>?

    var body: some View {
        Menu {
            // Sort key — the primary choices, each with its own symbol. Toggles, not a Picker:
            // a Picker swallows the Section's header, and a Button can't show the checkmark
            // alongside its symbol the way a menu Toggle does.
            Section("Sort By") {
                if let watchedSortKey {
                    sortToggle(.dateWatched, selection: watchedSortKey)
                    sortToggle(.releaseDate, selection: watchedSortKey)
                    sortToggle(.rating, selection: watchedSortKey)
                }

                if let listSortKey {
                    sortToggle(.releaseDate, selection: listSortKey)
                    sortToggle(.dateAdded, selection: listSortKey)
                }
            }

            // Order — nested so it reads as a single row with the current value as subtitle.
            Menu {
                Picker("Order", selection: $ascending) {
                    Label("Ascending", systemImage: "arrow.up").tag(true)
                    Label("Descending", systemImage: "arrow.down").tag(false)
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
                    Picker("View", selection: mediaFilter) {
                        label(.all).tag(MediaTypeFilter.all)
                        label(.movies).tag(MediaTypeFilter.movies)
                        label(.tv).tag(MediaTypeFilter.tv)
                    }

                    if let foldOlder {
                        Section {
                            Toggle("Hide Older Titles", isOn: foldOlder)
                        }
                    }
                } label: {
                    Text("View")
                    Text(mediaFilter.wrappedValue.title)
                }
                .menuActionDismissBehavior(.disabled)
            }
        } label: {
            Label("List Options", systemImage: "line.3.horizontal.decrease")
        }
        .menuActionDismissBehavior(.disabled)
    }

    private func label(_ filter: MediaTypeFilter) -> some View { Label(filter.title, systemImage: filter.symbol) }

    /// One sort-key row, ticked while selected. Re-picking the current key is a no-op,
    /// so the group behaves like a radio set rather than independent switches.
    private func sortToggle<Key: SortKey>(_ key: Key, selection: Binding<Key>) -> some View {
        Toggle(isOn: Binding(get: { selection.wrappedValue == key },
                             set: { if $0 { selection.wrappedValue = key } })) {
            Label(key.title, systemImage: key.symbol)
        }
    }

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
