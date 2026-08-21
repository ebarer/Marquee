//
//  SearchModelTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@MainActor
@Suite(.serialized) struct SearchModelTests {
    init() { UserDefaults.standard.removeObject(forKey: "recentSearchResults") }

    private func movie(_ id: Int, _ title: String) -> AnyHashable {
        AnyHashable(Movie(id: id, title: title))
    }

    @Test func visitInsertsMostRecentFirstAndDedupesByIdentity() {
        let model = SearchModel()
        model.query = "matrix"
        model.recordVisit(movie(1, "The Matrix"))
        model.recordVisit(AnyHashable(Show(id: 2, name: "Nightfall")))
        model.recordVisit(movie(1, "The Matrix"))
        #expect(model.recentSearches.map(\.id) == ["movie-1", "show-2"])
    }

    @Test func abandonedSearchIsNotRecorded() {
        let model = SearchModel()
        model.query = "   "
        model.recordVisit(movie(1, "The Matrix"))
        #expect(model.recentSearches.isEmpty)
    }

    @Test func reopeningARecentOutsideSearchBumpsIt() {
        let model = SearchModel()
        model.query = "matrix"
        model.recordVisit(movie(1, "The Matrix"))
        model.recordVisit(movie(2, "Inception"))
        model.query = ""
        model.recordVisit(movie(1, "The Matrix"))
        #expect(model.recentSearches.map(\.id) == ["movie-1", "movie-2"])
    }

    @Test func aTapOutsideSearchIsNotRecorded() {
        let model = SearchModel()
        model.recordVisit(movie(1, "The Matrix"))
        #expect(model.recentSearches.isEmpty)
    }

    @Test func peopleListsAreNotRecorded() {
        let model = SearchModel()
        model.query = "nolan"
        model.recordVisit(AnyHashable(PeopleList(title: "People", people: [])))
        #expect(model.recentSearches.isEmpty)
    }

    @Test func recentsAreCappedAtFifteen() {
        let model = SearchModel()
        model.query = "q"
        for index in 1...20 { model.recordVisit(movie(index, "Title \(index)")) }
        #expect(model.recentSearches.count == 15)
        #expect(model.recentSearches.first?.id == "movie-20")
    }

    @Test func removeAndClearRecents() {
        let model = SearchModel()
        model.query = "q"
        model.recordVisit(movie(1, "A"))
        model.recordVisit(movie(2, "B"))
        guard let first = model.recentSearches.last else { return }
        model.removeRecent(first)
        #expect(model.recentSearches.map(\.id) == ["movie-2"])
        model.clearRecents()
        #expect(model.recentSearches.isEmpty)
    }

    @Test func recentsPersistAcrossInstances() {
        let first = SearchModel()
        first.query = "persisted"
        first.recordVisit(AnyHashable(Person(id: 10, name: "Christopher Nolan")))
        let second = SearchModel()
        #expect(second.recentSearches.map(\.id) == ["person-10"])
        #expect(second.recentSearches.first?.title == "Christopher Nolan")
    }

    @Test func destinationRebuildsTheOpenedSeed() throws {
        var movie = Movie(id: 5, title: "Dune")
        movie.poster = "/dune.jpg"
        movie.releaseDate = DateComponents(calendar: .current, year: 2021, month: 10, day: 22).date
        let item = try #require(RecentSearch(navigationValue: AnyHashable(movie)))
        guard case .movie(let seed) = item.destination else {
            Issue.record("Expected a movie destination")
            return
        }
        #expect(seed.id == 5)
        #expect(seed.title == "Dune")
        #expect(seed.poster == "/dune.jpg")
        #expect(seed.releaseDate == movie.releaseDate)
    }

    @Test func emptyQueryClearsResults() {
        let model = SearchModel()
        model.search("")
        #expect(model.movies.isEmpty)
        #expect(model.results.isEmpty)
        #expect(model.namedPeople.isEmpty)
        #expect(model.castMatchedPeople.isEmpty)
        #expect(model.featuredPeople.isEmpty)
        #expect(model.isLoading == false)
    }

    @Test func placeholderText() {
        #expect(SearchModel.placeholder == "Movies, TV, People, etc.")
    }
}
