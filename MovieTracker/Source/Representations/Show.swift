//
//  Show.swift
//  MovieTracker
//

import Foundation

/// A transient TV show hydrated from TMDB (not persisted). Identity is the TMDB id,
/// so it works as a navigation value and de-duplicates in a Set.
struct Show: Hashable, Identifiable, Codable, Sendable {
    var id: Int
    var name: String
    var firstAirDate: Date?
    var lastAirDate: Date?
    var status: String?
    var overview: String?
    var poster: String?
    var background: String?
    var rating: Double?
    var popularity: Double?
    var voteCount: Int?
    var certification: String?
    var imdbID: String?
    var genres: [String]?
    var networks: [String]?
    /// ISO country codes the show originates in (e.g. ["US"]); used to filter search noise.
    var originCountry: [String]?
    var trailers: [MediaTrailer]?
    var creditRole: String?
    /// Episodes the credited person appeared in (from a person's TV credits); shown in
    /// their filmography instead of the year range. Nil outside that context.
    var episodeCount: Int?
    var creators: [Person] = []
    var recurringCast: [Person] = []
    var seasons: [Season] = []
    var watchByRegion: [String: WatchAvailability]?
    /// A transient navigation hint: which season the detail should open on (e.g. tapping
    /// a season row in the Watched list). Not part of identity.
    var initialSeason: Int?

    func watch(for region: String) -> WatchAvailability? { watchByRegion?[region] }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    // `initialSeason` participates so that the same show opened at different seasons are
    // distinct navigation values — otherwise a List highlights the wrong season's row.
    static func == (lhs: Show, rhs: Show) -> Bool {
        lhs.id == rhs.id && lhs.initialSeason == rhs.initialSeason
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(initialSeason)
    }
}

// MARK: - Air range & status

extension Show {
    private static let endedStatuses: Set<String> = ["ended", "canceled", "cancelled"]

    /// True only when TMDB affirmatively reports the show in production — list and search
    /// payloads omit `status`, and an unknown status must not claim "Present".
    var isOngoing: Bool {
        guard let status = status?.lowercased() else { return false }
        return !Self.endedStatuses.contains(status)
    }

    /// "2019", "2019–2023", or "2021–Present". Falls back to just the start year when we
    /// lack the status/last-air data to decide (e.g. search results); "N/A" with no dates.
    var yearRange: String {
        guard let start = firstAirDate?.year else { return "N/A" }
        if isOngoing { return "\(start)–Present" }
        guard let end = lastAirDate?.year, end != start else { return "\(start)" }
        return "\(start)–\(end)"
    }

    /// Seasons excluding "Specials" (season 0) and unaired placeholders (0 episodes), ordered — the default browsing set.
    var regularSeasons: [Season] {
        seasons.filter { !$0.isSpecials && $0.episodeCount > 0 }.sorted { $0.seasonNumber < $1.seasonNumber }
    }
}

// MARK: - Image URLs

extension Show {
    func posterURL(_ size: PosterSize = .w342) -> URL? {
        TMDBWrapper.imageURL(path: poster, size: size.rawValue)
    }

    func backgroundURL(_ size: BackgroundSize = .w1280) -> URL? {
        TMDBWrapper.imageURL(path: background, size: size.rawValue)
    }
}
