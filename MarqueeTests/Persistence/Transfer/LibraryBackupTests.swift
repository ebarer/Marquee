//
//  LibraryBackupTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@Suite struct LibraryBackupCodingTests {
    private func sampleEntry(_ id: Int) -> LibraryBackup.Entry {
        LibraryBackup.Entry(movieID: id, title: "M\(id)", posterPath: "/p.jpg",
                            releaseDate: .utc(2010, 1, 1), dateAdded: .utc(2011, 1, 1),
                            dateWatched: nil, userRating: nil)
    }

    @Test func jsonRoundTrips() throws {
        let backup = LibraryBackup(lists: [
            .init(uuid: UUID(), name: "Faves", symbol: "star", colorIndex: 2,
                  kind: LibraryBackup.Kind.custom.rawValue, sortOrder: 1,
                  createdAt: .utc(2012, 1, 1), entries: [sampleEntry(1), sampleEntry(2)])
        ])
        let restored = try LibraryBackup(json: backup.jsonData())
        #expect(restored.version == LibraryBackup.currentVersion)
        #expect(restored.lists.count == 1)
        #expect(restored.lists[0].entries.map(\.movieID) == [1, 2])
    }

    @Test func rejectsNewerVersion() throws {
        var backup = LibraryBackup(lists: [])
        backup.version = LibraryBackup.currentVersion + 1
        #expect(throws: ImportError.self) {
            _ = try LibraryBackup(json: backup.jsonData())
        }
    }

    @Test func entryDecodesWholeStarRatingAsDouble() throws {
        let json = #"{"movieID":1,"title":"A","dateAdded":"2011-01-01T00:00:00Z","userRating":4}"#
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(LibraryBackup.Entry.self, from: Data(json.utf8))
        #expect(entry.userRating == 4.0)
    }

    @Test func entryDecodesMissingRatingAsNil() throws {
        let json = #"{"movieID":1,"title":"A","dateAdded":"2011-01-01T00:00:00Z"}"#
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(LibraryBackup.Entry.self, from: Data(json.utf8))
        #expect(entry.userRating == nil)
    }

    @Test func decodesArchiveWithoutShowProgress() throws {
        let json = #"{"version":1,"exportedAt":"2011-01-01T00:00:00Z","lists":[]}"#
        let archive = try LibraryBackup(json: Data(json.utf8))
        #expect(archive.shows.isEmpty)
    }

    @Test func showProgressRoundTrips() throws {
        var backup = LibraryBackup(lists: [])
        backup.shows = [
            .init(tmdbID: 9, name: "MobLand", posterPath: "/m.jpg", isWatched: nil,
                  isCaughtUp: true, watchListOptOut: nil,
                  tracked: .init(season: 2, posterPath: nil, episodeCount: 8,
                                 nextEpisodeDate: .utc(2026, 4, 1)),
                  seasons: [.init(season: 1, name: "Season 1", posterPath: nil,
                                  airDate: .utc(2025, 6, 1), episodeCount: 2,
                                  watchedAt: .utc(2025, 6, 2), userRating: 4.5)],
                  episodes: [.init(season: 1, episode: 1, watchedAt: .utc(2025, 5, 1)),
                             .init(season: 1, episode: 2, watchedAt: .utc(2025, 6, 2))])
        ]
        let restored = try LibraryBackup(json: backup.jsonData())
        let show = try #require(restored.shows.first)
        #expect(show.episodes.count == 2)
        #expect(show.seasons.first?.userRating == 4.5)
        #expect(show.tracked?.season == 2)
        #expect(show.isCaughtUp == true)
    }

    @Test func entryDecodesMissingMediaTypeAsMovie() throws {
        // Files written before shows were tracked have no media type; they held movies only.
        let json = #"{"movieID":1,"title":"A","dateAdded":"2011-01-01T00:00:00Z"}"#
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(LibraryBackup.Entry.self, from: Data(json.utf8))
        #expect(entry.mediaType == MediaType.movie.rawValue)
    }
}

@Suite struct ImportSummaryTests {
    @Test func pluralizesAndOmitsZeroes() {
        var summary = ImportSummary(); summary.entriesAdded = 1
        #expect(summary.message == "1 title added.")
        summary = ImportSummary()
        summary.listsCreated = 2; summary.entriesAdded = 3; summary.entriesSkipped = 4
        #expect(summary.message == "2 new lists, 3 titles added, 4 already present.")
        summary = ImportSummary(); summary.listsCreated = 1; summary.entriesAdded = 0
        #expect(summary.message == "1 new list, 0 titles added.")
    }
}

@MainActor
@Suite struct LibraryBackupStoreTests {
    @Test func exportCapturesListsAndWatchedFacts() {
        let store = makeInMemoryStore()
        let list = MediaList(name: "Faves", sortOrder: 1)
        store.insert(list)
        store.add(makeMovie(id: 1, title: "A"), to: list)
        let watched = makeMovie(id: 2, title: "B")
        store.setWatched(true, for: watched)
        store.setRating(3, for: watched)

        let backup = LibraryBackup.export(from: store.context)
        #expect(backup.lists.contains { $0.name == "Faves" })
        let watchedList = backup.lists.first { $0.kind == LibraryBackup.Kind.watched.rawValue }
        #expect(watchedList?.entries.first?.movieID == 2)
        #expect(watchedList?.entries.first?.userRating == 3)
    }

    @Test func showsSurviveExportAndImportAsTV() {
        let store = makeInMemoryStore()
        let list = MediaList(name: "Faves", sortOrder: 1)
        store.insert(list)
        var show = Show(id: 7, name: "Silo")
        show.firstAirDate = .utc(2023, 5, 5)
        store.add(show, to: list)

        let backup = LibraryBackup.export(from: store.context)
        let exported = backup.lists.first { $0.name == "Faves" }?.entries.first
        #expect(exported?.mediaType == MediaType.tv.rawValue)

        // Import into a fresh store: the entry must come back as a show, not a movie.
        let fresh = makeInMemoryStore()
        _ = LibraryBackup.merge(backup, using: fresh)
        let imported = fresh.customLists.first { $0.name == "Faves" }?.entries?.first
        #expect(imported?.mediaType == .tv)
    }

    @Test func tvProgressSurvivesExportAndImport() {
        let store = makeInMemoryStore()
        var season = Season(id: 100, seasonNumber: 1, name: "Season 1", episodeCount: 3)
        season.airDate = .utc(2025, 3, 30)
        season.episodes = (1...3).map { number in
            var episode = Episode(id: 1000 + number, seasonNumber: 1, episodeNumber: number,
                                  name: "E\(number)")
            episode.airDate = .utc(2025, 3, 30)
            return episode
        }
        var show = Show(id: 247718, name: "MobLand")
        show.seasons = [season]
        store.setSeasonWatched(true, show: show, season: season)
        store.setSeasonRating(4.5, showID: 247718, season: 1)

        let backup = LibraryBackup.export(from: store.context)
        let fresh = makeInMemoryStore()
        _ = LibraryBackup.merge(backup, using: fresh)

        #expect(fresh.watchedEpisodeNumbers(showID: 247718, season: 1) == [1, 2, 3])
        #expect(fresh.isSeasonWatched(season, showID: 247718))
        #expect(fresh.seasonRating(showID: 247718, season: 1) == 4.5)
        #expect(fresh.isShowWatchedCached(showID: 247718))
    }

    @Test func reimportingProgressKeepsTheExistingRecords() {
        let store = makeInMemoryStore()
        let backup = LibraryBackup(lists: [], shows: [
            .init(tmdbID: 5, name: "S", posterPath: nil, isWatched: nil, isCaughtUp: nil,
                  watchListOptOut: nil, tracked: nil,
                  seasons: [], episodes: [.init(season: 1, episode: 1, watchedAt: .utc(2020, 1, 1))])
        ])
        _ = LibraryBackup.merge(backup, using: store)
        store.setEpisodeWatchedDate(.utc(2024, 6, 6), showID: 5, season: 1, episode: 1)
        _ = LibraryBackup.merge(backup, using: store)

        #expect(WatchedEpisode.all(showTmdbID: 5, in: store.context).count == 1)
        #expect(store.episodeWatchedDate(showID: 5, season: 1, episode: 1) == .utc(2024, 6, 6))
    }

    @Test func mergeCreatesCustomListAndSetsWatchedFacts() {
        let store = makeInMemoryStore()
        let backup = LibraryBackup(lists: [
            .init(uuid: UUID(), name: "Imported", symbol: "star", colorIndex: 1,
                  kind: LibraryBackup.Kind.custom.rawValue, sortOrder: 5, createdAt: Date(),
                  entries: [LibraryBackup.Entry(movieID: 10, title: "X", posterPath: nil,
                                                releaseDate: nil, dateAdded: Date(),
                                                dateWatched: nil, userRating: nil)]),
            .init(uuid: UUID(), name: "Watched", symbol: "checkmark", colorIndex: 0,
                  kind: LibraryBackup.Kind.watched.rawValue, sortOrder: 2, createdAt: Date(),
                  entries: [LibraryBackup.Entry(movieID: 20, title: "Y", posterPath: nil,
                                                releaseDate: nil, dateAdded: Date(),
                                                dateWatched: .utc(2020, 5, 5), userRating: 4.5)]),
        ])
        let summary = LibraryBackup.merge(backup, using: store)
        #expect(summary.listsCreated == 1)
        #expect(summary.entriesAdded == 2)
        #expect(store.customLists.contains { $0.name == "Imported" })
        #expect(store.isWatched(makeMovie(id: 20)))
        #expect(store.rating(for: makeMovie(id: 20)) == 4.5)
        #expect(store.dateWatched(for: makeMovie(id: 20)) == .utc(2020, 5, 5))
    }

    @Test func mergeSkipsDuplicateListEntries() {
        let store = makeInMemoryStore()
        let uuid = UUID()
        func backup() -> LibraryBackup {
            LibraryBackup(lists: [
                .init(uuid: uuid, name: "L", symbol: "star", colorIndex: 0,
                      kind: LibraryBackup.Kind.custom.rawValue, sortOrder: 0, createdAt: Date(),
                      entries: [LibraryBackup.Entry(movieID: 1, title: "A", posterPath: nil,
                                                    releaseDate: nil, dateAdded: Date(),
                                                    dateWatched: nil, userRating: nil)])
            ])
        }
        _ = LibraryBackup.merge(backup(), using: store)
        let second = LibraryBackup.merge(backup(), using: store)
        #expect(second.entriesSkipped == 1)
        #expect(second.entriesAdded == 0)
        #expect(second.listsCreated == 0)  // existing list reused by UUID
    }

    @Test func mergeIgnoresViewedPseudoList() {
        let store = makeInMemoryStore()
        let backup = LibraryBackup(lists: [
            .init(uuid: UUID(), name: "Viewed", symbol: "eye", colorIndex: 0,
                  kind: LibraryBackup.Kind.viewed.rawValue, sortOrder: 3, createdAt: Date(),
                  entries: [LibraryBackup.Entry(movieID: 1, title: "A", posterPath: nil,
                                                releaseDate: nil, dateAdded: Date(),
                                                dateWatched: nil, userRating: nil)])
        ])
        let summary = LibraryBackup.merge(backup, using: store)
        #expect(summary.entriesAdded == 0)
        #expect(store.viewedCount == 0)
    }
}
