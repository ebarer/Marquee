//
//  PersistenceCoordinator+TV.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// TV watched-progress: `WatchedEpisode` is the source of truth; a season is watched when
/// all its episodes are, a show when all its (aired) seasons are. Completing a season writes
/// a `WatchedSeason` display snapshot for the Watched list.
extension PersistenceCoordinator {

    // MARK: - Reads

    func watchedEpisodeNumbers(showID: Int, season: Int) -> Set<Int> {
        WatchedEpisode.watchedNumbers(showTmdbID: showID, seasonNumber: season, in: context)
    }

    func isEpisodeWatched(showID: Int, season: Int, episode: Int) -> Bool {
        WatchedEpisode.find(showTmdbID: showID, seasonNumber: season, episodeNumber: episode, in: context) != nil
    }

    /// The date a single episode was marked watched (nil when unwatched).
    func episodeWatchedDate(showID: Int, season: Int, episode: Int) -> Date? {
        WatchedEpisode.find(showTmdbID: showID, seasonNumber: season, episodeNumber: episode, in: context)?.watchedAt
    }

    /// Edit a watched episode's date.
    func setEpisodeWatchedDate(_ date: Date, showID: Int, season: Int, episode: Int) {
        guard let watched = WatchedEpisode.find(showTmdbID: showID, seasonNumber: season,
                                                episodeNumber: episode, in: context) else { return }
        watched.watchedAt = date
        save()
    }

    func isSeasonWatched(_ season: Season, showID: Int) -> Bool {
        guard season.episodeCount > 0 else { return false }
        return watchedEpisodeNumbers(showID: showID, season: season.seasonNumber).count >= season.episodeCount
    }

    /// "Fully watched" means every *aired* regular season is complete. An ongoing show whose
    /// only remaining season hasn't aired yet reads as watched (caught up) — the checkmark
    /// stays filled until that next season actually airs, at which point it becomes incomplete
    /// again and returns to the Watch List.
    func isShowFullyWatched(_ show: Show) -> Bool {
        let aired = show.regularSeasons.filter { $0.episodeCount > 0 }
        guard !aired.isEmpty else { return false }
        return aired.allSatisfy { isSeasonWatched($0, showID: show.id) }
    }

    /// Every *episode* that has aired is watched, but unaired ones remain — the show is
    /// caught up rather than finished, so its checkmark reads as in-progress instead of
    /// claiming completion. Falls to false for an incomplete season whose episodes aren't
    /// loaded: without air dates there's nothing to date-check against.
    func isShowCaughtUp(_ show: Show, episodesBySeason: [Int: [Episode]] = [:]) -> Bool {
        let seasons = show.regularSeasons
        guard !seasons.isEmpty, !isShowFullyWatched(show), hasWatchedEpisodes(show) else { return false }
        return seasons.allSatisfy { season in
            let watched = watchedEpisodeNumbers(showID: show.id, season: season.seasonNumber)
            if watched.count >= season.episodeCount { return true }
            let episodes = episodesBySeason[season.seasonNumber] ?? season.episodes
            guard !episodes.isEmpty else { return false }
            return !episodes.contains { $0.hasAired && !watched.contains($0.episodeNumber) }
        }
    }

    /// The persisted fully-watched flag, readable from `showID` alone (no loaded show).
    /// Lets the detail screen seed its checkmark correctly on entry, before the show
    /// payload arrives, instead of computing — and animating — after the fact.
    func isShowWatchedCached(showID: Int) -> Bool {
        MediaItem.find(tmdbID: showID, mediaType: .tv, in: context)?.showWatched ?? false
    }

    /// Whether the show has any watched episodes — the show is "in progress" and the
    /// bookmark's manual Watch List opt-out applies.
    func hasWatchedEpisodes(_ show: Show) -> Bool {
        hasWatchedEpisodes(showID: show.id)
    }

    /// `hasWatchedEpisodes` from the show id alone — the row/card badge reads it without a
    /// loaded show, so a partially-watched series can show its progress mark.
    func hasWatchedEpisodes(showID: Int) -> Bool {
        !WatchedEpisode.all(showTmdbID: showID, in: context).isEmpty
    }

    /// Watch List membership from the show id alone (never creates the list).
    func isInWatchList(showID: Int) -> Bool {
        MediaList.watchList(in: context)?.contains(showID, .tv) ?? false
    }

    /// Whether the user has manually dismissed this show from the auto-managed Watch List.
    func isWatchListDismissed(_ show: Show) -> Bool {
        MediaItem.find(key: show.mediaKey, in: context)?.watchListOptOut == true
    }

    /// Manually remove an in-progress show from the Watch List and remember it, so watched
    /// progress no longer bounces it back on. Reconcile then drops its tracked-season row
    /// (unless it's on another list). Undo via `restoreToWatchList`.
    func dismissFromWatchList(_ show: Show) {
        MediaItem.upsert(key: show.mediaKey, in: context).watchListOptOut = true
        MediaList.watchList(in: context)?.remove(key: show.mediaKey)
        reconcileMembership(show)
    }

    /// Undo `dismissFromWatchList`: clear the opt-out and let reconcile re-add the show and
    /// re-establish tracking of its next-episode (active) season.
    func restoreToWatchList(_ show: Show) {
        MediaItem.find(key: show.mediaKey, in: context)?.watchListOptOut = nil
        reconcileMembership(show)
    }

    /// The stored completion date for a watched season (nil if the season isn't complete).
    func seasonWatchedDate(showID: Int, season: Int) -> Date? {
        WatchedSeason.find(showTmdbID: showID, seasonNumber: season, in: context)?.watchedAt
    }

    /// Edit a completed season's watched date (the Watched-list sort/date anchor).
    func setSeasonWatchedDate(_ date: Date, showID: Int, season: Int) {
        guard let watched = WatchedSeason.find(showTmdbID: showID, seasonNumber: season, in: context) else { return }
        watched.watchedAt = date
        save()
    }

    /// The user's star rating for a completed season (nil when unrated or not complete).
    func seasonRating(showID: Int, season: Int) -> Double? {
        WatchedSeason.find(showTmdbID: showID, seasonNumber: season, in: context)?.userRating
    }

    /// Set (or clear) a completed season's star rating; snaps to half-star steps to match
    /// `StarRating`. A season only carries a rating once complete (its `WatchedSeason` exists).
    func setSeasonRating(_ stars: Double?, showID: Int, season: Int) {
        guard let watched = WatchedSeason.find(showTmdbID: showID, seasonNumber: season, in: context) else { return }
        watched.userRating = stars.flatMap { $0 > 0 ? ($0 * 2).rounded() / 2 : nil }
        save()
    }

    /// The show's next-to-watch season: the first regular season with aired episodes that
    /// isn't fully watched. Nil when every aired season is complete (or none has aired).
    func firstIncompleteSeason(_ show: Show) -> Season? {
        show.regularSeasons.first { season in
            season.episodeCount > 0
                && watchedEpisodeNumbers(showID: show.id, season: season.seasonNumber).count < season.episodeCount
        }
    }

    // MARK: - Background refresh (new-season detection)

    /// Distinct shows with any watched progress — the natural "shows I'm following" set to
    /// poll for new seasons (no extra state needed; `WatchedEpisode` is the memory).
    func watchedShowIDs() -> [Int] {
        let all = (try? context.fetch(FetchDescriptor<WatchedEpisode>())) ?? []
        return Array(Set(all.map(\.showTmdbID)))
    }

    /// Re-fetch in-progress shows and reconcile membership, so a newly-aired season pulls the
    /// show back onto the Watch List (and drops its "caught up" checkmark) without the user
    /// reopening it. Best-effort and TTL-gated; safe to call at launch and on foreground.
    /// Episode air dates aren't in the base payload, so a re-added season's `nextEpisodeDate`
    /// falls back to the season start until the detail is next opened.
    func refreshWatchedShows(ttl: TimeInterval = 60 * 60 * 24) async {
        for id in watchedShowIDs() {
            if Task.isCancelled { return }
            if await MediaCacheStore.shared.isShowFresh(id: id, ttl: ttl) { continue }
            // A fetch failure most likely means offline — stop, retry next launch/foreground.
            guard let show = try? await TMDBWrapper.getShow(id: id) else { return }

            var tint: Color?
            if let url = show.posterURL(.w342),
               let data = try? await TMDBWrapper.imageData(from: url) {
                tint = Color.averageColor(from: data)
            }
            await MediaCacheStore.shared.save(show, tint: tint)

            reconcileSeasons(for: show)
            reconcileMembership(show)
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    // MARK: - Writes

    /// Toggle a single episode (used where only the episode is known, e.g. the episode
    /// detail); season completion is reconciled when the show/section next appears.
    func setEpisodeWatched(_ watched: Bool, showID: Int, season: Int, episode: Int) {
        applyEpisode(watched, showID: showID, season: season, episode: episode)
        save()
    }

    /// Toggle an episode and immediately reconcile its season's snapshot + the show's list
    /// membership (the caller has the season, so completion updates in place).
    func toggleEpisodeWatched(show: Show, season: Season, episodeNumber: Int) {
        let now = isEpisodeWatched(showID: show.id, season: season.seasonNumber, episode: episodeNumber)
        applyEpisode(!now, showID: show.id, season: season.seasonNumber, episode: episodeNumber)
        reconcileSeason(show: show, season: season)
        reconcileMembership(show, episodesBySeason: [season.seasonNumber: season.episodes])
    }

    /// Mark (or clear) every episode of a season, then reconcile its snapshot + membership.
    /// Marking stops at today — a season still airing ends up partly watched, so it stays
    /// in progress on the Watch List rather than completing.
    func setSeasonWatched(_ watched: Bool, show: Show, season: Season) {
        for number in episodeNumbers(for: season, airedOnly: watched) {
            applyEpisode(watched, showID: show.id, season: season.seasonNumber, episode: number)
        }
        reconcileSeason(show: show, season: season)
        reconcileMembership(show, episodesBySeason: [season.seasonNumber: season.episodes])
    }

    /// Mark (or clear) an entire show across its regular seasons, then reconcile membership
    /// (marking removes it from the Watch List; clearing lets it return as in-progress).
    /// Marking stops at today: episodes dated in the future are left unwatched, so a show
    /// still on air keeps its current season in progress and stays on the Watch List.
    /// Newly-completed seasons are dated to their finale rather than today;
    /// `episodesBySeason` supplies loaded episodes so both the air check and that date are
    /// accurate, and `hydrateAiringSeasons` fills in whatever the caller is missing.
    func setShowWatched(_ watched: Bool, show: Show, episodesBySeason: [Int: [Episode]] = [:]) async {
        let known = watched ? await hydrateAiringSeasons(show, known: episodesBySeason) : episodesBySeason
        for var season in show.regularSeasons {
            if let episodes = known[season.seasonNumber], !episodes.isEmpty {
                season.episodes = episodes
            }
            for number in episodeNumbers(for: season, airedOnly: watched) {
                applyEpisode(watched, showID: show.id, season: season.seasonNumber, episode: number)
            }
            reconcileSeason(show: show, season: season,
                            completedAt: watched ? seasonFinaleDate(season) : nil)
        }
        let merged = Dictionary(uniqueKeysWithValues: show.regularSeasons.map {
            ($0.seasonNumber, known[$0.seasonNumber] ?? $0.episodes)
        })
        reconcileMembership(show, episodesBySeason: merged)
    }

    /// Episodes per season for the air check, fetching the ones the caller doesn't have.
    /// Only the tail needs fetching: a season is provably finished the moment a later one
    /// has started airing, so everything before the latest started season is left alone
    /// (long-running shows would otherwise cost one request per season).
    private func hydrateAiringSeasons(_ show: Show,
                                      known: [Int: [Episode]]) async -> [Int: [Episode]] {
        let seasons = show.regularSeasons
        guard let started = seasons.lastIndex(where: { ($0.airDate ?? .distantPast) <= Date() })
        else { return known }

        var hydrated = known
        for season in seasons[started...] where hydrated[season.seasonNumber]?.isEmpty ?? true {
            if !season.episodes.isEmpty {
                hydrated[season.seasonNumber] = season.episodes
            } else if let full = try? await TMDBWrapper.getSeason(showID: show.id,
                                                                 seasonNumber: season.seasonNumber) {
                hydrated[season.seasonNumber] = full.episodes
                await MediaCacheStore.shared.cacheSeason(showID: show.id, full)
            }
        }
        return hydrated
    }

    /// Clear a whole season (its episodes + snapshot) — the Watched list's un-watch swipe.
    func unwatchSeason(showID: Int, seasonNumber: Int) {
        for episode in WatchedEpisode.all(showTmdbID: showID, in: context)
        where episode.seasonNumber == seasonNumber {
            context.delete(episode)
        }
        if let snapshot = WatchedSeason.find(showTmdbID: showID, seasonNumber: seasonNumber, in: context) {
            context.delete(snapshot)
        }
        // Clearing a season can only break "fully watched"; drop the cached flag.
        if let item = MediaItem.find(tmdbID: showID, mediaType: .tv, in: context) {
            item.showWatched = nil
            item.pruneIfEmpty()
        }
        save()
    }

    // MARK: - Id-only entry points

    /// The one place a show is resolved from its id for a write: prefer the warm on-disk
    /// cache, else fetch from TMDB. Every id-only surface (list rows, episode detail) loads
    /// through here, so they all reach the same reconcile the detail screens do.
    func resolveShow(id: Int) async -> Show? {
        if let cached = await MediaCacheStore.shared.loadShow(id: id)?.show { return cached }
        return try? await TMDBWrapper.getShow(id: id)
    }

    /// Re-sync a show's season snapshots + list membership after an id-only mutation that
    /// couldn't reconcile itself (e.g. a single episode toggle, or a season un-watch). No-op
    /// when the show can't be resolved (offline, cold cache) — it self-heals on next open.
    func reconcile(showID: Int) async {
        guard let show = await resolveShow(id: showID) else { return }
        reconcileSeasons(for: show)
        reconcileMembership(show)
    }

    /// Mark (or clear) a season from an id-only context (a list swipe): resolves the show,
    /// then funnels into `setSeasonWatched(_:show:season:)`.
    func setSeasonWatched(_ watched: Bool, showID: Int, seasonNumber: Int) async {
        guard let show = await resolveShow(id: showID),
              let season = show.regularSeasons.first(where: { $0.seasonNumber == seasonNumber })
        else { return }
        setSeasonWatched(watched, show: show, season: season)
    }

    /// Mark (or clear) a whole show from an id-only context (a list swipe): resolves the
    /// show, then funnels into `setShowWatched(_:show:episodesBySeason:)`.
    func setShowWatched(_ watched: Bool, showID: Int) async {
        guard let show = await resolveShow(id: showID) else { return }
        await setShowWatched(watched, show: show)
    }

    /// Recompute every regular season's snapshot from the current episode records — used
    /// when the show reappears (episodes may have been toggled from the episode detail).
    func reconcileSeasons(for show: Show) {
        for season in show.regularSeasons { reconcileSeason(show: show, season: season) }
        save()
    }

    /// Keep the Watch List and the show's `TrackedSeason` in sync with watched progress —
    /// the single membership entry point after any episode/season/show mutation:
    ///  - fully watched → leave the Watch List, drop the `TrackedSeason` (it lives in Watched now);
    ///  - in progress (≥1 watched episode) → ensure it's on the Watch List ("watching == to watch");
    ///  - on ≥1 list → track the first incomplete season (poster/date for its row);
    ///  - off every list with no progress → drop the `TrackedSeason` (row falls back to the whole show).
    /// `episodesBySeason` supplies the tracked season's episodes for the next-episode bucket date.
    func reconcileMembership(_ show: Show, episodesBySeason: [Int: [Episode]] = [:]) {
        let key = show.mediaKey
        let existing = TrackedSeason.find(showTmdbID: show.id, in: context)
        let incomplete = firstIncompleteSeason(show)
        let hasCompletable = show.regularSeasons.contains { $0.episodeCount > 0 }

        // Persist the fully-watched flag on every reconcile — this is the single choke
        // point after any episode/season/show mutation, so the cache never drifts.
        setShowWatchedCache(incomplete == nil && hasCompletable, show: show)

        // Truly finished — watched and to-watch are mutually exclusive.
        if incomplete == nil && hasCompletable {
            MediaList.watchList(in: context)?.remove(key: key)
            if let existing { context.delete(existing) }
            save()
            return
        }

        // Any watched episode makes the show "to watch" → ensure it's on the Watch List,
        // unless the user manually dismissed it (opt-out sticks until they add it back).
        let optedOut = MediaItem.find(key: key, in: context)?.watchListOptOut == true
        if !optedOut, !WatchedEpisode.all(showTmdbID: show.id, in: context).isEmpty {
            MediaList.ensureWatchList(in: context).add(key: key)
        }

        // A TrackedSeason only earns its keep while the show is on some list.
        guard let season = incomplete ?? show.regularSeasons.first, isOnAnyList(show.id) else {
            if let existing { context.delete(existing) }
            save()
            return
        }

        let watched = watchedEpisodeNumbers(showID: show.id, season: season.seasonNumber)
        let episodes = episodesBySeason[season.seasonNumber] ?? season.episodes
        let nextDate = nextUnwatchedEpisodeDate(episodes: episodes, watched: watched) ?? season.airDate
        let poster = season.poster ?? show.poster

        if let existing {
            existing.seasonNumber = season.seasonNumber
            existing.showName = show.name
            existing.posterPath = poster
            existing.episodeCount = season.episodeCount
            existing.nextEpisodeDate = nextDate
            existing.updatedAt = Date()
        } else {
            context.insert(TrackedSeason(
                showTmdbID: show.id, seasonNumber: season.seasonNumber, showName: show.name,
                posterPath: poster, episodeCount: season.episodeCount, nextEpisodeDate: nextDate))
        }
        save()
    }

    // MARK: - Internals

    /// Upsert or clear the show's cached fully-watched flag. Storing `true` keeps a
    /// `MediaItem` alive; clearing prunes it if no other fact remains. No save — callers batch.
    private func setShowWatchedCache(_ watched: Bool, show: Show) {
        if watched {
            MediaItem.upsert(key: show.mediaKey, in: context).showWatched = true
        } else if let item = MediaItem.find(key: show.mediaKey, in: context) {
            item.showWatched = nil
            item.pruneIfEmpty()
        }
    }

    /// Air date of the lowest-numbered unwatched episode — the show's list sort/bucket
    /// anchor. Nil when episodes aren't loaded (caller falls back to the season start).
    private func nextUnwatchedEpisodeDate(episodes: [Episode], watched: Set<Int>) -> Date? {
        episodes
            .filter { !watched.contains($0.episodeNumber) }
            .min { $0.episodeNumber < $1.episodeNumber }?
            .airDate
    }

    private func isOnAnyList(_ showID: Int) -> Bool {
        let raw = MediaType.tv.rawValue
        let count = (try? context.fetchCount(FetchDescriptor<ListEntry>(
            predicate: #Predicate { $0.tmdbID == showID && $0.mediaTypeRaw == raw }))) ?? 0
        return count > 0
    }

    /// The episode numbers a bulk mark should touch. Marking watched passes `airedOnly` so
    /// episodes dated in the future are left alone — you can't have seen them. Clearing
    /// passes false so stray records are always removed. Without loaded episodes there's
    /// nothing to date-check against, so the whole contiguous range is assumed.
    private func episodeNumbers(for season: Season, airedOnly: Bool) -> [Int] {
        guard !season.episodes.isEmpty else {
            return season.episodeCount > 0 ? Array(1...season.episodeCount) : []
        }
        return season.episodes.filter { !airedOnly || $0.hasAired }.map(\.episodeNumber)
    }

    private func applyEpisode(_ watched: Bool, showID: Int, season: Int, episode: Int) {
        let existing = WatchedEpisode.find(showTmdbID: showID, seasonNumber: season,
                                           episodeNumber: episode, in: context)
        if watched {
            if existing == nil {
                context.insert(WatchedEpisode(showTmdbID: showID, seasonNumber: season, episodeNumber: episode))
            }
        } else if let existing {
            context.delete(existing)
        }
    }

    /// Upsert or remove the season's Watched-list snapshot. The Watched list holds only
    /// *completed* seasons — a season appears once every episode is watched and is removed
    /// the moment it drops below complete (in-progress seasons live on the Watch List
    /// instead). No save — callers batch and save once.
    /// `completedAt` seeds a *new* snapshot's watched date (used when batch-marking a show so
    /// each season dates to its finale); an existing snapshot keeps its date, so a user's edit
    /// (or an earlier completion) is never clobbered. Nil falls back to now.
    private func reconcileSeason(show: Show, season: Season, completedAt: Date? = nil) {
        let watchedCount = watchedEpisodeNumbers(showID: show.id, season: season.seasonNumber).count
        let existing = WatchedSeason.find(showTmdbID: show.id, seasonNumber: season.seasonNumber, in: context)

        let complete = season.episodeCount > 0 && watchedCount >= season.episodeCount
        guard complete else {
            if let existing { context.delete(existing) }
            return
        }

        let poster = season.poster ?? show.poster
        let anchor = seasonFinaleDate(season)
        if let existing {
            existing.showName = show.name
            existing.seasonName = season.name
            existing.posterPath = poster
            existing.airDate = anchor
            existing.episodeCount = season.episodeCount
        } else {
            context.insert(WatchedSeason(
                showTmdbID: show.id, seasonNumber: season.seasonNumber,
                showName: show.name, seasonName: season.name,
                posterPath: poster, airDate: anchor, episodeCount: season.episodeCount,
                watchedAt: completedAt ?? Date()))
        }
    }

    /// The season's finale air date when episodes are loaded, else its start date.
    private func seasonFinaleDate(_ season: Season) -> Date? {
        season.episodes.compactMap(\.airDate).max() ?? season.airDate
    }
}
