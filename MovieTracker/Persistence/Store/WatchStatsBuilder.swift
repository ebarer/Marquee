//
//  WatchStatsBuilder.swift
//  MovieTracker
//

import Foundation
import SwiftData

// Bucketed in UTC because `MediaItem.floatingDay` stores a watched day as UTC midnight, and every
// other date grouping in the app reads it back the same way.
extension ListCoordinator {
    func stats(scope: WatchStats.Scope) -> WatchStats {
        let calendar = DateFormatter.utcCalendar
        var stats = WatchStats()
        stats.scope = scope

        let movies = watchedMovieFacts()
        let seasons = watchedSeasonFacts()
        let episodes = watchedEpisodeFacts()

        stats.availableYears = Set(
            movies.map { calendar.component(.year, from: $0.watchedAt) }
                + seasons.map { calendar.component(.year, from: $0.watchedAt) }
                + episodes.map { calendar.component(.year, from: $0.watchedAt) }
        ).sorted(by: >)

        func inScope(_ date: Date) -> Bool {
            guard case .year(let year) = scope else { return true }
            return calendar.component(.year, from: date) == year
        }

        var months = (1...12).map { WatchStats.MonthBucket(month: $0, movies: 0, episodes: 0) }
        var ratings: [Int: Int] = [:]
        var ratingTotal = 0.0
        var activeDays: Set<Date> = []

        for movie in movies where inScope(movie.watchedAt) {
            stats.moviesWatched += 1
            if let runtime = movie.runtime, runtime > 0 {
                stats.movieMinutes += runtime
            } else {
                stats.moviesMissingRuntime += 1
            }
            let month = calendar.component(.month, from: movie.watchedAt)
            months[month - 1].movies += 1
            if let rating = movie.rating, rating > 0 {
                ratings[Int((rating * 2).rounded()), default: 0] += 1
                ratingTotal += rating
                stats.ratedCount += 1
            }
            if let day = calendar.dateInterval(of: .day, for: movie.watchedAt)?.start {
                activeDays.insert(day)
            }
        }

        for season in seasons where inScope(season.watchedAt) {
            stats.seasonsCompleted += 1
            if let rating = season.rating, rating > 0 {
                ratings[Int((rating * 2).rounded()), default: 0] += 1
                ratingTotal += rating
                stats.ratedCount += 1
            }
        }

        var episodesByShow: [Int: Int] = [:]
        for episode in episodes where inScope(episode.watchedAt) {
            stats.episodesWatched += 1
            if let runtime = episode.runtime, runtime > 0 {
                stats.episodeMinutes += runtime
            } else {
                stats.episodesMissingRuntime += 1
            }
            episodesByShow[episode.showTmdbID, default: 0] += 1
            let month = calendar.component(.month, from: episode.watchedAt)
            months[month - 1].episodes += 1
            if let day = calendar.dateInterval(of: .day, for: episode.watchedAt)?.start {
                activeDays.insert(day)
            }
        }

        stats.showsWatched = episodesByShow.count
        stats.months = months
        stats.busiestMonth = months.filter { $0.total > 0 }.max { $0.total < $1.total }
        stats.ratings = ratings
        stats.averageRating = stats.ratedCount > 0 ? ratingTotal / Double(stats.ratedCount) : nil
        stats.longestStreakDays = longestStreak(in: activeDays, calendar: calendar)

        let names = showNames()
        stats.topShows = episodesByShow
            .map { WatchStats.TopShow(showTmdbID: $0.key,
                                      name: names[$0.key] ?? "Show \($0.key)",
                                      episodes: $0.value) }
            .sorted { $0.episodes != $1.episodes ? $0.episodes > $1.episodes : $0.name < $1.name }
            .prefix(5)
            .map { $0 }

        return stats
    }

    // MARK: - Fetches

    private struct MovieFact {
        let watchedAt: Date
        let runtime: Int?
        let rating: Double?
    }

    private struct SeasonFact {
        let watchedAt: Date
        let rating: Double?
    }

    private struct EpisodeFact {
        let watchedAt: Date
        let showTmdbID: Int
        let runtime: Int?
    }

    private func watchedMovieFacts() -> [MovieFact] {
        let movieType = MediaType.movie.rawValue
        var descriptor = FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil && $0.mediaTypeRaw == movieType })
        descriptor.propertiesToFetch = [\.watchedAt, \.runtime, \.userRating]
        return ((try? modelContext.fetch(descriptor)) ?? []).compactMap { item in
            guard let watchedAt = item.watchedAt else { return nil }
            return MovieFact(watchedAt: watchedAt, runtime: item.runtime,
                             rating: item.userRating)
        }
    }

    private func watchedSeasonFacts() -> [SeasonFact] {
        var descriptor = FetchDescriptor<WatchedSeason>()
        descriptor.propertiesToFetch = [\.watchedAt, \.userRating]
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .map { SeasonFact(watchedAt: $0.watchedAt, rating: $0.userRating) }
    }

    private func watchedEpisodeFacts() -> [EpisodeFact] {
        var descriptor = FetchDescriptor<WatchedEpisode>()
        descriptor.propertiesToFetch = [\.watchedAt, \.showTmdbID, \.runtime]
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .map { EpisodeFact(watchedAt: $0.watchedAt, showTmdbID: $0.showTmdbID,
                               runtime: $0.runtime) }
    }

    // A show's name can come from any of three tables; the tracked season is the freshest.
    private func showNames() -> [Int: String] {
        var names: [Int: String] = [:]
        let tvType = MediaType.tv.rawValue
        var items = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.mediaTypeRaw == tvType })
        items.propertiesToFetch = [\.tmdbID, \.title]
        for item in (try? modelContext.fetch(items)) ?? [] where !item.title.isEmpty {
            names[item.tmdbID] = item.title
        }
        var seasons = FetchDescriptor<WatchedSeason>()
        seasons.propertiesToFetch = [\.showTmdbID, \.showName]
        for season in (try? modelContext.fetch(seasons)) ?? [] where !season.showName.isEmpty {
            names[season.showTmdbID] = season.showName
        }
        var tracked = FetchDescriptor<TrackedSeason>()
        tracked.propertiesToFetch = [\.showTmdbID, \.showName]
        for season in (try? modelContext.fetch(tracked)) ?? [] where !season.showName.isEmpty {
            names[season.showTmdbID] = season.showName
        }
        return names
    }

    private func longestStreak(in days: Set<Date>, calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var longest = 1
        var current = 1
        for (previous, day) in zip(sorted, sorted.dropFirst()) {
            if calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}

extension PersistenceCoordinator {
    func stats(scope: WatchStats.Scope) async -> WatchStats {
        await readingOffMain { $0.stats(scope: scope) }
    }
}
