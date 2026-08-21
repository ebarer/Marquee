//
//  Show.swift
//  MovieTracker
//

import Foundation

/// A transient TV show hydrated from TMDB. Identity is the TMDB id, so it works as a navigation value.
struct Show: Hashable, Identifiable, Codable, Sendable {
    var id: Int
    var name: String
    var firstAirDate: Date?
    var lastAirDate: Date?
    var nextAirDate: Date?
    var status: String?
    var overview: String?
    var poster: String?
    var background: String?
    var rating: Double?
    var popularity: Double?
    var voteCount: Int?
    var certification: String?
    var imdbID: String?
    var wikidataID: String?
    var genres: [String]?
    var networks: [String]?
    var originCountry: [String]?
    var trailers: [MediaTrailer]?
    var creditRole: String?
    var creditJobs: [String]?
    var creditKind: CreditKind?
    var episodeCount: Int?
    // TMDB can file one person under several credit ids for the same show.
    var creditIDs: [String] = []
    // Each credit id's own character, since the ids can disagree and `creditRole` joins them all.
    var creditRolesByID: [String: String]?
    var creators: [Person] = []
    var recurringCast: [Person] = []
    // Optional so cache entries written before it existed still decode.
    var guestCast: [Person]?
    // Optional so cache entries written before it existed still decode.
    var castEpisodeCounts: [Int: Int]?
    var seasons: [Season] = []
    var watchByRegion: [String: WatchAvailability]?
    // A navigation hint, not part of identity.
    var initialSeason: Int?
    // Optional so cache entries written before it existed still decode.
    var isFullDetail: Bool?

    func watch(for region: String) -> WatchAvailability? { watchByRegion?[region] }

    // Can't be inferred from the fields: list and search records land with the same shape.
    var isDetailPayload: Bool { isFullDetail == true }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    // `initialSeason` participates so the same show opened at different seasons are distinct navigation
    // values; otherwise a List highlights the wrong season's row.
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

    // List and search payloads omit `status`, and an unknown status must not claim "Present".
    var isOngoing: Bool {
        guard let status = status?.lowercased() else { return false }
        return !Self.endedStatuses.contains(status)
    }

    var yearRange: String {
        guard let start = firstAirDate?.year else { return "N/A" }
        if isOngoing { return "\(start)–Present" }
        guard let end = lastAirDate?.year, end != start else { return "\(start)" }
        return "\(start)–\(end)"
    }

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
