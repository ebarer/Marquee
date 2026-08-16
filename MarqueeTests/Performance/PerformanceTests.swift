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
                let coordinator = ListCoordinator(modelContainer: container)
                let list = await coordinator.load(request: .list(uuid, sort: .releaseDate, foldOlder: .movies),
                                                  filter: "")
                _ = SectionFormatter.sections(from: list, ascending: false)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
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
