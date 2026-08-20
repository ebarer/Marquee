//
//  SchemaPrimerCoverageTests.swift
//  MarqueeTests
//
//  A tripwire, not a proof. It can't check that SchemaPrimer sets the right field — only that
//  changing the schema is impossible without being made to look at it. That's the failure mode:
//  `.automatic` materializes a CloudKit field only when a record writes it, so a field the primer
//  misses never reaches Production and sync breaks silently (twice in Aug 2026).
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@Suite struct SchemaPrimerCoverageTests {

    private static let primed: [String: Set<String>] = [
        "MediaItem": ["posterPath", "releaseDate", "sortDate", "runtime", "userRating",
                      "watchedAt", "lastViewedAt", "showWatched", "showCaughtUp", "watchListOptOut"],
        "MediaList": ["customColorHex", "deduplicatedDate"],
        "ListEntry": ["posterPath", "releaseDate", "sortDate", "runtime"],
        "WatchedEpisode": [],
        "WatchedSeason": ["posterPath", "airDate", "userRating"],
        "TrackedSeason": ["posterPath", "nextEpisodeDate"],
    ]

    @Test func noModelTypeIsMissingFromThePrimer() {
        let entities = Set(MarqueeSchema.schema.entities.map(\.name))
        #expect(entities == Set(Self.primed.keys), """
            The set of @Model types changed. A new type needs its own context.insert(...) in \
            SchemaPrimer.prime AND a delete loop in SchemaPrimer.purge, then an entry here.
            """)
    }

    @Test func noOptionalFieldIsMissingFromThePrimer() {
        for entity in MarqueeSchema.schema.entities {
            guard let known = Self.primed[entity.name] else { continue }  // covered by the test above
            let optionals = Set(entity.attributes.filter(\.isOptional).map(\.name))
            #expect(optionals == known, """
                \(entity.name)'s optional fields changed: \(optionals.symmetricDifference(known)). \
                Set them in SchemaPrimer.prime, or they never materialize in CloudKit.
                """)
        }
    }

    @MainActor
    @Test func primingWritesOneRecordOfEveryType() {
        let store = makeInMemoryStore()
        SchemaPrimer.prime(using: store)

        #expect(count(MediaItem.self, in: store) == 1)
        #expect(count(MediaList.self, in: store) == 1)
        #expect(count(ListEntry.self, in: store) == 1)
        #expect(count(WatchedEpisode.self, in: store) == 1)
        #expect(count(WatchedSeason.self, in: store) == 1)
        #expect(count(TrackedSeason.self, in: store) == 1)

        SchemaPrimer.purge(using: store)
        #expect(count(MediaItem.self, in: store) == 0)
        #expect(count(MediaList.self, in: store) == 0)
        #expect(count(ListEntry.self, in: store) == 0)
        #expect(count(WatchedEpisode.self, in: store) == 0)
        #expect(count(WatchedSeason.self, in: store) == 0)
        #expect(count(TrackedSeason.self, in: store) == 0)
    }

    @MainActor
    private func count<T: PersistentModel>(_ type: T.Type, in store: PersistenceCoordinator) -> Int {
        (try? store.context.fetchCount(FetchDescriptor<T>())) ?? -1
    }
}
