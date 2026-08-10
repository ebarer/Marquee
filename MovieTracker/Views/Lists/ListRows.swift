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
                        if let stars = section.ratingStars {
                            RatingStars(rating: stars, starSize: 15, tint: listColor)
                        } else {
                            Text(section.title)
                                .foregroundStyle(listColor)
                        }
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
            let firstEdge: Visibility = (!hasHeader && index == 0) ? .hidden : .automatic
            let lastEdge: Visibility = index == entries.count - 1 ? .hidden : .automatic
            Group {
                if entry.mediaType == .tv {
                    if isWatched {
                        watchedSeasonRow(entry)       // a completed season in the Watched list
                    } else if entry.seasonNumber != nil {
                        trackedSeasonRow(entry)       // a Watch List / custom-list show, shown as its next season
                    } else {
                        showRow(entry)                // an untracked show (e.g. fully watched on a custom list)
                    }
                } else {
                    movieRow(entry)
                }
            }
            .listRowSeparator(lastEdge, edges: .bottom)
            // Hide the first row's top separator when it has no header above it.
            .listRowSeparator(firstEdge, edges: .top)
        }
    }

    private func movieRow(_ entry: MediaSnapshot) -> some View {
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
            trailingActions: { deleteButton(entry) }
        )
    }

    private func showRow(_ entry: MediaSnapshot) -> some View {
        DetailLink(value: show(entry)) {
            ShowRow(show: show(entry), showsSeasonCount: false)
        }
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if isWatched {
                WatchListSwipeButton(key: key(entry))
            } else {
                WatchedSwipeButton(key: key(entry))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { deleteButton(entry) }
    }

    /// A completed season in the Watched list: tapping opens the show on that season, a
    /// trailing swipe un-watches the whole season.
    private func watchedSeasonRow(_ entry: MediaSnapshot) -> some View {
        DetailLink(value: show(entry, openingSeason: entry.seasonNumber)) {
            SeasonRowContent(entry: entry, tint: listColor)
        }
        // Multiple seasons of one show push equal `Show` values; opt out of selection so
        // tapping one doesn't stray-highlight another row that shares that value.
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { deleteButton(entry) }
    }

    /// A Watch List / custom-list show, represented by its next-incomplete season: same look
    /// as a Watched row (poster, "Season N • x of y", partial badge), tapping opens the show
    /// on that season, a trailing swipe removes it from the list.
    private func trackedSeasonRow(_ entry: MediaSnapshot) -> some View {
        DetailLink(value: show(entry, openingSeason: entry.seasonNumber)) {
            SeasonRowContent(entry: entry, tint: listColor)
        }
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { deleteButton(entry) }
    }

    private func deleteButton(_ entry: MediaSnapshot) -> some View {
        Button(role: .destructive) {
            delete(entry)
        } label: {
            Image(systemName: "trash")
                .tint(.red)
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
        guard isWatchList, let runtime = entry.runtime, runtime > 0 else { return nil }
        return "\(runtime / 60) hr \(runtime % 60) min"
    }

    private func movie(_ entry: MediaSnapshot) -> Movie {
        var movie = Movie(id: entry.tmdbID, title: entry.title)
        movie.poster = entry.posterPath
        movie.releaseDate = entry.releaseDate
        movie.runtime = entry.runtime
        return movie
    }

    private func show(_ entry: MediaSnapshot, openingSeason: Int? = nil) -> Show {
        var show = Show(id: entry.tmdbID, name: entry.title)
        show.poster = entry.posterPath
        show.firstAirDate = entry.releaseDate
        show.initialSeason = openingSeason
        return show
    }

    private func key(_ entry: MediaSnapshot) -> MediaKey {
        MediaKey(tmdbID: entry.tmdbID, mediaType: entry.mediaType, title: entry.title,
                 posterPath: entry.posterPath, releaseDate: entry.releaseDate,
                 runtime: entry.runtime, sortDate: entry.sortDate)
    }

    private func delete(_ entry: MediaSnapshot) {
        switch selection {
        case .watched:
            // A watched-season row clears that whole season; a movie clears its watched fact.
            if let season = entry.seasonNumber {
                store?.unwatchSeason(showID: entry.tmdbID, seasonNumber: season)
            } else {
                store?.unwatch(entry.persistentID)
            }
        case .list: store?.deleteEntry(entry.persistentID)
        case .viewed: store?.removeFromViewed(entry.persistentID)
        }
    }
}

/// The poster + "Season N • x of y Episodes" body shared by the Watched-list season rows
/// and the membership (Watch List / custom) tracked-season rows. Partial seasons get the
/// half-filled corner badge over the app's standard poster gradient.
private struct SeasonRowContent: View {
    let entry: MediaSnapshot
    var tint: Color = .appAccent

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBWrapper.imageURL(path: entry.posterPath,
                                                  size: PosterSize.w185.rawValue))
                .frame(width: 51, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    if isPartial {
                        PosterSymbolBadge(symbol: "circle.tophalf.filled",
                                          cornerRadius: 6, pointSize: 15, padding: 5)
                    }
                }
                .padding(.vertical, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let rating = entry.userRating, rating > 0 {
                    RatingStars(rating: rating, tint: tint)
                        .padding(.top, 1)
                }
            }
            Spacer()
        }
    }

    private var subtitle: String {
        guard let season = entry.seasonNumber else { return "" }
        guard let watched = entry.seasonWatched, let total = entry.seasonTotal, total > 0 else {
            return "Season \(season)"
        }
        let remaining = total - watched
        guard remaining > 0 else { return "Season \(season)" }
        return "Season \(season)  •  Ep. \(watched + 1) of \(total)"
    }

    private var isPartial: Bool {
        guard let watched = entry.seasonWatched, let total = entry.seasonTotal, total > 0 else { return false }
        return watched < total
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
        return MediaSnapshot(persistentID: entry.persistentModelID, tmdbID: id, mediaType: .movie,
                             title: title, posterPath: nil, releaseDate: nil, sortDate: nil,
                             seasonNumber: nil, seasonWatched: nil, seasonTotal: nil,
                             runtime: 120, dateWatched: nil, userRating: nil)
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

#Preview("Watched — grouped by stars") {
    // Mirrors SectionBuilder.groupByRating output: one section per star count, unrated last.
    let sections: [SectionSnapshot] = {
        let context = previewModelContainer.mainContext
        // Real MediaItem ids so the snapshots are valid; contents are throwaway.
        func snap(_ id: Int, _ title: String, rating: Double?) -> MediaSnapshot {
            let item = MediaItem(tmdbID: id, mediaType: .movie, title: title)
            item.userRating = rating
            item.watchedAt = .now
            context.insert(item)
            return MediaSnapshot(persistentID: item.persistentModelID, tmdbID: id, mediaType: .movie,
                                 title: title, posterPath: nil, releaseDate: nil, sortDate: nil,
                                 seasonNumber: nil, seasonWatched: nil, seasonTotal: nil,
                                 runtime: 120, dateWatched: .now, userRating: rating)
        }
        return [
            SectionSnapshot(id: DateComponents(year: 9010), title: "5 Stars",
                            entries: [snap(1, "Masterpiece", rating: 5)], isCollapsible: false,
                            ratingStars: 5),
            SectionSnapshot(id: DateComponents(year: 9009), title: "4.5 Stars",
                            entries: [snap(2, "Nearly Perfect", rating: 4.5)], isCollapsible: false,
                            ratingStars: 4.5),
            SectionSnapshot(id: DateComponents(year: 9002), title: "1 Star",
                            entries: [snap(3, "A Misfire", rating: 1)], isCollapsible: false,
                            ratingStars: 1),
            SectionSnapshot(id: DateComponents(year: 9000), title: "Unrated",
                            entries: [snap(4, "Not Yet Rated", rating: nil)], isCollapsible: false),
        ]
    }()
    NavigationStack {
        ListRows(sections: sections, selection: .watched, lists: [], listColor: ListDestination.watchedColor)
            .listStyle(.plain)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
