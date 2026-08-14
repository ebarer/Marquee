//
//  Episode.swift
//  MovieTracker
//

import Foundation

/// A single episode within a `Season`, hydrated from TMDB.
struct Episode: Hashable, Identifiable, Codable, Sendable {
    var id: Int
    /// The owning show's TMDB id, stamped when a season is fetched (episodes don't carry
    /// it from TMDB). Lets a standalone episode toggle its watched state.
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

    /// "S1 · E3"-style label for the episode row.
    var code: String { "S\(seasonNumber) · E\(episodeNumber)" }

    /// Whether the air day has arrived in the device's timezone; bulk marks skip the ones that
    /// haven't. An unknown air date counts as aired — TMDB omits it in some back catalogues.
    var hasAired: Bool { hasAired(asOf: Date()) }

    /// Takes the instant to judge against so the local-midnight boundary is testable.
    func hasAired(asOf reference: Date) -> Bool {
        guard let airDate else { return true }
        return !airDate.isInTheFuture(asOf: reference)
    }

    var duration: String? {
        guard let runtime else { return nil }
        guard runtime >= 60 else { return "\(runtime) min" }
        return "\(runtime / 60) hr \(runtime % 60) min"
    }

    func stillURL(_ size: BackgroundSize = .w300) -> URL? {
        TMDBWrapper.imageURL(path: still, size: size.rawValue)
    }
}
