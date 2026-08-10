//
//  SearchResults.swift
//  MovieTracker
//
//  The finished output of a SearchPolicy run: the shaped candidate sets plus the
//  interlaced movie+TV ordering the UI shows. People are surfaced via SearchModel.
//

import Foundation

struct SearchResults: Sendable {
    var movies: [Movie] = []
    var shows: [Show] = []
    /// Movies and shows interlaced and ranked — the list the UI renders.
    var results: [MediaRef] = []
    var namedPeople: [Person] = []
    /// Cast surfaced from matched titles (film + top show).
    var castPeople: [Person] = []

    static let empty = SearchResults()
}
