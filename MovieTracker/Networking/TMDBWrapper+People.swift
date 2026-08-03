//
//  TMDBWrapper+People.swift
//  MovieTracker
//

import Foundation

extension TMDBWrapper {
    static func getPerson(id: Int) async throws -> Person {
        let data = try await fetch("/person/\(id)",
                                   queryItems: [URLQueryItem(name: "append_to_response", value: "movie_credits")])
        return translate(person: try decode(PersonRaw.self, from: data))
    }

    static func searchForPeople(query: String, page: Int = 1) async throws -> PagedResult<Person> {
        guard !query.isEmpty else { return .empty }
        let data = try await fetch("/search/person", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
        ])
        let root = try decode(RootRaw<PersonRaw>.self, from: data)
        return PagedResult(items: root.results.map(translate(person:)),
                           totalResults: root.totalResults, totalPages: root.totalPages)
    }
}
