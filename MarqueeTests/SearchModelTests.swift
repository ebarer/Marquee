//
//  SearchModelTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@MainActor
@Suite(.serialized) struct SearchModelTests {
    init() { UserDefaults.standard.removeObject(forKey: "recentSearches") }

    @Test func commitInsertsMostRecentFirstAndDedupesCaseInsensitively() {
        let model = SearchModel()
        model.query = "Matrix"; model.commit()
        model.query = "Inception"; model.commit()
        model.query = "matrix"; model.commit()  // dupe of "Matrix"
        #expect(model.recentSearches == ["matrix", "Inception"])
    }

    @Test func commitIgnoresBlankQuery() {
        let model = SearchModel()
        model.query = "   "; model.commit()
        #expect(model.recentSearches.isEmpty)
    }

    @Test func recentsAreCappedAtFifteen() {
        let model = SearchModel()
        for i in 1...20 { model.query = "q\(i)"; model.commit() }
        #expect(model.recentSearches.count == 15)
        #expect(model.recentSearches.first == "q20")
    }

    @Test func removeAndClearRecents() {
        let model = SearchModel()
        model.query = "A"; model.commit()
        model.query = "B"; model.commit()
        model.removeRecent("a")  // case-insensitive
        #expect(model.recentSearches == ["B"])
        model.clearRecents()
        #expect(model.recentSearches.isEmpty)
    }

    @Test func recentsPersistAcrossInstances() {
        let first = SearchModel()
        first.query = "Persisted"; first.commit()
        let second = SearchModel()
        #expect(second.recentSearches == ["Persisted"])
    }

    @Test func emptyQueryClearsResults() {
        let model = SearchModel()
        model.search("")
        #expect(model.movies.isEmpty)
        #expect(model.people.isEmpty)
    }

    @Test func scopePlaceholder() {
        #expect(SearchModel.Scope.movies.placeholder == "Movies, People, etc.")
        #expect(SearchModel.Scope.allCases.count == 2)
    }
}
