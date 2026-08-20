//
//  TMDBWrapper+Person.swift
//  MovieTracker
//

import Foundation

extension TMDBWrapper {
    static func getPerson(id: Int) async throws -> Person {
        let data = try await fetch("/person/\(id)",
                                   queryItems: [URLQueryItem(name: "append_to_response", value: "movie_credits,tv_credits")])
        return translate(person: try decode(PersonRaw.self, from: data))
    }

    static func getCredit(id: String) async throws -> EpisodeCredit {
        let data = try await fetch("/credit/\(id)")
        return try decode(CreditRaw.self, from: data).credit()
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

    static func translate(person p: PersonRaw) -> Person {
        var person = Person(id: p.id, name: p.name)
        person.popularity = p.popularity
        person.profilePicture = p.profilePicture
        person.birthday = p.birthday
        person.placeOfBirth = p.placeOfBirth
        person.bio = p.biography
        person.imdbID = p.imdbID
        person.credits = p.credits()
        person.tvCredits = p.tvCredits()
        return person
    }
}
