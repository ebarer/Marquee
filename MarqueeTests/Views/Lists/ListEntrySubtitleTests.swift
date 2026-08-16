//
//  ListEntrySubtitleTests.swift
//  MarqueeTests
//
//  The watched-date line a list row shows: its wording per media type, and how the season
//  row folds it onto the season line.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct ListEntrySubtitleTests {
    let store = makeInMemoryStore()

    private static let watchedDay = Date.utc(2026, 8, 16)
    private var stamp: String { Self.watchedDay.toString() }

    private func context(_ selection: ListSelection) -> ListEntryContext {
        ListEntryContext(selection: selection, isWatchList: false, watchListIDs: [],
                         listColor: .appAccent)
    }

    private func snapshot(mediaType: MediaType = .movie, season: Int? = nil,
                          seasonWatched: Int? = nil, seasonTotal: Int? = nil,
                          dateWatched: Date? = watchedDay) -> MediaSnapshot {
        let item = MediaItem(tmdbID: 1, mediaType: mediaType, title: "Shogun")
        store.context.insert(item)
        return MediaSnapshot(persistentID: item.persistentModelID, tmdbID: 1,
                             mediaType: mediaType, title: "Shogun", posterPath: nil,
                             releaseDate: nil, sortDate: nil, seasonNumber: season,
                             seasonWatched: seasonWatched, seasonTotal: seasonTotal,
                             nextEpisodeDate: nil, runtime: nil,
                             dateWatched: dateWatched, userRating: nil)
    }

    // MARK: - Wording

    @Test func movieOnWatchedListReadsAsWatched() {
        let subtitle = context(.watched).subtitle(for: snapshot())
        #expect(subtitle == "Watched \(stamp)")
    }

    /// A season is finished, not watched: the show it belongs to may still be running.
    @Test func seasonOnWatchedListReadsAsFinished() {
        let entry = snapshot(mediaType: .tv, season: 1, seasonWatched: 10, seasonTotal: 10)
        #expect(context(.watched).subtitle(for: entry) == "Finished \(stamp)")
    }

    @Test func noSubtitleOffTheWatchedList() {
        for selection in [ListSelection.viewed, .list(UUID())] {
            #expect(context(selection).subtitle(for: snapshot()) == nil)
            let season = snapshot(mediaType: .tv, season: 1, seasonWatched: 10, seasonTotal: 10)
            #expect(context(selection).subtitle(for: season) == nil)
        }
    }

    @Test func noSubtitleWithoutAWatchedDate() {
        let entry = snapshot(mediaType: .tv, season: 1, seasonWatched: 10, seasonTotal: 10,
                             dateWatched: nil)
        #expect(context(.watched).subtitle(for: entry) == nil)
    }

    // MARK: - The season row's one-line subtitle

    @Test func finishedDateSitsOnTheSeasonLine() {
        let entry = snapshot(mediaType: .tv, season: 2, seasonWatched: 10, seasonTotal: 10)
        let row = SeasonRowContent(entry: entry, detail: context(.watched).subtitle(for: entry))
        #expect(row.subtitle == "Season 2\(SeasonRowContent.separator)Finished \(stamp)")
    }

    /// Without a date the line is the season alone — no dangling separator or trailing space.
    @Test func seasonLineAloneWhenThereIsNoDetail() {
        let entry = snapshot(mediaType: .tv, season: 2, seasonWatched: 10, seasonTotal: 10)
        #expect(SeasonRowContent(entry: entry).subtitle == "Season 2")
    }

    @Test func partialSeasonKeepsItsEpisodeProgress() {
        let entry = snapshot(mediaType: .tv, season: 3, seasonWatched: 5, seasonTotal: 8,
                             dateWatched: nil)
        let separator = SeasonRowContent.separator
        #expect(SeasonRowContent(entry: entry).subtitle
                == "Season 3\(separator)Ep. 6 of 8")
    }

    /// A tracked-season row carries no season number until the show resolves.
    @Test func noSeasonNumberYieldsAnEmptyLine() {
        #expect(SeasonRowContent(entry: snapshot(mediaType: .tv)).subtitle.isEmpty)
    }
}
