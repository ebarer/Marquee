//
//  MediaItemTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct MediaItemTests {
    let store = makeInMemoryStore()
    var ctx: ModelContext { store.context }

    @Test func upsertInsertsThenReturnsSameAndRefreshes() {
        var movie = makeMovie(id: 1, title: "Old", poster: "/old.jpg")
        let a = MediaItem.upsert(movie, in: ctx)
        movie.title = "New"; movie.poster = "/new.jpg"
        let b = MediaItem.upsert(movie, in: ctx)
        #expect(a === b)
        #expect(b.title == "New")
        #expect(b.posterPath == "/new.jpg")
        #expect(MediaItem.find(tmdbID: 1, in: ctx) === a)
    }

    @Test func initFromMovieCopiesSnapshot() {
        let item = MediaItem(movie: makeMovie(id: 7, title: "T", poster: "/p", runtime: 100))
        #expect(item.tmdbID == 7)
        #expect(item.title == "T")
        #expect(item.runtime == 100)
        #expect(item.mediaType == .movie)
        #expect(item.isWatched == false)
    }

    @Test func setRatingSnapsToHalfStar() {
        let movie = makeMovie(id: 1)
        MediaItem.setRating(3.7, for: movie, in: ctx)
        #expect(MediaItem.rating(for: movie, in: ctx) == 3.5)
        MediaItem.setRating(4.25, for: movie, in: ctx)
        #expect(MediaItem.rating(for: movie, in: ctx) == 4.5)
    }

    @Test func setRatingNilOrZeroClearsAndPrunes() {
        let movie = makeMovie(id: 1)
        MediaItem.setRating(4, for: movie, in: ctx)
        #expect(MediaItem.find(movie, in: ctx) != nil)
        MediaItem.setRating(0, for: movie, in: ctx)
        #expect(MediaItem.find(movie, in: ctx) == nil)
    }

    @Test func setRatingOnAbsentItemIsNoOp() {
        let movie = makeMovie(id: 1)
        MediaItem.setRating(nil, for: movie, in: ctx)
        #expect(MediaItem.find(movie, in: ctx) == nil)
    }

    @Test func ratingSurvivesAlongsideWatched() {
        let movie = makeMovie(id: 1)
        MediaItem.setWatched(true, for: movie, in: ctx)
        MediaItem.setRating(5, for: movie, in: ctx)
        MediaItem.setRating(0, for: movie, in: ctx)  // clears rating only
        let item = MediaItem.find(movie, in: ctx)
        #expect(item != nil)
        #expect(item?.userRating == nil)
        #expect(item?.isWatched == true)
    }

    @Test func setWatchedMarksAndUnmarks() {
        let movie = makeMovie(id: 1)
        MediaItem.setWatched(true, for: movie, in: ctx)
        #expect(MediaItem.isWatched(movie, in: ctx))
        #expect(MediaItem.dateWatched(for: movie, in: ctx) == MediaItem.floatingDay(from: Date()))
        MediaItem.setWatched(false, for: movie, in: ctx)
        #expect(MediaItem.isWatched(movie, in: ctx) == false)
        #expect(MediaItem.find(movie, in: ctx) == nil)  // pruned
    }

    @Test func markingWatchedRemovesFromWatchList() {
        let movie = makeMovie(id: 1)
        let list = MediaList.ensureWatchList(in: ctx)
        list.add(movie)
        #expect(list.contains(movie.id))
        MediaItem.setWatched(true, for: movie, in: ctx)
        try? ctx.save()  // reflect the entry delete in the to-many relationship
        #expect(list.contains(movie.id) == false)
        #expect(MediaItem.isWatched(movie, in: ctx))
    }

    @Test func setDateWatchedUpdatesExistingOnly() {
        let movie = makeMovie(id: 1)
        MediaItem.setDateWatched(.utc(2020, 1, 1), for: movie, in: ctx)
        #expect(MediaItem.find(movie, in: ctx) == nil)  // no item to update
        MediaItem.setWatched(true, for: movie, in: ctx)
        MediaItem.setDateWatched(.utc(2019, 6, 6), for: movie, in: ctx)
        #expect(MediaItem.dateWatched(for: movie, in: ctx) == .utc(2019, 6, 6))
    }

    @Test func recordViewTrimsToLimit() {
        for id in 1...5 { MediaItem.recordView(makeMovie(id: id), in: ctx, keeping: 3) }
        let viewed = (try? ctx.fetch(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.lastViewedAt != nil }))) ?? []
        #expect(viewed.count == 3)
        // Oldest (ids 1,2) trimmed and pruned since they hold no other state.
        #expect(MediaItem.find(tmdbID: 1, in: ctx) == nil)
        #expect(MediaItem.find(tmdbID: 5, in: ctx) != nil)
    }

    @Test func recordViewKeepsTrimmedItemThatHasOtherState() {
        let watched = makeMovie(id: 1)
        MediaItem.setWatched(true, for: watched, in: ctx)
        for id in 2...5 { MediaItem.recordView(makeMovie(id: id), in: ctx, keeping: 2) }
        MediaItem.recordView(watched, in: ctx, keeping: 2)   // pushes id 1 out of Viewed
        let item = MediaItem.find(tmdbID: 1, in: ctx)
        #expect(item != nil)               // survives: still Watched
        #expect(item?.lastViewedAt != nil) // most recent view, within limit
    }

    @Test func floatingDayRoundTrip() {
        let local = Date()
        let stored = MediaItem.floatingDay(from: local)
        let back = MediaItem.localDay(from: stored)
        let cal = Calendar.current
        #expect(cal.dateComponents([.year, .month, .day], from: back)
                == cal.dateComponents([.year, .month, .day], from: local))
    }

    @Test func floatingDayIsUTCMidnight() {
        let stored = MediaItem.floatingDay(from: .utc(2021, 7, 4))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = utc.dateComponents([.hour, .minute, .second], from: stored)
        #expect(comps.hour == 0 && comps.minute == 0 && comps.second == 0)
    }

    @Test func deduplicateMergesFactsKeepingEarliest() {
        let keep = MediaItem(tmdbID: 1, title: "A")
        keep.addedAt = .utc(2020, 1, 1)
        keep.userRating = 4
        let dup = MediaItem(tmdbID: 1, title: "A")
        dup.addedAt = .utc(2021, 1, 1)
        dup.watchedAt = .utc(2021, 5, 5)
        ctx.insert(keep); ctx.insert(dup)

        #expect(MediaItem.deduplicate(in: ctx))
        let all = (try? ctx.fetch(FetchDescriptor<MediaItem>())) ?? []
        #expect(all.count == 1)
        #expect(all.first === keep)
        #expect(keep.userRating == 4)        // kept
        #expect(keep.watchedAt == .utc(2021, 5, 5))  // OR-ed from dup
    }

    @Test func deduplicateNoopWhenUnique() {
        ctx.insert(MediaItem(tmdbID: 1, title: "A"))
        ctx.insert(MediaItem(tmdbID: 2, title: "B"))
        #expect(MediaItem.deduplicate(in: ctx) == false)
    }
}
