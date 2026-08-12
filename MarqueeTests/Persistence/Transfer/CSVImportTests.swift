//
//  CSVImportTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@Suite struct CSVParseTests {
    private let header = "Title,Genre,Release Date,Watched,Your Rating,TMDB URL,TMDB ID,Watched Date,Comments"

    @Test func parsesTypicalRows() throws {
        let csv = """
        \(header)
        The Matrix,Action,3/31/99,1,5,https://tmdb/603,603,,
        Inception,Sci-Fi,7/16/10,0,,https://tmdb/27205,27205,,
        """
        let records = try CSVMovieRecord.parse(data: Data(csv.utf8))
        #expect(records.count == 2)
        #expect(records[0].movieID == 603)
        #expect(records[0].watched)
        #expect(records[0].userRating == 5)
        #expect(records[1].movieID == 27205)
        #expect(records[1].watched == false)
        #expect(records[1].userRating == nil)
    }

    @Test func resolvesColumnsByHeaderNameRegardlessOfOrder() throws {
        let csv = """
        TMDB ID,Watched,Title
        550,1,Fight Club
        """
        let records = try CSVMovieRecord.parse(data: Data(csv.utf8))
        #expect(records.first?.movieID == 550)
        #expect(records.first?.title == "Fight Club")
        #expect(records.first?.watched == true)
    }

    @Test func skipsRowsWithoutValidID() throws {
        let csv = """
        \(header)
        No ID,Action,,0,,,,,
        Bad ID,Action,,0,,,notanumber,,
        Good,Action,,0,,,42,,
        """
        let records = try CSVMovieRecord.parse(data: Data(csv.utf8))
        #expect(records.map(\.movieID) == [42])
    }

    @Test func handlesQuotedFieldsWithCommasAndNewlines() throws {
        // Quoted commas and an embedded newline. LF endings only — the parser mishandles
        // CRLF (Swift reads "\r\n" as one grapheme cluster), tracked as a separate bug.
        let csv = "\(header)\n\"Movie, The\",\"Drama\",1/1/20,1,4,url,7,,\"Line1\nLine2\"\n"
        let records = try CSVMovieRecord.parse(data: Data(csv.utf8))
        #expect(records.count == 1)
        #expect(records[0].title == "Movie, The")
        #expect(records[0].movieID == 7)
    }

    @Test func handlesDoubledQuoteEscape() throws {
        let csv = "\(header)\n\"She said \"\"hi\"\"\",Drama,,0,,,99,,\n"
        let records = try CSVMovieRecord.parse(data: Data(csv.utf8))
        #expect(records[0].title == "She said \"hi\"")
    }

    @Test func parsesReleaseDate() throws {
        let csv = "\(header)\nA,Action,7/19/07,0,,,1,,\n"
        let records = try CSVMovieRecord.parse(data: Data(csv.utf8))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let comps = cal.dateComponents([.year, .month, .day], from: records[0].releaseDate!)
        #expect(comps.year == 2007 && comps.month == 7 && comps.day == 19)
    }

    @Test func emptyFileThrows() {
        #expect(throws: CSVImportError.self) {
            _ = try CSVMovieRecord.parse(data: Data())
        }
    }

    @Test func missingTMDBIDColumnThrows() {
        let csv = "Title,Watched\nA,1\n"
        #expect(throws: CSVImportError.self) {
            _ = try CSVMovieRecord.parse(data: Data(csv.utf8))
        }
    }

    @Test func skipsBlankTrailingLines() throws {
        let csv = "\(header)\nA,Action,,0,,,1,,\n\n\n"
        let records = try CSVMovieRecord.parse(data: Data(csv.utf8))
        #expect(records.count == 1)
    }
}

@MainActor
@Suite(.serialized) struct CSVMergeTests {
    @Test func mergeSplitsWatchedAndWatchListAndSkipsPresent() async {
        URLProtocolStub.install { _ in (Data(#"{"id":1,"title":"T","poster_path":"/p.jpg","release_date":"2000-01-01"}"#.utf8), 200) }
        defer { URLProtocolStub.remove() }

        let store = makeInMemoryStore()
        let records = [
            CSVMovieRecord(movieID: 1, title: "Watched One", releaseDate: nil, watched: true, userRating: 4),
            CSVMovieRecord(movieID: 2, title: "ToWatch One", releaseDate: nil, watched: false, userRating: nil),
        ]
        var lastProgress = (0, 0)
        let summary = await CSVMovieRecord.merge(records, using: store) { done, total in
            lastProgress = (done, total)
        }
        #expect(summary.entriesAdded == 2)
        #expect(store.isWatched(makeMovie(id: 1)))
        #expect(store.rating(for: makeMovie(id: 1)) == 4)
        #expect(store.isInWatchList(makeMovie(id: 2)))
        #expect(lastProgress == (2, 2))

        // Re-importing the same records skips both.
        let again = await CSVMovieRecord.merge(records, using: store) { _, _ in }
        #expect(again.entriesSkipped == 2)
        #expect(again.entriesAdded == 0)
    }
}
