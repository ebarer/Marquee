//
//  WatchedMemoryTests.swift
//  MarqueeTests
//
//  An accidental un-mark must not cost the date the user entered: re-marking the same title
//  restores it, for a movie and for a TV season (whose rating goes with its snapshot).
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct WatchedMemoryTests {
    private func makeShow(id: Int = 1, seasons: Int = 1, episodes: Int = 2) -> Show {
        var show = Show(id: id, name: "Show \(id)")
        show.seasons = (1...seasons).map { number in
            var season = Season(id: number * 100, seasonNumber: number, name: "Season \(number)",
                                episodeCount: episodes)
            season.episodes = (1...episodes).map { episodeNumber in
                var episode = Episode(id: number * 1000 + episodeNumber, seasonNumber: number,
                                      episodeNumber: episodeNumber, name: "E\(episodeNumber)")
                episode.airDate = .utc(2020, 1, 1)
                return episode
            }
            return season
        }
        return show
    }

    // MARK: - Movies

    @Test func reMarkingAMovieRestoresTheEnteredDate() {
        let store = makeInMemoryStore()
        let movie = makeMovie(id: 1)
        let entered = MediaItem.floatingDay(from: .utc(2024, 3, 9))
        store.setWatched(true, for: movie)
        store.setDateWatched(entered, for: movie)

        store.setWatched(false, for: movie)
        store.setWatched(true, for: movie)

        #expect(store.dateWatched(for: movie) == entered)
    }

    @Test func aMovieWithNoRememberedDateIsMarkedToday() {
        let store = makeInMemoryStore()
        let movie = makeMovie(id: 2)
        store.setWatched(true, for: movie)

        #expect(store.dateWatched(for: movie) == MediaItem.floatingDay(from: Date()))
    }

    /// The Watched-list swipe deletes the row through the item, not the movie.
    @Test func unwatchingByItemRemembersTheDate() {
        let store = makeInMemoryStore()
        let movie = makeMovie(id: 3)
        let entered = MediaItem.floatingDay(from: .utc(2021, 12, 25))
        store.setWatched(true, for: movie)
        store.setDateWatched(entered, for: movie)

        store.unwatch(MediaItem.find(movie, in: store.context)!)
        store.setWatched(true, for: movie)

        #expect(store.dateWatched(for: movie) == entered)
    }

    /// Moving a watched movie to the Watch List un-marks it; marking it watched again keeps
    /// the date rather than reading as watched today.
    @Test func theWatchListRoundTripKeepsTheDate() {
        let store = makeInMemoryStore()
        let movie = makeMovie(id: 4)
        let entered = MediaItem.floatingDay(from: .utc(2023, 7, 1))
        store.setWatched(true, for: movie)
        store.setDateWatched(entered, for: movie)

        store.addToWatchList(movie)
        #expect(!store.isWatched(movie))

        store.setWatched(true, for: movie)
        #expect(store.dateWatched(for: movie) == entered)
    }

    @Test func aFreshDateOverwritesTheRememberedOne() {
        let store = makeInMemoryStore()
        let movie = makeMovie(id: 5)
        store.setWatched(true, for: movie)
        store.setDateWatched(MediaItem.floatingDay(from: .utc(2020, 1, 1)), for: movie)
        store.setWatched(false, for: movie)
        store.setWatched(true, for: movie)

        let corrected = MediaItem.floatingDay(from: .utc(2022, 5, 5))
        store.setDateWatched(corrected, for: movie)
        store.setWatched(false, for: movie)
        store.setWatched(true, for: movie)

        #expect(store.dateWatched(for: movie) == corrected)
    }

    // MARK: - Seasons

    @Test func reCompletingASeasonRestoresItsDateAndRating() {
        let store = makeInMemoryStore()
        let show = makeShow()
        let season = show.seasons[0]
        let entered = Date.utc(2024, 2, 2)
        store.setSeasonWatched(true, show: show, season: season)
        store.setSeasonWatchedDate(entered, showID: show.id, season: 1)
        store.setSeasonRating(4.5, showID: show.id, season: 1)

        store.setSeasonWatched(false, show: show, season: season)
        #expect(store.seasonWatchedDate(showID: show.id, season: 1) == nil)

        store.setSeasonWatched(true, show: show, season: season)
        #expect(store.seasonWatchedDate(showID: show.id, season: 1) == entered)
        #expect(store.seasonRating(showID: show.id, season: 1) == 4.5)
    }

    /// Un-marking one episode drops the season's snapshot; watching it again brings the date back.
    @Test func unwatchingOneEpisodeKeepsTheSeasonDate() {
        let store = makeInMemoryStore()
        let show = makeShow()
        let season = show.seasons[0]
        let entered = Date.utc(2019, 9, 9)
        store.setSeasonWatched(true, show: show, season: season)
        store.setSeasonWatchedDate(entered, showID: show.id, season: 1)

        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 2)
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 2)

        #expect(store.seasonWatchedDate(showID: show.id, season: 1) == entered)
    }

    @Test func clearingAWholeSeasonThenReMarkingKeepsTheDate() async {
        let store = makeInMemoryStore()
        let show = makeShow(seasons: 2)
        await store.setShowWatched(true, show: show)
        let entered = Date.utc(2018, 4, 4)
        store.setSeasonWatchedDate(entered, showID: show.id, season: 2)

        store.unwatchSeason(showID: show.id, seasonNumber: 2)
        await store.setShowWatched(true, show: show)

        #expect(store.seasonWatchedDate(showID: show.id, season: 2) == entered)
    }

    /// Nothing remembered: a completed season is dated by the caller (the finale, here).
    @Test func aSeasonWithNoRememberedDateTakesTheFinale() async {
        let store = makeInMemoryStore()
        let show = makeShow()
        await store.setShowWatched(true, show: show)

        #expect(store.seasonWatchedDate(showID: show.id, season: 1) == .utc(2020, 1, 1))
    }
}
