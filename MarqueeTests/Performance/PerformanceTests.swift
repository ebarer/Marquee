//
//  PerformanceTests.swift
//  MarqueeTests
//
//  XCTest for its measure() harness (Swift Testing has no perf metric yet).
//

import XCTest
import SwiftData
@testable import Marquee

final class PerformanceTests: XCTestCase {

    func testCSVParsePerformance() throws {
        var csv = "Title,Release Date,Watched,Your Rating,TMDB ID\n"
        for row in 1...5000 {
            csv += "\"Movie \(row), Part\",1/1/20,\(row % 2),\(row % 5 + 1),\(row)\n"
        }
        let data = Data(csv.utf8)
        measure { _ = try? CSVMovieRecord.parse(data: data) }
    }

    @MainActor
    func testSectionBuildingPerformance() {
        let store = makeInMemoryStore()
        let list = MediaList(name: "Big")
        store.context.insert(list)
        var day = Date.utc(2000, 1, 1)
        for index in 1...2000 {
            var movie = makeMovie(id: index, title: "Movie \(index)")
            movie.releaseDate = day
            let entry = ListEntry(movie: movie)
            entry.list = list
            store.context.insert(entry)
            day = Calendar.current.date(byAdding: .day, value: 3, to: day)!
        }
        store.save()
        let uuid = list.uuid
        let container = store.context.container

        measure {
            let expectation = expectation(description: "build")
            Task {
                let coordinator = ListCoordinator(container: container)
                let list = coordinator.load(request: .list(uuid, sort: .releaseDate, foldOlder: .movies),
                                            filter: "")
                _ = SectionFormatter.sections(from: list, ascending: false)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }

    /// Formatting is the half that used to run on the main actor, so it's measured on its own:
    /// this is the budget a store tick spends before the Lists screen can draw a frame.
    @MainActor
    func testWatchedSectionFormattingPerformance() {
        let store = makeInMemoryStore()
        var day = Date.utc(2010, 1, 1)
        for index in 1...1500 {
            var movie = makeMovie(id: index, title: "Movie \(index)")
            movie.releaseDate = day
            store.setWatched(true, for: movie)
            day = Calendar.current.date(byAdding: .day, value: 3, to: day)!
        }
        for show in 1...200 {
            store.context.insert(WatchedSeason(showTmdbID: show, seasonNumber: 1,
                                               showName: "Show \(show)", seasonName: "Season 1",
                                               posterPath: nil, airDate: day))
            for episode in 1...10 {
                store.context.insert(WatchedEpisode(showTmdbID: show, seasonNumber: 1,
                                                    episodeNumber: episode))
            }
        }
        store.save()
        let container = store.context.container

        var rows: ListResult!
        let loaded = expectation(description: "load")
        Task {
            rows = ListCoordinator(container: container)
                .load(request: .watched(sort: .dateWatched), filter: "")
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 30)

        measure { _ = SectionFormatter.sections(from: rows, ascending: false) }
    }

    /// A screenful of cards derives its badges every time the store ticks. Measured against the
    /// per-title store lookups they used to run in `body`.
    @MainActor
    func testBadgeDerivationPerformance() {
        let store = badgeFixture()
        let onScreen = Array(1...200)

        measure {
            let badges = store.badges
            for id in onScreen { _ = PosterStatus.derive(movieID: id, from: badges) }
        }
    }

    @MainActor
    func testBadgeDerivationViaPerTitleFetches() {
        let store = badgeFixture()
        let onScreen = Array(1...200).map { makeMovie(id: $0) }

        measure {
            for movie in onScreen {
                _ = store.isWatched(movie) || store.isInWatchList(movie)
            }
        }
    }

    /// The index rebuilds on the first badge read after each save, on the main actor — so the
    /// rebuild itself has to fit inside a frame.
    @MainActor
    func testBadgeIndexRebuildPerformance() {
        let store = badgeFixture()
        _ = MediaBadgeIndex(context: store.context)   // warm the context, as a running app is

        measure { _ = MediaBadgeIndex(context: store.context) }
    }

    /// 800 watched movies, 400 on the Watch List, 200 shows with watched episodes.
    @MainActor
    private func badgeFixture() -> PersistenceCoordinator {
        let store = makeInMemoryStore()
        for index in 1...800 { store.setWatched(true, for: makeMovie(id: index)) }
        for index in 801...1200 { store.addToWatchList(makeMovie(id: index)) }
        for show in 1...200 {
            store.context.insert(WatchedEpisode(showTmdbID: show, seasonNumber: 1, episodeNumber: 1))
        }
        store.save()
        return store
    }

    @MainActor
    func testDeduplicatePerformance() {
        // One container reused across iterations — creating in-memory containers
        // inside measure() crashes SwiftData.
        let context = makeInMemoryStore().context
        measure {
            for index in 1...1000 {
                context.insert(MediaItem(tmdbID: index, title: "M\(index)"))
                context.insert(MediaItem(tmdbID: index, title: "M\(index)"))  // duplicate
            }
            MediaItem.deduplicate(in: context)
        }
    }
}
