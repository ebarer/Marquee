//
//  RecentSearch.swift
//  MovieTracker
//

import Foundation

/// A search result that was opened, stored as the seed its detail screen reopens on.
struct RecentSearch: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case movie, show, person
    }

    enum Destination: Hashable, Sendable {
        case movie(Movie)
        case show(Show)
        case person(Person)
    }

    let kind: Kind
    let mediaID: Int
    let title: String
    let imagePath: String?
    let date: Date?

    var id: String { "\(kind.rawValue)-\(mediaID)" }

    // Only the seed fields are stored; a detail screen faults the rest in around them.
    var destination: Destination {
        switch kind {
        case .movie:
            var movie = Movie(id: mediaID, title: title)
            movie.poster = imagePath
            movie.releaseDate = date
            return .movie(movie)
        case .show:
            var show = Show(id: mediaID, name: title)
            show.poster = imagePath
            show.firstAirDate = date
            return .show(show)
        case .person:
            var person = Person(id: mediaID, name: title)
            person.profilePicture = imagePath
            return .person(person)
        }
    }
}

extension RecentSearch {
    init?(navigationValue: AnyHashable) {
        switch navigationValue.base {
        case let movie as Movie:
            self.init(kind: .movie, mediaID: movie.id, title: movie.title,
                      imagePath: movie.poster, date: movie.releaseDate)
        case let show as Show:
            self.init(kind: .show, mediaID: show.id, title: show.name,
                      imagePath: show.poster, date: show.firstAirDate)
        case let person as Person:
            self.init(kind: .person, mediaID: person.id, title: person.name,
                      imagePath: person.profilePicture, date: nil)
        default:
            return nil
        }
    }
}
