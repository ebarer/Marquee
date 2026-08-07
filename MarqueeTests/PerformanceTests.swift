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
        for i in 1...5000 {
            csv += "\"Movie \(i), Part\",1/1/20,\(i % 2),\(i % 5 + 1),\(i)\n"
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
        for i in 1...2000 {
            var movie = makeMovie(id: i, title: "Movie \(i)")
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
                let builder = SectionBuilder(modelContainer: container)
                _ = await builder.build(source: .list(uuid, byDateAdded: false, foldOlder: true),
                                        ascending: false, filter: "")
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }

    @MainActor
    func testDeduplicatePerformance() {
        // One container reused across iterations — creating in-memory containers
        // inside measure() crashes SwiftData.
        let ctx = makeInMemoryStore().context
        measure {
            for i in 1...1000 {
                ctx.insert(MediaItem(tmdbID: i, title: "M\(i)"))
                ctx.insert(MediaItem(tmdbID: i, title: "M\(i)"))  // duplicate
            }
            MediaItem.deduplicate(in: ctx)
        }
    }
}
