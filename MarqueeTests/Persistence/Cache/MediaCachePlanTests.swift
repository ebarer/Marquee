//
//  MediaCachePlanTests.swift
//  MarqueeTests
//
//  What the offline prefetcher keeps and in what order: Watch List, Discovery,
//  this year's watched, custom lists, then the rest of Watched.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct MediaCachePlanTests {
    @Test func watchListLeadsAndShowsPullTheirLatestSeasons() {
        let store = makeInMemoryStore()
        store.addToWatchList(makeMovie(id: 1))
        store.addToWatchList(Show(id: 2, name: "Show"))

        let plan = MediaCachePlan.merged(MediaCachePlan.local(in: store.context))
        #expect(plan.count == 2)
        #expect(plan.allSatisfy { $0.priority == .watchList })
        #expect(plan.first { $0.mediaType == .tv }?.seasonDepth == MediaCachePlan.watchListSeasonDepth)
        #expect(plan.first { $0.mediaType == .movie }?.seasonDepth == 0)
    }

    @Test func watchedSplitsOnTheCurrentYear() {
        let store = makeInMemoryStore()
        store.setWatched(true, for: makeMovie(id: 1))
        store.setWatched(true, for: makeMovie(id: 2))
        store.setDateWatched(Date.utc(2001, 6, 1), for: makeMovie(id: 2))

        let plan = MediaCachePlan.merged(MediaCachePlan.local(in: store.context))
        #expect(plan.first { $0.tmdbID == 1 }?.priority == .recentlyWatched)
        #expect(plan.first { $0.tmdbID == 2 }?.priority == .watched)
    }

    @Test func watchedSeasonSnapshotsCarryTheirShow() {
        let store = makeInMemoryStore()
        store.insert(WatchedSeason(showTmdbID: 9, seasonNumber: 1, showName: "Show",
                                   seasonName: "Season 1", posterPath: nil, airDate: nil,
                                   episodeCount: 1, watchedAt: Date.utc(2001, 6, 1)))

        // A show can sit in the Watched list on season snapshots alone, with no MediaItem.
        let plan = MediaCachePlan.merged(MediaCachePlan.local(in: store.context))
        #expect(plan.first { $0.tmdbID == 9 }?.mediaType == .tv)
        #expect(plan.first { $0.tmdbID == 9 }?.priority == .watched)
    }

    @Test func customListEntriesRankBelowWatchList() {
        let store = makeInMemoryStore()
        let list = MediaList(name: "Faves")
        store.insert(list)
        store.add(makeMovie(id: 3), to: list)

        let plan = MediaCachePlan.merged(MediaCachePlan.local(in: store.context))
        #expect(plan.first { $0.tmdbID == 3 }?.priority == .customList)
    }

    @Test func aTitleInTwoTiersTakesTheStrongerOne() {
        let store = makeInMemoryStore()
        let list = MediaList(name: "Faves")
        store.insert(list)
        store.add(makeMovie(id: 4), to: list)
        store.addToWatchList(makeMovie(id: 4))

        let plan = MediaCachePlan.merged(MediaCachePlan.local(in: store.context))
        #expect(plan.count == 1)
        #expect(plan[0].priority == .watchList)
    }

    @Test func mergedOrdersByTier() {
        let plan = MediaCachePlan.merged([
            MediaCacheTarget(tmdbID: 1, mediaType: .movie, priority: .watched),
            MediaCacheTarget(tmdbID: 2, mediaType: .movie, priority: .customList),
            MediaCacheTarget(tmdbID: 3, mediaType: .movie, priority: .discovery),
            MediaCacheTarget(tmdbID: 4, mediaType: .movie, priority: .watchList),
            MediaCacheTarget(tmdbID: 5, mediaType: .movie, priority: .recentlyWatched)
        ])
        #expect(plan.map(\.tmdbID) == [4, 3, 5, 2, 1])
    }

    @Test func mergedKeepsTheDeepestSeasonPull() {
        let plan = MediaCachePlan.merged([
            MediaCacheTarget(tmdbID: 7, mediaType: .tv, priority: .discovery),
            MediaCacheTarget(tmdbID: 7, mediaType: .tv, priority: .watchList, seasonDepth: 3)
        ])
        #expect(plan.count == 1)
        #expect(plan[0].seasonDepth == 3)
    }

    @Test func aMovieAndShowSharingAnIDStayDistinct() {
        let plan = MediaCachePlan.merged([
            MediaCacheTarget(tmdbID: 7, mediaType: .movie, priority: .watchList),
            MediaCacheTarget(tmdbID: 7, mediaType: .tv, priority: .discovery)
        ])
        #expect(plan.count == 2)
    }
}
