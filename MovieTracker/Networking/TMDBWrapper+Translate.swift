//
//  TMDBWrapper+Translate.swift
//  MovieTracker
//
//  Maps the raw TMDB response types (`TMDBDTO`) onto the app's domain models.
//

import Foundation

extension TMDBWrapper {
    static func translate(movie mv: MovieRaw) -> Movie {
        var movie = Movie(id: mv.id, title: mv.title)

        if let overview = mv.overview, !overview.isEmpty {
            movie.overview = overview
        }

        movie.poster = mv.poster
        movie.background = mv.background
        movie.runtime = mv.runtime
        movie.rating = mv.rating
        movie.popularity = mv.popularity
        movie.imdbID = mv.imdbID

        let releaseInfo = mv.certification()
        if let releaseDate = releaseInfo.releaseDate {
            movie.releaseDate = releaseDate
        } else if let releaseDateString = mv.releaseDateString {
            movie.releaseDate = releaseDateString.toDate(format: .iso8601DAw)
        }

        movie.certification = releaseInfo.certification
        movie.genres = mv.genres()
        movie.bonusCredits = Movie.Credits(mv.bonusCredits())
        movie.team = mv.team()
        movie.trailers = mv.trailers()
        movie.collection = mv.collection()

        return movie
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
        return person
    }
}
