//
//  WatchStatsTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@Suite @MainActor struct WatchStatsTests {
    private let store = makeInMemoryStore()

    private func coordinator() -> ListCoordinator {
        ListCoordinator(container: store.context.container)
    }

    private func markMovieWatched(id: Int, on date: Date, runtime: Int? = nil,
                                 release: Date? = nil, rating: Double? = nil) {
        let movie = makeMovie(id: id, title: "Movie \(id)", release: release, runtime: runtime)
        let item = MediaItem.upsert(movie, in: store.context)
        item.watchedAt = date
        item.userRating = rating
        store.save()
    }

    private func markEpisodeWatched(showID: Int, season: Int, episode: Int, on date: Date) {
        let watched = WatchedEpisode(showTmdbID: showID, seasonNumber: season,
                                     episodeNumber: episode, watchedAt: date)
        store.context.insert(watched)
        store.save()
    }

    @Test func countsMoviesAndRuntimeForTheSelectedYear() {
        markMovieWatched(id: 1, on: .utc(2025, 3, 4), runtime: 120)
        markMovieWatched(id: 2, on: .utc(2025, 7, 9), runtime: 90)
        markMovieWatched(id: 3, on: .utc(2024, 1, 1), runtime: 200)

        let stats = coordinator().stats(scope: .year(2025))
        #expect(stats.moviesWatched == 2)
        #expect(stats.movieMinutes == 210)
        #expect(stats.moviesMissingRuntime == 0)
    }

    @Test func allTimeSpansEveryYear() {
        markMovieWatched(id: 1, on: .utc(2025, 3, 4), runtime: 120)
        markMovieWatched(id: 2, on: .utc(2024, 3, 4), runtime: 60)

        let stats = coordinator().stats(scope: .allTime)
        #expect(stats.moviesWatched == 2)
        #expect(stats.movieMinutes == 180)
        #expect(stats.availableYears == [2025, 2024])
    }

    @Test func tracksMoviesWithNoKnownRuntimeSeparately() {
        markMovieWatched(id: 1, on: .utc(2025, 3, 4), runtime: nil)
        markMovieWatched(id: 2, on: .utc(2025, 3, 5), runtime: 0)
        markMovieWatched(id: 3, on: .utc(2025, 3, 6), runtime: 100)

        let stats = coordinator().stats(scope: .year(2025))
        #expect(stats.movieMinutes == 100)
        #expect(stats.moviesMissingRuntime == 2)
    }

    @Test func bucketsActivityByMonth() {
        markMovieWatched(id: 1, on: .utc(2025, 1, 10), runtime: 100)
        markEpisodeWatched(showID: 7, season: 1, episode: 1, on: .utc(2025, 1, 11))
        markEpisodeWatched(showID: 7, season: 1, episode: 2, on: .utc(2025, 4, 2))

        let stats = coordinator().stats(scope: .year(2025))
        #expect(stats.months.count == 12)
        #expect(stats.months[0].movies == 1)
        #expect(stats.months[0].episodes == 1)
        #expect(stats.months[3].episodes == 1)
        #expect(stats.busiestMonth?.month == 1)
    }

    @Test func countsDistinctShowsAndRanksThemByEpisodes() {
        markEpisodeWatched(showID: 10, season: 1, episode: 1, on: .utc(2025, 2, 1))
        markEpisodeWatched(showID: 10, season: 1, episode: 2, on: .utc(2025, 2, 2))
        markEpisodeWatched(showID: 11, season: 1, episode: 1, on: .utc(2025, 2, 3))

        let stats = coordinator().stats(scope: .year(2025))
        #expect(stats.episodesWatched == 3)
        #expect(stats.showsWatched == 2)
        #expect(stats.topShows.first?.showTmdbID == 10)
        #expect(stats.topShows.first?.episodes == 2)
    }

    @Test func buildsRatingHistogramInHalfStars() {
        markMovieWatched(id: 1, on: .utc(2025, 1, 1), runtime: 90, rating: 5)
        markMovieWatched(id: 2, on: .utc(2025, 1, 2), runtime: 90, rating: 3.5)
        markMovieWatched(id: 3, on: .utc(2025, 1, 3), runtime: 90, rating: 3.5)

        let stats = coordinator().stats(scope: .year(2025))
        #expect(stats.ratings[10] == 1)
        #expect(stats.ratings[7] == 2)
        #expect(stats.ratedCount == 3)
        #expect(stats.averageRating == 4)
    }

    @Test func longestStreakCountsConsecutiveDaysOnly() {
        for day in 5...8 {
            markEpisodeWatched(showID: 3, season: 1, episode: day, on: .utc(2025, 6, day))
        }
        markEpisodeWatched(showID: 3, season: 1, episode: 20, on: .utc(2025, 6, 20))

        let stats = coordinator().stats(scope: .year(2025))
        #expect(stats.longestStreakDays == 4)
    }

    @Test func completedSeasonsCountAsTitlesFinished() {
        let season = WatchedSeason(showTmdbID: 4, seasonNumber: 2, showName: "Show",
                                   seasonName: "Season 2", posterPath: nil,
                                   airDate: .utc(2025, 1, 1), episodeCount: 8,
                                   watchedAt: .utc(2025, 5, 5))
        store.context.insert(season)
        store.save()
        markMovieWatched(id: 1, on: .utc(2025, 5, 6), runtime: 90)

        let stats = coordinator().stats(scope: .year(2025))
        #expect(stats.seasonsCompleted == 1)
        #expect(stats.titlesFinished == 2)
    }

    @Test func emptyHistoryReportsEmpty() {
        let stats = coordinator().stats(scope: .allTime)
        #expect(stats.isEmpty)
        #expect(stats.availableYears.isEmpty)
        #expect(stats.longestStreakDays == 0)
    }
}
