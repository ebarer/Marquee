//
//  SearchResults.swift
//  MovieTracker
//
//  The finished output of a `SearchPolicy` run: the candidate sets plus the interlaced ordering.
//

import Foundation

struct SearchResults: Sendable {
    var movies: [Movie] = []
    var shows: [Show] = []
    var results: [MediaRef] = []
    var namedPeople: [Person] = []
    var castPeople: [Person] = []

    static let empty = SearchResults()
}
