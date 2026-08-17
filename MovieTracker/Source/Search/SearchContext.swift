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
    /// Cast credited as the searched character, most notable film first.
    var filmCharacterPeople: [Person]
    /// The billing of each film the query names, in rank order — what fills the strip.
    var filmLeads: [(filmID: Int, people: [Person])]
    /// The first leads of every hydrated film, named by the query or not — the list leader
    /// donates these even when it arrived via franchise expansion (The Dark Knight/"batman").
    var leadsByFilmID: [Int: [Person]]
    /// Cast surfaced from the top matched show. Kept apart from the film's until the results
    /// are ranked, which is what decides which of the two the People strip opens on.
    var showCastPeople: [Person]
    /// Hydrated details (collection + cast) for the top movies, fetched once by
    /// HydrateTopMoviesTool so the franchise and cast tools don't each re-fetch.
    var movieDetails: [Int: Movie]
    /// Movies surfaced as related (e.g. franchise-collection siblings) that don't literally
    /// match the title, keyed by id to the title relevance of the match that surfaced them.
    var relatedMovies: [Int: Int]

    init(query: String, movies: [Movie] = [], shows: [Show] = [],
         namedPeople: [Person] = [], filmCharacterPeople: [Person] = [],
         filmLeads: [(filmID: Int, people: [Person])] = [],
         leadsByFilmID: [Int: [Person]] = [:],
         showCastPeople: [Person] = [],
         movieDetails: [Int: Movie] = [:], relatedMovies: [Int: Int] = [:]) {
        self.query = query
        self.needle = SearchMatching.normalized(SearchMatching.articleStripped(query))
        self.movies = movies
        self.shows = shows
        self.namedPeople = namedPeople
        self.filmCharacterPeople = filmCharacterPeople
        self.filmLeads = filmLeads
        self.leadsByFilmID = leadsByFilmID
        self.showCastPeople = showCastPeople
        self.movieDetails = movieDetails
        self.relatedMovies = relatedMovies
    }
}
