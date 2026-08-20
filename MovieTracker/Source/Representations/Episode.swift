//
//  Episode.swift
//  MovieTracker
//

import Foundation

/// A single episode within a `Season`, hydrated from TMDB.
struct Episode: Hashable, Identifiable, Codable, Sendable {
    var id: Int
    // TMDB episodes don't carry the show id, so a season fetch stamps it here.
    var showTmdbID: Int = 0
    var seasonNumber: Int
    var episodeNumber: Int
    var name: String
    var overview: String?
    var still: String?
    var runtime: Int?
    var rating: Double?
    var airDate: Date?
    var guestCast: [Person] = []
    var crew: [Person] = []

    init(id: Int, seasonNumber: Int, episodeNumber: Int, name: String) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.name = name
    }

    static func == (lhs: Episode, rhs: Episode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var code: String { "S\(seasonNumber) · E\(episodeNumber)" }

    // An unknown air date counts as aired; TMDB omits it in some back catalogues.
    var hasAired: Bool { hasAired(asOf: Date()) }

    func hasAired(asOf reference: Date) -> Bool {
        guard let airDate else { return true }
        return !airDate.isInTheFuture(asOf: reference)
    }

    var duration: String? { RuntimeLabel.duration(minutes: runtime) }

    func stillURL(_ size: BackgroundSize = .w300) -> URL? {
        TMDBWrapper.imageURL(path: still, size: size.rawValue)
    }
}
