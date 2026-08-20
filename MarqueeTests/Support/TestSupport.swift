//
//  TestSupport.swift
//  MarqueeTests
//
//  Shared helpers: in-memory store, model factories.
//

import Foundation
import SwiftData
@testable import Marquee

// A temp file because `#Predicate` fetches crash in-memory, and a plain `ModelContext` because
// `mainContext` traps under Swift Testing's concurrency.
@MainActor
func makeInMemoryStore() -> PersistenceCoordinator {
    let url = URL.temporaryDirectory.appending(path: "MarqueeTests-\(UUID().uuidString).store")
    // cloudKitDatabase defaults to .automatic: the app's entitlement then attaches a mirroring
    // delegate that can't set up, and its store monitor stalls the run ~100s on teardown.
    let config = ModelConfiguration(url: url, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: MarqueeSchema.schema, configurations: config)
    return PersistenceCoordinator(ModelContext(container))
}

func makeMovie(id: Int, title: String = "Movie",
               poster: String? = nil, release: Date? = nil,
               popularity: Double? = nil, runtime: Int? = nil) -> Movie {
    var movie = Movie(id: id, title: title)
    movie.poster = poster
    movie.releaseDate = release
    movie.popularity = popularity
    movie.runtime = runtime
    return movie
}

extension Date {
    static func utc(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
