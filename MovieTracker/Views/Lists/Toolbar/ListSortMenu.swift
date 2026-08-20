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
    var listSortKeys: [ListSortKey] = ListSortKey.allCases
    var foldOlderMovies: Binding<Bool>?
    var foldOlderShows: Binding<Bool>?
    var mediaFilter: Binding<MediaTypeFilter>?
    var tint: Color = .appAccent

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
                    ForEach(listSortKeys, id: \.self) { key in
                        sortToggle(key, selection: listSortKey)
                    }
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
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(isFiltering ? Color.black : tint)
        }
        // On the menu rather than its label, so the fill is centred on the item the bar lays out.
        .filterOnBadge(isFiltering, size: DetailSearchBar.barItemCircle, color: tint)
        .menuActionDismissBehavior(.disabled)
        .accessibilityLabel("List Options")
    }

    private func label(_ filter: MediaTypeFilter) -> some View {
        Label(filter.title, systemImage: filter.symbol)
    }

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

// In the bar it actually lives in, since the fill has to land inside the item's glass circle.
private struct SortMenuBarPreview: View {
    @State private var mediaFilter: MediaTypeFilter
    @State private var ascending = true

    init(mediaFilter: MediaTypeFilter) {
        _mediaFilter = State(initialValue: mediaFilter)
    }

    var body: some View {
        NavigationStack {
            List(0..<20, id: \.self) { index in
                Text("Row \(index)")
            }
            .listStyle(.plain)
            .navigationTitle("Watched")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ListSortMenu(ascending: $ascending, listSortKey: .constant(.alphabetical),
                                 mediaFilter: $mediaFilter, tint: ListDestination.watchedColor)
                        .tint(ListDestination.watchedColor)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("In a bar — filtering") {
    SortMenuBarPreview(mediaFilter: .movies)
}

#Preview("In a bar — not filtering") {
    SortMenuBarPreview(mediaFilter: .all)
}
