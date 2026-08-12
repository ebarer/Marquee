//
//  TMDBNetworkTests.swift
//  MarqueeTests
//
//  Exercises the client's request/decode path with URLSession.shared stubbed.
//

import Testing
import Foundation
@testable import Marquee

@Suite(.serialized) struct TMDBNetworkTests {

    private func withStub(_ json: String, status: Int = 200,
                          _ body: () async throws -> Void) async rethrows {
        URLProtocolStub.install { _ in (Data(json.utf8), status) }
        defer { URLProtocolStub.remove() }
        try await body()
    }

    @Test func getMovieDecodesAndTranslates() async throws {
        try await withStub(#"{"id":603,"title":"The Matrix","runtime":136}"#) {
            let movie = try await TMDBWrapper.getMovie(id: 603)
            #expect(movie.id == 603)
            #expect(movie.title == "The Matrix")
            #expect(movie.runtime == 136)
            #expect(URLProtocolStub.requestedURLs.first?.absoluteString.contains("/movie/603") == true)
        }
    }

    @Test func requestsCarryAPIKeyAndLocale() async throws {
        try await withStub(#"{"id":1,"title":"X"}"#) {
            _ = try await TMDBWrapper.getMovie(id: 1)
            let query = URLProtocolStub.requestedURLs.first?.query ?? ""
            #expect(query.contains("api_key="))
            #expect(query.contains("include_adult=false"))
            #expect(query.contains("certification_country="))  // movie endpoints are certified
        }
    }

    @Test func moviePageReturnsPagination() async throws {
        try await withStub(#"{"results":[{"id":1,"title":"A"},{"id":2,"title":"B"}],"total_results":2,"total_pages":5}"#) {
            let page = try await TMDBWrapper.moviesPopular(page: 1)
            #expect(page.items.count == 2)
            #expect(page.totalPages == 5)
            #expect(page.totalResults == 2)
        }
    }

    @Test func invalidPageThrowsBeforeNetwork() async {
        URLProtocolStub.install { _ in (Data(), 200) }
        defer { URLProtocolStub.remove() }
        await #expect(throws: FetchError.self) {
            _ = try await TMDBWrapper.moviesPopular(page: 0)
        }
        #expect(URLProtocolStub.requestedURLs.isEmpty)  // never hit the network
    }

    @Test func emptySearchQueryShortCircuits() async throws {
        URLProtocolStub.install { _ in (Data(), 200) }
        defer { URLProtocolStub.remove() }
        let movies = try await TMDBWrapper.searchForMovies(query: "")
        let people = try await TMDBWrapper.searchForPeople(query: "")
        #expect(movies.items.isEmpty)
        #expect(people.items.isEmpty)
        #expect(URLProtocolStub.requestedURLs.isEmpty)
    }

    @Test func searchForMoviesEncodesQuery() async throws {
        try await withStub(#"{"results":[{"id":9,"title":"Found"}],"total_results":1,"total_pages":1}"#) {
            let result = try await TMDBWrapper.searchForMovies(query: "the matrix")
            #expect(result.items.map(\.id) == [9])
            let url = URLProtocolStub.requestedURLs.first
            #expect(url?.path.contains("/search/movie") == true)
            #expect((url?.query?.contains("query=the%20matrix") ?? false)
                    || (url?.query?.contains("query=the+matrix") ?? false))
        }
    }

    @Test func searchForPeopleDecodes() async throws {
        try await withStub(#"{"results":[{"id":7,"name":"Actor","popularity":1.0}],"total_results":1,"total_pages":1}"#) {
            let result = try await TMDBWrapper.searchForPeople(query: "actor")
            #expect(result.items.map(\.id) == [7])
        }
    }

    @Test func getCollectionSortsChronologically() async throws {
        try await withStub("""
        {"id":1,"name":"Saga","parts":[
          {"id":2,"title":"Sequel","release_date":"2010-01-01"},
          {"id":1,"title":"Original","release_date":"2000-01-01"}
        ]}
        """) {
            let movies = try await TMDBWrapper.getCollection(id: 1)
            #expect(movies.map(\.id) == [1, 2])  // oldest first
        }
    }
}
