//
//  TestSupport.swift
//  MarqueeTests
//
//  Shared helpers: in-memory store, model factories.
//

import Foundation
import SwiftData
@testable import Marquee

/// A fresh, isolated store per test. Two deliberate choices for this toolchain:
///  - a unique on-disk temp file, not `isStoredInMemoryOnly` (`#Predicate` fetches
///    crash against the in-memory store, and the app leans on them everywhere);
///  - a plain `ModelContext(container)` rather than `container.mainContext`, whose
///    main-actor assertion traps under Swift Testing's executor.
@MainActor
func makeInMemoryStore() -> PersistenceCoordinator {
    let url = URL.temporaryDirectory.appending(path: "MarqueeTests-\(UUID().uuidString).store")
    let config = ModelConfiguration(url: url)
    let container = try! ModelContainer(
        for: MediaItem.self, MediaList.self, ListEntry.self,
        configurations: config)
    return PersistenceCoordinator(ModelContext(container))
}

/// A minimal display `Movie`.
func makeMovie(id: Int, title: String = "Movie",
               poster: String? = nil, release: Date? = nil,
               popularity: Double? = nil, runtime: Int? = nil) -> Movie {
    var m = Movie(id: id, title: title)
    m.poster = poster
    m.releaseDate = release
    m.popularity = popularity
    m.runtime = runtime
    return m
}

extension Date {
    /// A calendar day at UTC midnight, for deterministic date assertions.
    static func utc(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
