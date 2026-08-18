//
//  ListEntrySwipeChoiceTests.swift
//  MarqueeTests
//
//  Which leading swipe a row offers. Marking stops at today, so a row with nothing aired left
//  to mark must offer no swipe rather than one that quietly does nothing.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct ListEntrySwipeChoiceTests {
    let store = makeInMemoryStore()

    private func context(_ selection: ListSelection = .list(UUID()),
                         isWatchList: Bool = true,
                         caughtUp: Set<Int> = []) -> ListEntryContext {
        ListEntryContext(selection: selection, isWatchList: isWatchList, watchListIDs: [],
                         listColor: .appAccent, caughtUpShowIDs: caughtUp)
    }

    private func snapshot(id: Int = 1, mediaType: MediaType = .tv, season: Int? = nil,
                          nextEpisodeDate: Date? = nil) -> MediaSnapshot {
        let item = MediaItem(tmdbID: id, mediaType: mediaType, title: "Shogun")
        store.context.insert(item)
        return MediaSnapshot(persistentID: item.persistentModelID, tmdbID: id,
                             mediaType: mediaType, title: "Shogun", posterPath: nil,
                             releaseDate: nil, sortDate: nil, seasonNumber: season,
                             seasonWatched: nil, seasonTotal: nil,
                             nextEpisodeDate: nextEpisodeDate, runtime: nil,
                             dateWatched: nil, userRating: nil)
    }

    @Test func trackedSeasonOffersTheEpisodeSwipe() {
        let entry = snapshot(season: 2, nextEpisodeDate: .utc(2020, 1, 1))
        #expect(context().leadingSwipe(for: entry) == .trackedSeason(2))
    }

    @Test func caughtUpSeasonOffersNothing() {
        let entry = snapshot(season: 2, nextEpisodeDate: .utc(2020, 1, 1))
        #expect(context(caughtUp: [entry.tmdbID]).leadingSwipe(for: entry) == nil)
    }

    /// The whole-show swipe would mark aired episodes only, and there are none left.
    @Test func caughtUpShowOffersNothingWithoutATrackedSeason() {
        let entry = snapshot()
        #expect(context().leadingSwipe(for: entry) == .toggleShowWatched)
        #expect(context(caughtUp: [entry.tmdbID]).leadingSwipe(for: entry) == nil)
    }

    /// Being caught up on one show says nothing about the next row.
    @Test func otherShowsKeepTheirSwipe() {
        let entry = snapshot(id: 7, season: 1, nextEpisodeDate: .utc(2020, 1, 1))
        #expect(context(caughtUp: [99]).leadingSwipe(for: entry) == .trackedSeason(1))
    }

    /// Already covered before this: nothing to mark until the next episode airs.
    @Test func unairedNextEpisodeOffersNothing() {
        let entry = snapshot(season: 2, nextEpisodeDate: .distantFuture)
        #expect(context().leadingSwipe(for: entry) == nil)
    }

    @Test func moviesAreUntouchedByTheShowRule() {
        let entry = snapshot(id: 3, mediaType: .movie)
        #expect(context(caughtUp: [3]).leadingSwipe(for: entry) == .markWatched)
        #expect(context(.watched, isWatchList: false, caughtUp: [3])
            .leadingSwipe(for: entry) == .addToWatchList)
    }
}
