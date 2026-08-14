//
//  SearchContext.swift
//  MovieTracker
//
//  The mutable working set threaded through a policy's tools: each tool augments
//  it (adds candidates, filters noise, extracts cast) before ranking.
//

import Foundation

struct SearchContext: Sendable {
    /// Trimmed, lowercased query.
    let query: String
    /// Article-stripped + normalized query, for title matching ("The Office"/"office").
    let needle: String

    var movies: [Movie]
    var shows: [Show]
    /// Direct `/search/person` hits.
    var namedPeople: [Person]
    /// Cast surfaced from matched titles (film leads/character matches + top show's cast).
    var castPeople: [Person]
    /// Hydrated details (collection + cast) for the top movies, fetched once by
    /// HydrateTopMoviesTool so the franchise and cast tools don't each re-fetch.
    var movieDetails: [Int: Movie]
    /// Movies surfaced as related (e.g. franchise-collection siblings) that don't literally
    /// match the title, keyed by id to the title relevance of the match that surfaced them.
    var relatedMovies: [Int: Int]

    init(query: String, movies: [Movie] = [], shows: [Show] = [],
         namedPeople: [Person] = [], castPeople: [Person] = [],
         movieDetails: [Int: Movie] = [:], relatedMovies: [Int: Int] = [:]) {
        self.query = query
        self.needle = SearchMatching.normalized(SearchMatching.articleStripped(query))
        self.movies = movies
        self.shows = shows
        self.namedPeople = namedPeople
        self.castPeople = castPeople
        self.movieDetails = movieDetails
        self.relatedMovies = relatedMovies
    }
}
