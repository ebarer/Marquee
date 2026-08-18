//
//  PersistenceCoordinator+TV.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// TV watched-progress: `WatchedEpisode` is the source of truth; a season is watched when
/// all its episodes are, a show when all its aired seasons are.
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
        let watched = watchedEpisodeNumbers(showID: showID, season: season.seasonNumber).count
        return watched >= season.episodeCount || completedSnapshotCovers(season, showID: showID)
    }

    /// Whether a `WatchedSeason` still vouches for the season. A CloudKit import lands episode
    /// records in unordered batches, so absent ones can't disprove a snapshot — only growth can.
    private func completedSnapshotCovers(_ season: Season, showID: Int) -> Bool {
        guard let snapshot = WatchedSeason.find(showTmdbID: showID,
                                                seasonNumber: season.seasonNumber, in: context)
        else { return false }
        return snapshot.episodeCount >= season.episodeCount
    }

    /// Every *aired* regular season is complete, so an ongoing show reads as watched until
    /// its next season actually airs — at which point it returns to the Watch List.
    func isShowFullyWatched(_ show: Show) -> Bool {
        let aired = show.regularSeasons.filter { $0.episodeCount > 0 }
        guard !aired.isEmpty else { return false }
        return aired.allSatisfy { isSeasonWatched($0, showID: show.id) }
    }

    /// Every aired *episode* is watched but unaired ones remain — caught up, not finished.
    /// False when an incomplete season's episodes aren't loaded: no air dates to check.
    func isShowCaughtUp(_ show: Show, episodesBySeason: [Int: [Episode]] = [:]) -> Bool {
        caughtUpState(show, episodesBySeason: episodesBySeason) ?? false
    }

    /// `isShowCaughtUp`, but nil when an incomplete season's episodes aren't loaded: with no air
    /// dates to check the answer is unknown, and a cached one must not be overwritten with false.
    func caughtUpState(_ show: Show, episodesBySeason: [Int: [Episode]] = [:]) -> Bool? {
        let seasons = show.regularSeasons
        guard !seasons.isEmpty else { return nil }
        guard hasWatchedEpisodes(show), !isShowFullyWatched(show) else { return false }
        for season in seasons {
            let watched = watchedEpisodeNumbers(showID: show.id, season: season.seasonNumber)
            if watched.count >= season.episodeCount { continue }
            let episodes = episodesBySeason[season.seasonNumber] ?? season.episodes
            guard !episodes.isEmpty else { return nil }
            if episodes.contains(where: { $0.hasAired && !watched.contains($0.episodeNumber) }) {
                return false
            }
        }
        return true
    }

    /// The persisted fully-watched flag, readable from `showID` alone — lets detail seed its
    /// checkmark on entry instead of computing (and animating) it once the payload arrives.
    func isShowWatchedCached(showID: Int) -> Bool {
        MediaItem.find(tmdbID: showID, mediaType: .tv, in: context)?.showWatched ?? false
    }

    /// Everything the show controls need, from persisted facts only — right on entry, and cheap
    /// enough to re-read on a store tick. `reconcileMembership` is what keeps it true.
    func showProgress(showID: Int) -> ShowProgress {
        let item = MediaItem.find(tmdbID: showID, mediaType: .tv, in: context)
        return ShowProgress(isWatched: item?.showWatched == true,
                            isCaughtUp: item?.showCaughtUp == true,
                            hasProgress: hasWatchedEpisodes(showID: showID),
                            isTracked: isInWatchList(showID: showID))
    }

    /// Whether the show has any watched episodes — the show is "in progress" and the
    /// bookmark's manual Watch List opt-out applies.
    func hasWatchedEpisodes(_ show: Show) -> Bool {
        hasWatchedEpisodes(showID: show.id)
    }

    /// `hasWatchedEpisodes` from the show id alone — the row/card badge reads it without a
    /// loaded show, so a partially-watched series can show its progress mark.
    func hasWatchedEpisodes(showID: Int) -> Bool {
        let count = (try? context.fetchCount(FetchDescriptor<WatchedEpisode>(
            predicate: #Predicate { $0.showTmdbID == showID }))) ?? 0
        return count > 0
    }

    /// Watch List membership from the show id alone (never creates the list).
    func isInWatchList(showID: Int) -> Bool {
        MediaList.watchList(in: context)?.contains(showID, .tv) ?? false
    }

    /// Whether the user has manually dismissed this show from the auto-managed Watch List.
    func isWatchListDismissed(_ show: Show) -> Bool {
        MediaItem.find(key: show.mediaKey, in: context)?.watchListOptOut == true
    }

    /// Remove an in-progress show from the Watch List and remember the choice, so watched
    /// progress no longer bounces it back on. Undo via `restoreToWatchList`.
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
        show.regularSeasons.first { $0.episodeCount > 0 && !isSeasonWatched($0, showID: show.id) }
    }

    // MARK: - Background refresh (new-season detection)

    /// Distinct shows with any watched progress — the natural "shows I'm following" set to
    /// poll for new seasons (no extra state needed; `WatchedEpisode` is the memory).
    func watchedShowIDs() -> [Int] {
        let all = (try? context.fetch(FetchDescriptor<WatchedEpisode>())) ?? []
        return Array(Set(all.map(\.showTmdbID)))
    }

    /// Re-fetch in-progress shows and reconcile, so a newly-aired season pulls the show back
    /// onto the Watch List without the user reopening it. Best-effort and TTL-gated.
    func refreshWatchedShows(ttl: TimeInterval = 60 * 60 * 24) async {
        for id in watchedShowIDs() {
            if Task.isCancelled { return }
            if await MediaCacheStore.shared.isShowFresh(id: id, ttl: ttl) { continue }
            // A fetch failure most likely means offline — stop, retry next launch/foreground.
            guard let show = try? await TMDBWrapper.getShow(id: id) else { return }

            var tint: Color?
            if let url = show.posterURL(.w342),
               let data = try? await TMDBWrapper.imageData(from: url) {
                tint = Color.dominantColor(from: data)
            }
            await MediaCacheStore.shared.save(show, tint: tint)

            // Re-read: the save merges cached episodes back in, and reconciling needs them to
            // date the tracked season by its next unwatched episode (the payload carries none).
            let merged = await MediaCacheStore.shared.loadShow(id: id)?.show ?? show
            reconcileSeasons(for: merged)
            reconcileMembership(merged)
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
        reconcileSeason(show: show, season: season, afterLocalEdit: true)
        reconcileMembership(show, episodesBySeason: [season.seasonNumber: season.episodes])
    }

    /// Mark (or clear) every episode of a season, then reconcile. Marking stops at today, so
    /// a season still airing stays partly watched and in progress on the Watch List.
    func setSeasonWatched(_ watched: Bool, show: Show, season: Season) {
        for number in episodeNumbers(for: season, airedOnly: watched) {
            applyEpisode(watched, showID: show.id, season: season.seasonNumber, episode: number)
        }
        reconcileSeason(show: show, season: season, afterLocalEdit: true)
        reconcileMembership(show, episodesBySeason: [season.seasonNumber: season.episodes])
    }

    /// Mark the season's next unwatched episode, then reconcile, so one swipe advances the
    /// tracked season by an episode.
    func markNextEpisodeWatched(show: Show, season: Season) {
        let watched = watchedEpisodeNumbers(showID: show.id, season: season.seasonNumber)
        guard let next = nextUnwatchedEpisode(in: season, watched: watched) else { return }
        applyEpisode(true, showID: show.id, season: season.seasonNumber, episode: next)
        reconcileSeason(show: show, season: season, afterLocalEdit: true)
        reconcileMembership(show, episodesBySeason: [season.seasonNumber: season.episodes])
    }

    /// The lowest-numbered aired episode still unwatched. With no episodes loaded there are no
    /// air dates to check, so the numbering is assumed to run 1...episodeCount.
    private func nextUnwatchedEpisode(in season: Season, watched: Set<Int>) -> Int? {
        guard season.episodes.isEmpty else {
            return season.episodes
                .filter { $0.hasAired && !watched.contains($0.episodeNumber) }
                .map(\.episodeNumber)
                .min()
        }
        guard season.episodeCount > 0 else { return nil }
        return (1...season.episodeCount).first { !watched.contains($0) }
    }

    /// Mark (or clear) an entire show, then reconcile. Marking stops at today and dates each
    /// newly-completed season to its finale; `episodesBySeason` supplies loaded episodes.
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
                            completedAt: watched ? seasonFinaleDate(season) : nil,
                            afterLocalEdit: true)
        }
        let merged = Dictionary(uniqueKeysWithValues: show.regularSeasons.map {
            ($0.seasonNumber, known[$0.seasonNumber] ?? $0.episodes)
        })
        reconcileMembership(show, episodesBySeason: merged)
    }

    /// Episodes for the air check, fetching only from the latest started season on — earlier
    /// seasons are provably finished, and fetching every one costs a request each.
    private func hydrateAiringSeasons(_ show: Show,
                                      known: [Int: [Episode]]) async -> [Int: [Episode]] {
        let seasons = show.regularSeasons
        guard let started = seasons.lastIndex(where: { !($0.airDate ?? .distantPast).inTheFuture })
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
        // Clearing a season leaves aired episodes unwatched, so neither flag can still hold.
        if let item = MediaItem.find(tmdbID: showID, mediaType: .tv, in: context) {
            item.showWatched = nil
            item.showCaughtUp = nil
            item.pruneIfEmpty()
        }
        save()
    }

    // MARK: - Id-only entry points

    /// The one place a show is resolved from its id for a write, so every id-only surface
    /// (list rows, episode detail) reaches the same reconcile the detail screens do.
    func resolveShow(id: Int) async -> Show? {
        if let cached = await MediaCacheStore.shared.loadShow(id: id)?.show { return cached }
        return try? await TMDBWrapper.getShow(id: id)
    }

    /// Re-sync a show after an id-only mutation. A show that won't resolve (offline, cold cache)
    /// self-heals on next open; `editedSeason` is the one to drop the snapshot of.
    func reconcile(showID: Int, editedSeason: Int? = nil) async {
        guard let show = await resolveShow(id: showID) else { return }
        reconcileSeasons(for: show, editedSeason: editedSeason)
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

    /// `markNextEpisodeWatched(show:season:)` from an id-only context (a list swipe). The
    /// season's episodes are fetched when the cached show payload carries none.
    func markNextEpisodeWatched(showID: Int, seasonNumber: Int) async {
        guard let show = await resolveShow(id: showID),
              var season = show.regularSeasons.first(where: { $0.seasonNumber == seasonNumber })
        else { return }
        if season.episodes.isEmpty,
           let full = try? await TMDBWrapper.getSeason(showID: showID, seasonNumber: seasonNumber) {
            season.episodes = full.episodes
            await MediaCacheStore.shared.cacheSeason(showID: showID, full)
        }
        markNextEpisodeWatched(show: show, season: season)
    }

    /// Mark (or clear) a whole show from an id-only context (a list swipe): resolves the
    /// show, then funnels into `setShowWatched(_:show:episodesBySeason:)`.
    func setShowWatched(_ watched: Bool, showID: Int) async {
        guard let show = await resolveShow(id: showID) else { return }
        await setShowWatched(watched, show: show)
    }

    /// Recompute every regular season's snapshot from the current episode records.
    /// `editedSeason` is the one just changed, whose episode records can be trusted.
    func reconcileSeasons(for show: Show, editedSeason: Int? = nil) {
        for season in show.regularSeasons {
            reconcileSeason(show: show, season: season,
                            afterLocalEdit: season.seasonNumber == editedSeason)
        }
        save()
    }

    /// The single membership entry point after any mutation: fully watched leaves the Watch
    /// List, in-progress joins it, and `TrackedSeason` follows the first incomplete season.
    func reconcileMembership(_ show: Show, episodesBySeason: [Int: [Episode]] = [:]) {
        let key = show.mediaKey
        let existing = TrackedSeason.find(showTmdbID: show.id, in: context)
        let incomplete = firstIncompleteSeason(show)
        let hasCompletable = show.regularSeasons.contains { $0.episodeCount > 0 }

        // Persist the show-level flags on every reconcile — this is the single choke point
        // after any episode/season/show mutation, so the caches never drift.
        let fullyWatched = incomplete == nil && hasCompletable
        setShowWatchedCache(fullyWatched, show: show)
        setShowCaughtUpCache(fullyWatched ? false : caughtUpState(show, episodesBySeason: episodesBySeason),
                             show: show)

        // Truly finished — watched and to-watch are mutually exclusive.
        if fullyWatched {
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
        let nextDate = nextEpisodeDate(for: season, episodes: episodes, watched: watched,
                                       existing: existing)
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

    /// As `setShowWatchedCache`, but nil means "episodes couldn't settle it" — keep what's
    /// stored rather than clearing a known-good flag on a payload-less reconcile.
    private func setShowCaughtUpCache(_ caughtUp: Bool?, show: Show) {
        guard let caughtUp else { return }
        if caughtUp {
            MediaItem.upsert(key: show.mediaKey, in: context).showCaughtUp = true
        } else if let item = MediaItem.find(key: show.mediaKey, in: context) {
            item.showCaughtUp = nil
            item.pruneIfEmpty()
        }
    }

    /// The tracked season's sort/bucket anchor. With no episodes to read, keep the date already
    /// stored for this season — resetting to the premiere re-buckets a mid-season show.
    private func nextEpisodeDate(for season: Season, episodes: [Episode], watched: Set<Int>,
                                 existing: TrackedSeason?) -> Date? {
        if let next = nextUnwatchedEpisodeDate(episodes: episodes, watched: watched) { return next }
        if episodes.isEmpty, existing?.seasonNumber == season.seasonNumber,
           let known = existing?.nextEpisodeDate { return known }
        return season.airDate
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

    /// The episode numbers a bulk mark should touch. `airedOnly` skips future-dated episodes;
    /// without loaded episodes there's nothing to date-check, so the whole range is assumed.
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

    /// Upsert or remove the season's Watched-list snapshot; only *completed* seasons appear.
    /// `completedAt` seeds a new snapshot only — an existing date is never clobbered.
    private func reconcileSeason(show: Show, season: Season, completedAt: Date? = nil,
                                 afterLocalEdit: Bool = false) {
        let watchedCount = watchedEpisodeNumbers(showID: show.id, season: season.seasonNumber).count
        let existing = WatchedSeason.find(showTmdbID: show.id, seasonNumber: season.seasonNumber, in: context)

        let complete = season.episodeCount > 0 && watchedCount >= season.episodeCount
        guard complete else {
            // A snapshot carries a watched date and rating nothing else can re-derive, and its
            // delete syncs. Drop it only on a local unwatch, or once the season has outgrown it.
            if let existing, afterLocalEdit || existing.episodeCount < season.episodeCount {
                context.delete(existing)
            }
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
