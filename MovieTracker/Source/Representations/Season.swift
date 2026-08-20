//
//  Season.swift
//  MovieTracker
//

import Foundation

/// A single season of a `Show`. Episodes are hydrated lazily per season from TMDB.
struct Season: Hashable, Identifiable, Codable, Sendable {
    var id: Int
    var seasonNumber: Int
    var name: String
    var overview: String?
    var poster: String?
    var airDate: Date?
    var episodeCount: Int
    var episodes: [Episode] = []
    var cast: [Person] = []

    init(id: Int, seasonNumber: Int, name: String, episodeCount: Int = 0) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.name = name
        self.episodeCount = episodeCount
    }

    static func == (lhs: Season, rhs: Season) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var isSpecials: Bool { seasonNumber == 0 }

    var startYear: Int? { airDate?.year }

    func posterURL(_ size: PosterSize = .w342) -> URL? {
        TMDBWrapper.imageURL(path: poster, size: size.rawValue)
    }
}
