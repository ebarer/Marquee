//
//  PersistenceCoordinator+TV.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// TV watched progress. `WatchedEpisode` is the source of truth; seasons and shows derive from it.
extension PersistenceCoordinator {

    // MARK: - Reads

    func watchedEpisodeNumbers(showID: Int, season: Int) -> Set<Int> {
        WatchedEpisode.watchedNumbers(showTmdbID: showID, seasonNumber: season, in: context)
    }

    func isEpisodeWatched(showID: Int, season: Int, episode: Int) -> Bool {
        WatchedEpisode.find(showTmdbID: showID, seasonNumber: season, episodeNumber: episode, in: context) != nil
    }

    func episodeWatchedDate(showID: Int, season: Int, episode: Int) -> Date? {
        WatchedEpisode.find(showTmdbID: showID, seasonNumber: season, episodeNumber: episode, in: context)?.watchedAt
    }

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

    // A CloudKit import lands episode records in unordered batches, so absent ones can't disprove a
    // snapshot. Only growth can.
    private func completedSnapshotCovers(_ season: Season, showID: Int) -> Bool {
        guard let snapshot = WatchedSeason.find(showTmdbID: showID,
                                                seasonNumber: season.seasonNumber, in: context)
        else { return false }
        return snapshot.episodeCount >= season.episodeCount
    }

    // Only scheduled seasons count, so an ongoing show reads as watched until its next season airs.
    // Seasons before the resume point fall outside the intended run and don't hold it open.
    func isShowFullyWatched(_ show: Show) -> Bool {
        guard let resume = nextSeasonToWatch(show) else { return false }
        return isSeasonWatched(resume, showID: show.id)
    }

    // False when an incomplete season's episodes aren't loaded: there are no air dates to check.
    func isShowCaughtUp(_ show: Show, episodesBySeason: [Int: [Episode]] = [:]) -> Bool {
        caughtUpState(show, episodesBySeason: episodesBySeason) ?? false
    }

    // Nil when episodes aren't loaded. A cached flag must not be overwritten with false.
    func caughtUpState(_ show: Show, episodesBySeason: [Int: [Episode]] = [:]) -> Bool? {
        let seasons = show.scheduledSeasons
        guard !seasons.isEmpty else { return nil }
        guard hasWatchedEpisodes(show), !isShowFullyWatched(show) else { return false }
        // Seasons before the resume point are ones the viewer never intends to watch, so they
        // can't hold the show back from being caught up.
        guard let resume = nextSeasonToWatch(show)?.seasonNumber else { return false }
        for season in seasons where season.seasonNumber >= resume {
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

    func isShowWatchedCached(showID: Int) -> Bool {
        MediaItem.find(tmdbID: showID, mediaType: .tv, in: context)?.showWatched ?? false
    }

    func showProgress(showID: Int) -> ShowProgress {
        let item = MediaItem.find(tmdbID: showID, mediaType: .tv, in: context)
        return ShowProgress(isWatched: item?.showWatched == true,
                            isCaughtUp: item?.showCaughtUp == true,
                            hasProgress: hasWatchedEpisodes(showID: showID),
                            isTracked: isInWatchList(showID: showID))
    }

    func hasWatchedEpisodes(_ show: Show) -> Bool {
        hasWatchedEpisodes(showID: show.id)
    }

    func hasWatchedEpisodes(showID: Int) -> Bool {
        let count = (try? context.fetchCount(FetchDescriptor<WatchedEpisode>(
            predicate: #Predicate { $0.showTmdbID == showID }))) ?? 0
        return count > 0
    }

    func isInWatchList(showID: Int) -> Bool {
        MediaList.watchList(in: context)?.contains(showID, .tv) ?? false
    }

    func isWatchListDismissed(_ show: Show) -> Bool {
        MediaItem.find(key: show.mediaKey, in: context)?.watchListOptOut == true
    }

    func dismissFromWatchList(_ show: Show) {
        MediaItem.upsert(key: show.mediaKey, in: context).watchListOptOut = true
        MediaList.watchList(in: context)?.remove(key: show.mediaKey)
        reconcileMembership(show)
    }

    func restoreToWatchList(_ show: Show) {
        MediaItem.find(key: show.mediaKey, in: context)?.watchListOptOut = nil
        reconcileMembership(show)
    }

    func seasonWatchedDate(showID: Int, season: Int) -> Date? {
        WatchedSeason.find(showTmdbID: showID, seasonNumber: season, in: context)?.watchedAt
    }

    func setSeasonWatchedDate(_ date: Date, showID: Int, season: Int) {
        guard let watched = WatchedSeason.find(showTmdbID: showID, seasonNumber: season, in: context) else { return }
        watched.watchedAt = date
        save()
    }

    func seasonRating(showID: Int, season: Int) -> Double? {
        WatchedSeason.find(showTmdbID: showID, seasonNumber: season, in: context)?.userRating
    }

    func setSeasonRating(_ stars: Double?, showID: Int, season: Int) {
        guard let watched = WatchedSeason.find(showTmdbID: showID, seasonNumber: season, in: context) else { return }
        watched.userRating = stars.flatMap { $0 > 0 ? ($0 * 2).rounded() / 2 : nil }
        save()
    }

    func firstIncompleteSeason(_ show: Show) -> Season? {
        show.scheduledSeasons.first { !isSeasonWatched($0, showID: show.id) }
    }

    // Resuming starts where watching started, not at season 1: joining a long-running show at
    // season 20 skips the earlier gap, while watching season 1 later makes season 2 next.
    func nextSeasonToWatch(_ show: Show) -> Season? {
        let seasons = show.scheduledSeasons
        guard let start = seasons.firstIndex(where: { hasProgress(in: $0, showID: show.id) }) else {
            return seasons.first
        }
        let ahead = seasons[start...].first { !isSeasonWatched($0, showID: show.id) }
        // Nothing left ahead: hold the last season until a new one airs.
        return ahead ?? seasons.last
    }

    private func hasProgress(in season: Season, showID: Int) -> Bool {
        !watchedEpisodeNumbers(showID: showID, season: season.seasonNumber).isEmpty
            || isSeasonWatched(season, showID: showID)
    }

    // MARK: - Background refresh (new-season detection)

    func watchedShowIDs() -> [Int] {
        let all = (try? context.fetch(FetchDescriptor<WatchedEpisode>())) ?? []
        return Array(Set(all.map(\.showTmdbID)))
    }

    func refreshWatchedShows(ttl: TimeInterval = 60 * 60 * 24) async {
        for id in watchedShowIDs() {
            if Task.isCancelled { return }
            if await MediaCacheStore.shared.isShowFresh(id: id, ttl: ttl) { continue }
            // A fetch failure most likely means offline, so stop and retry next launch.
            guard let show = try? await TMDBWrapper.getShow(id: id) else { return }

            var tint: Color?
            if let url = show.posterURL(.w342),
               let data = try? await TMDBWrapper.imageData(from: url) {
                tint = Color.dominantColor(from: data)
            }
            await MediaCacheStore.shared.save(show, tint: tint)

            // Re-read: the save merges cached episodes back in, and reconciling needs them to date the tracked
            // season by its next unwatched episode.
            let merged = await MediaCacheStore.shared.loadShow(id: id)?.show ?? show
            reconcileSeasons(for: merged)
            reconcileMembership(merged)
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    // MARK: - Writes

    func setEpisodeWatched(_ watched: Bool, showID: Int, season: Int, episode: Int) {
        applyEpisode(watched, showID: showID, season: season, episode: episode)
        save()
    }

    func toggleEpisodeWatched(show: Show, season: Season, episodeNumber: Int) {
        let now = isEpisodeWatched(showID: show.id, season: season.seasonNumber, episode: episodeNumber)
        applyEpisode(!now, showID: show.id, season: season.seasonNumber, episode: episodeNumber)
        reconcileSeason(show: show, season: season, afterLocalEdit: true)
        reconcileMembership(show, episodesBySeason: [season.seasonNumber: season.episodes])
    }

    // Marking stops at today, so a season still airing stays partly watched and in progress.
    func setSeasonWatched(_ watched: Bool, show: Show, season: Season) {
        for number in episodeNumbers(for: season, airedOnly: watched) {
            applyEpisode(watched, showID: show.id, season: season.seasonNumber, episode: number)
        }
        reconcileSeason(show: show, season: season, afterLocalEdit: true)
        reconcileMembership(show, episodesBySeason: [season.seasonNumber: season.episodes])
    }

    func markNextEpisodeWatched(show: Show, season: Season) {
        let watched = watchedEpisodeNumbers(showID: show.id, season: season.seasonNumber)
        guard let next = nextUnwatchedEpisode(in: season, watched: watched) else { return }
        applyEpisode(true, showID: show.id, season: season.seasonNumber, episode: next)
        reconcileSeason(show: show, season: season, afterLocalEdit: true)
        reconcileMembership(show, episodesBySeason: [season.seasonNumber: season.episodes])
    }

    // With no episodes loaded there are no air dates to check, so numbering is assumed to run 1...episodeCount.
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

    // Marking stops at today and dates each newly-completed season to its finale.
    func setShowWatched(_ watched: Bool, show: Show, episodesBySeason: [Int: [Episode]] = [:]) async {
        let known = watched ? await hydrateAiringSeasons(show, known: episodesBySeason) : episodesBySeason
        for var season in show.scheduledSeasons {
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
        let merged = Dictionary(uniqueKeysWithValues: show.scheduledSeasons.map {
            ($0.seasonNumber, known[$0.seasonNumber] ?? $0.episodes)
        })
        reconcileMembership(show, episodesBySeason: merged)
    }

    // Earlier seasons are provably finished, and fetching every one costs a request each.
    private func hydrateAiringSeasons(_ show: Show,
                                      known: [Int: [Episode]]) async -> [Int: [Episode]] {
        let seasons = show.scheduledSeasons
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

    func unwatchSeason(showID: Int, seasonNumber: Int) {
        for episode in WatchedEpisode.all(showTmdbID: showID, in: context)
        where episode.seasonNumber == seasonNumber {
            context.delete(episode)
        }
        if let snapshot = WatchedSeason.find(showTmdbID: showID, seasonNumber: seasonNumber, in: context) {
            watchedMemory.remember(snapshot)
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

    func resolveShow(id: Int) async -> Show? {
        if let cached = await MediaCacheStore.shared.loadShow(id: id)?.show { return cached }
        return try? await TMDBWrapper.getShow(id: id)
    }

    func reconcile(showID: Int, editedSeason: Int? = nil) async {
        guard let show = await resolveShow(id: showID) else { return }
        reconcileSeasons(for: show, editedSeason: editedSeason)
        reconcileMembership(show)
    }

    func setSeasonWatched(_ watched: Bool, showID: Int, seasonNumber: Int) async {
        guard let show = await resolveShow(id: showID),
              let season = show.regularSeasons.first(where: { $0.seasonNumber == seasonNumber })
        else { return }
        setSeasonWatched(watched, show: show, season: season)
    }

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

    func setShowWatched(_ watched: Bool, showID: Int) async {
        guard let show = await resolveShow(id: showID) else { return }
        await setShowWatched(watched, show: show)
    }

    // `editedSeason` is the one that changed, whose episode records can be trusted.
    func reconcileSeasons(for show: Show, editedSeason: Int? = nil) {
        for season in show.regularSeasons {
            reconcileSeason(show: show, season: season,
                            afterLocalEdit: season.seasonNumber == editedSeason)
        }
        save()
    }

    // Fully watched leaves the Watch List, in progress joins it, and `TrackedSeason` follows the
    // season to resume at.
    func reconcileMembership(_ show: Show, episodesBySeason: [Int: [Episode]] = [:]) {
        let key = show.mediaKey
        let existing = TrackedSeason.find(showTmdbID: show.id, in: context)

        // The single choke point after any episode, season or show mutation, so the caches never drift.
        let fullyWatched = isShowFullyWatched(show)
        setShowWatchedCache(fullyWatched, show: show)
        setShowCaughtUpCache(fullyWatched ? false : caughtUpState(show, episodesBySeason: episodesBySeason),
                             show: show)

        if fullyWatched {
            MediaList.watchList(in: context)?.remove(key: key)
            if let existing { context.delete(existing) }
            save()
            return
        }

        // Any watched episode makes the show to-watch, unless the user dismissed it. The opt-out sticks
        // until they add it back.
        let optedOut = MediaItem.find(key: key, in: context)?.watchListOptOut == true
        if !optedOut, !WatchedEpisode.all(showTmdbID: show.id, in: context).isEmpty {
            MediaList.ensureWatchList(in: context).add(key: key)
        }

        guard let season = nextSeasonToWatch(show), isOnAnyList(show.id) else {
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

    // No save: callers batch. Storing `true` keeps a `MediaItem` alive; clearing prunes it if no
    // other fact remains.
    private func setShowWatchedCache(_ watched: Bool, show: Show) {
        if watched {
            MediaItem.upsert(key: show.mediaKey, in: context).showWatched = true
        } else if let item = MediaItem.find(key: show.mediaKey, in: context) {
            item.showWatched = nil
            item.pruneIfEmpty()
        }
    }

    // Nil means episodes couldn't settle it: keep what is stored rather than clearing a known-good flag.
    private func setShowCaughtUpCache(_ caughtUp: Bool?, show: Show) {
        guard let caughtUp else { return }
        if caughtUp {
            MediaItem.upsert(key: show.mediaKey, in: context).showCaughtUp = true
        } else if let item = MediaItem.find(key: show.mediaKey, in: context) {
            item.showCaughtUp = nil
            item.pruneIfEmpty()
        }
    }

    // With no episodes to read, keep the stored date; resetting to the premiere re-buckets a mid-season show.
    private func nextEpisodeDate(for season: Season, episodes: [Episode], watched: Set<Int>,
                                 existing: TrackedSeason?) -> Date? {
        if let next = nextUnwatchedEpisodeDate(episodes: episodes, watched: watched) { return next }
        if episodes.isEmpty, existing?.seasonNumber == season.seasonNumber,
           let known = existing?.nextEpisodeDate { return known }
        return season.airDate
    }

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

    // Without loaded episodes there is nothing to date-check, so the whole range is assumed.
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

    // A new snapshot takes a remembered date over `completedAt`; an existing one's date is never touched.
    private func reconcileSeason(show: Show, season: Season, completedAt: Date? = nil,
                                 afterLocalEdit: Bool = false) {
        let watchedCount = watchedEpisodeNumbers(showID: show.id, season: season.seasonNumber).count
        let existing = WatchedSeason.find(showTmdbID: show.id, seasonNumber: season.seasonNumber, in: context)

        let complete = season.episodeCount > 0 && watchedCount >= season.episodeCount
        guard complete else {
            // A snapshot carries a watched date and rating nothing else can re-derive, and its delete syncs.
            // Drop it only on a local unwatch, or once the season has outgrown it.
            if let existing, afterLocalEdit || existing.episodeCount < season.episodeCount {
                // Only a user's un-mark is worth remembering; a season that merely outgrew its snapshot is re-dated.
                if afterLocalEdit { watchedMemory.remember(existing) }
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
            let remembered = watchedMemory.takeSeason(showID: show.id,
                                                      seasonNumber: season.seasonNumber)
            let snapshot = WatchedSeason(
                showTmdbID: show.id, seasonNumber: season.seasonNumber,
                showName: show.name, seasonName: season.name,
                posterPath: poster, airDate: anchor, episodeCount: season.episodeCount,
                watchedAt: remembered?.watchedAt ?? completedAt ?? Date())
            snapshot.userRating = remembered?.userRating
            context.insert(snapshot)
        }
    }

    private func seasonFinaleDate(_ season: Season) -> Date? {
        season.episodes.compactMap(\.airDate).max() ?? season.airDate
    }
}
