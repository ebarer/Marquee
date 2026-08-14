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
    /// The confirmation a swipe is waiting on, and the row that raised it. ONE piece of state:
    /// a row carries only a single presentation of a kind — two would cancel each other out.
    @State private var pending: PendingConfirmation?

    private enum PendingConfirmation: Identifiable {
        /// Removing an in-progress show whose watched episodes would otherwise re-add it.
        case removeFromWatchList(MediaSnapshot)
        /// Marking a whole show, which sweeps every episode of every season.
        case showWatched(MediaSnapshot, watched: Bool)

        var entry: MediaSnapshot {
            switch self {
            case .removeFromWatchList(let entry): return entry
            case .showWatched(let entry, _): return entry
            }
        }

        var id: MediaSnapshot.ID { entry.id }

        var title: String {
            switch self {
            case .removeFromWatchList: return "Remove from Watch List?"
            case .showWatched(_, let watched): return watched ? "Mark Show Watched?" : "Mark Show Unwatched?"
            }
        }

        var message: String {
            switch self {
            case .removeFromWatchList:
                return "You've watched some episodes, so it stays on your Watch List automatically. Removing keeps it off until you add it back."
            case .showWatched(let entry, let watched):
                return watched
                    ? "This marks every episode of every season of \(entry.title) as watched."
                    : "This clears the watched date for every episode of every season of \(entry.title)."
            }
        }
    }

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
                            StarRating(display: stars, size: 15, tint: listColor)
                        } else {
                            Text(section.title)
                                .foregroundStyle(listColor)
                        }
                    }
                }
            }
        }
    }

    /// Tappable header for the collapsible "Older" bucket. Stays a section header so it pins
    /// like the month headers.
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
            // Anchored to the row it's asking about. The item-based dialog holds the change:
            // nothing is written until an action here runs.
            .confirmationDialog(Text(confirmation(for: entry)?.title ?? ""),
                                item: confirmationItem(for: entry),
                                titleVisibility: .visible) { pending in
                confirmationActions(pending)
            } message: { pending in
                Text(pending.message)
            }
        }
    }

    // MARK: - Swipe confirmation

    /// Non-nil only for the row that raised the confirmation, so the dialog presents from it.
    private func confirmationItem(for entry: MediaSnapshot) -> Binding<PendingConfirmation?> {
        Binding(get: { confirmation(for: entry) }, set: { pending = $0 })
    }

    private func confirmation(for entry: MediaSnapshot) -> PendingConfirmation? {
        pending?.entry.id == entry.id ? pending : nil
    }

    @ViewBuilder
    private func confirmationActions(_ pending: PendingConfirmation) -> some View {
        switch pending {
        case .removeFromWatchList(let entry):
            Button("Remove", role: .destructive) { dismiss(entry) }
        case .showWatched(let entry, let watched):
            Button(watched ? "Mark Watched" : "Mark Unwatched",
                   role: watched ? nil : .destructive) {
                applyShowWatched(entry, watched: watched)
            }
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
            // Custom lists badge the poster (watched / partially watched / to-watch) the
            // same way movie rows do.
            ShowRow(show: show(entry), showsSeasonCount: false, derivesStatus: isCustomList)
        }
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        // TV watched-state is episode-based, so toggle through the show model, not the movie
        // `watchedAt` flag. A full swipe raises the confirmation; it doesn't apply the change.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            ShowWatchedSwipeButton(showID: entry.tmdbID) { watched in
                pending = .showWatched(entry, watched: watched)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { deleteButton(entry) }
    }

    /// A completed season in the Watched list: tapping opens the show there, a trailing swipe
    /// un-watches it. No leading swipe — "add back" reads as confusing on a finished season.
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

    /// A Watch List / custom-list show shown as its next-incomplete season: tapping opens the
    /// show there, a leading swipe completes the season, a trailing swipe removes the show.
    private func trackedSeasonRow(_ entry: MediaSnapshot) -> some View {
        DetailLink(value: show(entry, openingSeason: entry.seasonNumber)) {
            SeasonRowContent(entry: entry, tint: listColor)
        }
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        // No leading swipe while the next episode is still to air — completing the season
        // would skip it, so the action has nothing to mark.
        .swipeActions(edge: .leading, allowsFullSwipe: !isAwaitingNextEpisode(entry)) {
            if !isAwaitingNextEpisode(entry) {
                SeasonWatchedSwipeButton(showID: entry.tmdbID, seasonNumber: entry.seasonNumber ?? 0)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { deleteButton(entry) }
    }

    // Deliberately NOT `role: .destructive`: that promises the row is going, so the cell
    // clears on tap and tears down its own dialog. The red tint looks the same, no promise.
    private func deleteButton(_ entry: MediaSnapshot) -> some View {
        Button {
            requestDelete(entry)
        } label: {
            Image(systemName: "trash")
        }
        .tint(.red)
    }

    @ViewBuilder
    private func leadingAction(_ entry: MediaSnapshot) -> some View {
        if isWatched {
            WatchListSwipeButton(movie: movie(entry))
        } else {
            WatchedSwipeButton(movie: movie(entry))
        }
    }

    /// The tracked season's next episode hasn't aired yet, so there's nothing to mark watched.
    private func isAwaitingNextEpisode(_ entry: MediaSnapshot) -> Bool {
        entry.nextEpisodeDate?.inTheFuture == true
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

    /// Removing an in-progress show from the Watch List can't just drop its `ListEntry` —
    /// watched episodes re-add it on the next reconcile — so confirm, then opt out.
    private func requestDelete(_ entry: MediaSnapshot) {
        if isWatchList, entry.mediaType == .tv, store?.hasWatchedEpisodes(show(entry)) == true {
            pending = .removeFromWatchList(entry)
        } else {
            delete(entry)
        }
    }

    /// Persist the manual Watch List opt-out. Resolve the show so reconcile keeps an accurate
    /// tracked season; fall back to the snapshot's show so the removal sticks offline.
    private func dismiss(_ entry: MediaSnapshot) {
        pending = nil
        guard let store else { return }
        let fallback = show(entry)
        Task { @MainActor in
            let show = await store.resolveShow(id: entry.tmdbID) ?? fallback
            store.dismissFromWatchList(show)
        }
    }

    private func delete(_ entry: MediaSnapshot) {
        switch selection {
        case .watched:
            // A watched-season row clears that whole season; a movie clears its watched fact.
            if let season = entry.seasonNumber {
                unwatchSeason(entry, season: season)
            } else {
                store?.unwatch(entry.persistentID)
            }
        case .list: store?.deleteEntry(entry.persistentID)
        case .viewed: store?.removeFromViewed(entry.persistentID)
        }
    }

    /// Apply a confirmed whole-show watched change through the shared id-only entry point.
    private func applyShowWatched(_ entry: MediaSnapshot, watched: Bool) {
        pending = nil
        guard let store else { return }
        Task { @MainActor in await store.setShowWatched(watched, showID: entry.tmdbID) }
    }

    /// Clear a completed season, then reconcile: un-watching an earlier season makes the show
    /// in-progress again, so it returns to the Watch List now, not on next open.
    private func unwatchSeason(_ entry: MediaSnapshot, season: Int) {
        guard let store else { return }
        store.unwatchSeason(showID: entry.tmdbID, seasonNumber: season)
        Task { @MainActor in await store.reconcile(showID: entry.tmdbID) }
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
                             nextEpisodeDate: nil, runtime: 120, dateWatched: nil, userRating: nil)
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
    // Mirrors SectionFormatter.byRating output: one section per star count, unrated last.
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
                                 nextEpisodeDate: nil, runtime: 120, dateWatched: .now, userRating: rating)
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
