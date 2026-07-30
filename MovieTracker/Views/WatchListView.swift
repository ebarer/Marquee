//
//  WatchListView.swift
//  MovieTracker
//
//  The user's Watch List, backed by SwiftData (+ CloudKit). A toolbar toggle
//  flips between the "To Watch" and "Watched" collections; a sort menu flips
//  ascending/descending and (for Watched) chooses release date vs. date
//  watched. Swipe actions move entries between lists or remove them.
//

import SwiftUI
import SwiftData

enum WatchListCollection: Int, CaseIterable, Identifiable {
    case toWatch
    case watched

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .toWatch: return "To Watch"
        case .watched: return "Watched"
        }
    }

    var symbol: String {
        switch self {
        case .toWatch: return "bookmark"
        case .watched: return "checkmark.circle"
        }
    }

    var emptyMessage: String {
        switch self {
        case .toWatch: return "Movies you track will appear here."
        case .watched: return "Movies you mark as seen will appear here."
        }
    }
}

/// Sort key available for the Watched list (the To Watch list always sorts by release date).
enum WatchedSortKey: String {
    case releaseDate
    case dateWatched

    var title: String {
        switch self {
        case .releaseDate: return "Release Date"
        case .dateWatched: return "Date Watched"
        }
    }
}

struct WatchListView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [WatchListEntry]

    @State private var collection: WatchListCollection = .toWatch
    @AppStorage("watchListSortAscending") private var sortAscending = true
    @AppStorage("watchedSortKey") private var watchedSortKey: WatchedSortKey = .releaseDate

    // Remembers the last-viewed list and when it was last seen, so re-entering
    // the tab restores it — unless it's gone stale (defaults back to To Watch).
    @AppStorage("watchListLastCollection") private var lastCollectionRaw = WatchListCollection.toWatch.rawValue
    @AppStorage("watchListLastViewedAt") private var lastViewedAt = 0.0

    /// After this long away, the list resets to To Watch on the next visit.
    private static let staleInterval: TimeInterval = 3 * 60 * 60

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.entries) { entry in
                        NavigationLink(value: Movie(id: entry.movieID, title: entry.title)) {
                            WatchListRow(entry: entry, collection: collection, sortKey: watchedSortKey)
                        }
                        .listRowBackground(Color.appBackground)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            leadingAction(for: entry)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                remove(entry)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(collection.title)
        .toolbarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            Picker("List", selection: $collection) {
                ForEach(WatchListCollection.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView {
                    Label(collection.title, systemImage: collection.symbol)
                } description: {
                    Text(collection.emptyMessage)
                }
            }
        }
        .onAppear {
            // Restore the last-viewed list, unless it's been too long — then reset
            // to To Watch. Either way, mark this as the latest visit.
            let elapsed = Date.timeIntervalSinceReferenceDate - lastViewedAt
            let stored = WatchListCollection(rawValue: lastCollectionRaw) ?? .toWatch
            collection = elapsed > Self.staleInterval ? .toWatch : stored
            recordVisit()
        }
        .onChange(of: collection) { _, _ in
            recordVisit()
        }
    }

    /// Persists the current list and the time it was viewed.
    private func recordVisit() {
        lastCollectionRaw = collection.rawValue
        lastViewedAt = Date.timeIntervalSinceReferenceDate
    }

    // MARK: - Sorting menu

    private var sortMenu: some View {
        Menu {
            Picker("Order", selection: $sortAscending) {
                Text("Ascending").tag(true)
                Text("Descending").tag(false)
            }

            if collection == .watched {
                Picker("Sort By", selection: $watchedSortKey) {
                    Text(WatchedSortKey.releaseDate.title).tag(WatchedSortKey.releaseDate)
                    Text(WatchedSortKey.dateWatched.title).tag(WatchedSortKey.dateWatched)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Data

    /// A month/year group of entries, e.g. "May 2025".
    private struct MonthSection: Identifiable {
        let id: DateComponents
        let title: String
        let entries: [WatchListEntry]
    }

    /// Entries for the current collection, grouped into month/year sections and
    /// ordered (both sections and rows within them) per the ascending toggle.
    private var sections: [MonthSection] {
        let filtered = entries.filter { collection == .toWatch ? $0.tracked : $0.watched }

        let grouped = Dictionary(grouping: filtered) { entry -> DateComponents in
            let date = sortValue(for: entry)
            return Calendar.current.dateComponents([.year, .month], from: date)
        }

        let sortedKeys = grouped.keys.sorted { a, b in
            (a.year ?? 0, a.month ?? 0) < (b.year ?? 0, b.month ?? 0)
        }
        let orderedKeys = sortAscending ? sortedKeys : sortedKeys.reversed()

        return orderedKeys.map { key in
            let rows = (grouped[key] ?? []).sorted { sortValue(for: $0) < sortValue(for: $1) }
            let ordered = sortAscending ? rows : rows.reversed()
            let title = Calendar.current.date(from: key)
                .map { DateFormatter.sectionHeader.string(from: $0) } ?? "Unknown"
            return MonthSection(id: key, title: title, entries: Array(ordered))
        }
    }

    /// The date the current collection/sort key orders and groups by. Missing dates
    /// sort last in ascending order (they become `.distantFuture`).
    private func sortValue(for entry: WatchListEntry) -> Date {
        if collection == .watched, watchedSortKey == .dateWatched {
            return entry.dateWatched ?? .distantFuture
        }
        return entry.releaseDate ?? .distantFuture
    }

    // MARK: - Swipe actions

    @ViewBuilder
    private func leadingAction(for entry: WatchListEntry) -> some View {
        let movie = Movie(id: entry.movieID, title: entry.title)
        if collection == .toWatch {
            Button {
                WatchListStore.setWatched(true, for: movie, in: context)
            } label: {
                Label("Watched", systemImage: "checkmark.circle")
            }
            .tint(.green)
        } else {
            Button {
                WatchListStore.setTracked(true, for: movie, in: context)
            } label: {
                Label("To Watch", systemImage: "bookmark")
            }
            .tint(.appAccent)
        }
    }

    private func remove(_ entry: WatchListEntry) {
        context.delete(entry)
    }
}

// MARK: - Row

private struct WatchListRow: View {
    let entry: WatchListEntry
    let collection: WatchListCollection
    let sortKey: WatchedSortKey

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: entry.posterURL(.w185))
                .frame(width: 55, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    /// Watched rows sorted by date-watched surface that date; everything else
    /// shows the release date.
    private var subtitle: String? {
        if collection == .watched, sortKey == .dateWatched {
            return entry.dateWatched.map { "Watched \($0.toString())" }
        }
        return entry.releaseDate?.toString()
    }
}
