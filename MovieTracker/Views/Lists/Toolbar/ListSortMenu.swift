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
    var foldOlderMovies: Binding<Bool>?
    var foldOlderShows: Binding<Bool>?
    var mediaFilter: Binding<MediaTypeFilter>?

    // Used to style the button if actively filtering
    private var isFiltering: Bool {
        (mediaFilter?.wrappedValue ?? .all) != .all
    }

    var body: some View {
        Menu {
            Section("Sort By") {
                if let watchedSortKey {
                    sortToggle(.dateWatched, selection: watchedSortKey)
                    sortToggle(.releaseDate, selection: watchedSortKey)
                    sortToggle(.rating, selection: watchedSortKey)
                    sortToggle(.alphabetical, selection: watchedSortKey)
                }

                if let listSortKey {
                    sortToggle(.releaseDate, selection: listSortKey)
                    sortToggle(.dateAdded, selection: listSortKey)
                    sortToggle(.rating, selection: listSortKey)
                    sortToggle(.alphabetical, selection: listSortKey)
                }
            }

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

            if let mediaFilter {
                Menu {
                    Picker("View", selection: mediaFilter) {
                        label(.all).tag(MediaTypeFilter.all)
                        label(.movies).tag(MediaTypeFilter.movies)
                        label(.tv).tag(MediaTypeFilter.tv)
                    }

                    // A fold toggle only for the media types currently on screen.
                    Section {
                        if let foldOlderMovies, mediaFilter.wrappedValue != .tv {
                            Toggle("Hide Older Movies", isOn: foldOlderMovies)
                        }
                        if let foldOlderShows, mediaFilter.wrappedValue != .movies {
                            Toggle("Hide Older Shows", isOn: foldOlderShows)
                        }
                    }
                } label: {
                    Text("View")
                    Text(mediaFilter.wrappedValue.title)
                }
                .menuActionDismissBehavior(.disabled)
            }
        } label: {
            Label("List Options", systemImage: isFiltering
                  ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
        }
        .menuActionDismissBehavior(.disabled)
    }

    private func label(_ filter: MediaTypeFilter) -> some View { Label(filter.title, systemImage: filter.symbol) }

    /// One sort-key row, ticked while selected. Re-picking the current key is a no-op, so the
    /// group behaves like a radio set; switching keys also resets the order to that key's default.
    private func sortToggle<Key: SortKey>(_ key: Key, selection: Binding<Key>) -> some View {
        Toggle(isOn: Binding(get: { selection.wrappedValue == key },
                             set: { isOn in
                                 guard isOn, selection.wrappedValue != key else { return }
                                 selection.wrappedValue = key
                                 ascending = key.defaultAscending
                             })) {
            Label(key.title, systemImage: key.symbol)
        }
    }

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
    @Previewable @State var key: ListSortKey = .alphabetical
    ListSortMenu(ascending: $ascending, listSortKey: $key)
        .tint(.appAccent)
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}

#Preview("Sort menu — Watch List") {
    @Previewable @State var ascending = true
    @Previewable @State var key: ListSortKey = .releaseDate
    @Previewable @State var foldMovies = true
    @Previewable @State var foldShows = false
    @Previewable @State var mediaFilter: MediaTypeFilter = .all
    ListSortMenu(ascending: $ascending, listSortKey: $key, foldOlderMovies: $foldMovies,
                 foldOlderShows: $foldShows, mediaFilter: $mediaFilter)
        .tint(.appAccent)
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
