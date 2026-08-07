//
//  ListRows.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The month/year grouped list for the current selection, rendered from Sendable snapshots.
struct ListRows: View {
    let sections: [SectionSnapshot]
    let selection: ListSelection
    let lists: [MediaList]
    let listColor: Color
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Environment(\.openDetail) private var openDetail

    /// iPad: `List(selection:)` fires even during sync re-renders that were swallowing in-row taps.
    @State private var tappedMovie: Movie?
    /// The "Older" archive bucket starts collapsed each visit.
    @State private var olderExpanded = false

    private var isWatchList: Bool {
        if case .list(let uuid) = selection { return lists.first { $0.uuid == uuid }?.isWatchList == true }
        return false
    }
    private var isViewed: Bool { selection == .viewed }
    private var isWatched: Bool { selection == .watched }
    private var isCustomList: Bool {
        if case .list = selection { return !isWatchList }
        return false
    }

    /// ScrollViewReader target for the collapsible "Older" section.
    private static let olderAnchor = "older-section"

    var body: some View {
        ScrollViewReader { proxy in
            listContent
                // Clear the floating tab bar so the last section isn't jammed against
                // it, and leave slack to scroll an expanded "Older" bucket into view.
                .contentMargins(.bottom, 24, for: .scrollContent)
                .onChange(of: olderExpanded) { _, expanded in
                    guard expanded else { return }
                    withAnimation { proxy.scrollTo(Self.olderAnchor, anchor: .top) }
                }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if openDetail == nil {
            List { sectionsContent }
        } else {
            List(selection: $tappedMovie) { sectionsContent }
                .onChange(of: tappedMovie) { _, movie in
                    guard let movie else { return }
                    openDetail?(AnyHashable(movie))
                    tappedMovie = nil
                }
        }
    }

    @ViewBuilder
    private var sectionsContent: some View {
        if isViewed {
            rows(for: sections.first?.entries ?? [], hasHeader: false)
        } else {
            ForEach(sections) { section in
                if section.isCollapsible {
                    Section {
                        if olderExpanded {
                            rows(for: section.entries, hasHeader: true)
                        }
                    } header: {
                        olderHeader(count: section.entries.count)
                    }
                    .id(Self.olderAnchor)
                } else if section.title.isEmpty {
                    rows(for: section.entries, hasHeader: false)
                } else {
                    Section {
                        rows(for: section.entries, hasHeader: true)
                    } header: {
                        Text(section.title)
                            .foregroundStyle(listColor)
                    }
                }
            }
        }
    }

    /// Tappable header for the collapsible "Older" bucket — a chevron that rotates
    /// with the expanded state plus the archived count. Stays a section header so it
    /// pins like the month headers.
    private func olderHeader(count: Int) -> some View {
        Button {
            withAnimation { olderExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text("Older (\(count))")
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(olderExpanded ? 90 : 0))
                Spacer()
            }
            .foregroundStyle(listColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func rows(for entries: [MediaSnapshot], hasHeader: Bool) -> some View {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            MovieListRow(
                movie: movie(entry),
                subtitle: subtitle(entry),
                showsSubtitle: !isViewed,
                duration: duration(entry),
                rating: rating(entry),
                ratingTint: listColor,
                status: status(entry),
                lists: lists,
                leadingActions: { leadingAction(entry) },
                trailingActions: {
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Image(systemName: "trash")
                            .tint(.red)
                    }
                }
            )
            .listRowSeparator(index == entries.count - 1 ? .hidden : .automatic, edges: .bottom)
            // Hide the first row's top separator when it has no header above it.
            .listRowSeparator(!hasHeader && index == 0 ? .hidden : .automatic, edges: .top)
        }
    }

    @ViewBuilder
    private func leadingAction(_ entry: MediaSnapshot) -> some View {
        if isWatched {
            WatchListSwipeButton(movie: movie(entry))
        } else {
            WatchedSwipeButton(movie: movie(entry))
        }
    }

    private func subtitle(_ entry: MediaSnapshot) -> String? {
        guard isWatched, let date = entry.dateWatched else { return nil }
        return "Watched \(date.toString())"
    }

    private func status(_ entry: MediaSnapshot) -> PosterStatus? {
        guard isCustomList else { return nil }
        if entry.dateWatched != nil { return .watched }
        if store?.isInWatchList(movie(entry)) == true { return .watchList }
        return nil
    }

    private func rating(_ entry: MediaSnapshot) -> Double? {
        (isWatched || (!isWatchList && !isViewed)) ? entry.userRating : nil
    }

    private func duration(_ entry: MediaSnapshot) -> String? {
        guard isWatchList, let runtime = entry.runtime else { return nil }
        return "\(runtime / 60) hr \(runtime % 60) min"
    }

    private func movie(_ entry: MediaSnapshot) -> Movie {
        var movie = Movie(id: entry.tmdbID, title: entry.title)
        movie.poster = entry.posterPath
        movie.releaseDate = entry.releaseDate
        movie.runtime = entry.runtime
        return movie
    }

    private func delete(_ entry: MediaSnapshot) {
        switch selection {
        case .list: store?.deleteEntry(entry.persistentID)
        case .watched: store?.unwatch(entry.persistentID)
        case .viewed: store?.removeFromViewed(entry.persistentID)
        }
    }
}

#Preview {
    ListRows(sections: [], selection: .watched, lists: [], listColor: .appAccent)
        .listStyle(.plain)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
}

#Preview("Older bucket") {
    let context = previewModelContainer.mainContext
    // Real ListEntry ids so the snapshots are valid; contents are throwaway.
    func snap(_ id: Int, _ title: String) -> MediaSnapshot {
        let entry = ListEntry(movie: Movie(id: id, title: title))
        context.insert(entry)
        return MediaSnapshot(persistentID: entry.persistentModelID, tmdbID: id, title: title,
                             posterPath: nil, releaseDate: nil, runtime: 120,
                             dateWatched: nil, userRating: nil)
    }
    let sections = [
        SectionSnapshot(id: DateComponents(year: 2026, month: 8), title: "August 2026",
                        entries: [snap(1, "New Release")], isCollapsible: false),
        SectionSnapshot(id: DateComponents(year: 2026, month: 7), title: "July 2026",
                        entries: [snap(2, "Still in Theatres")], isCollapsible: false),
        SectionSnapshot(id: SectionSnapshot.olderID, title: "Older",
                        entries: [snap(3, "Old One"), snap(4, "Old Two"), snap(5, "Old Three")],
                        isCollapsible: true),
    ]
    return NavigationStack {
        ListRows(sections: sections, selection: .list(UUID()), lists: [], listColor: .appAccent)
            .listStyle(.plain)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
