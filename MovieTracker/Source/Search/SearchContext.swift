//
//  SearchContext.swift
//  MovieTracker
//
//  The mutable working set threaded through a policy's tools, augmented before ranking.
//

import Foundation

struct SearchContext: Sendable {
    let query: String
    let needle: String

    var movies: [Movie]
    var shows: [Show]
    var namedPeople: [Person]
    var filmCharacterPeople: [Person]
    var filmLeads: [(filmID: Int, people: [Person])]
    var leadsByFilmID: [Int: [Person]]
    // Kept apart from the film cast until ranking, which decides which the People strip opens on.
    var showCastPeople: [Person]
    // Hydrated once by HydrateTopMoviesTool so the franchise and cast tools don't each re-fetch.
    var movieDetails: [Int: Movie]
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
