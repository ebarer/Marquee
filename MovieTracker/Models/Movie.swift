//
//  Movie.swift
//  MovieTracker
//
//  Created by Elliot Barer on 5/31/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import Foundation

/// A transient movie hydrated from TMDB (not persisted). Identity is the TMDB id,
/// so it works as a navigation value and de-duplicates in a Set.
struct Movie: Hashable, Identifiable, Codable {
    var id: Int
    var title: String
    var releaseDate: Date?
    var overview: String?
    var poster: String?
    var background: String?
    var runtime: Int?
    var rating: Double?
    var popularity: Double?
    var voteCount: Int?
    var certification: String?
    var imdbID: String?
    var genres: [String]?
    var trailers: [MovieTrailer]?
    var bonusCredits = Credits(during: false, after: false)
    var team: [Person] = []
    var creditRole: String?
    var collection: MovieCollection?
    var watchByRegion: [String: WatchAvailability]?

    func watch(for region: String) -> WatchAvailability? { watchByRegion?[region] }

    init(id: Int, title: String) {
        self.id = id
        self.title = title
    }

    static func == (lhs: Movie, rhs: Movie) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var duration: String? {
        // A 0 runtime means unknown (e.g. an unreleased film) — show nothing, not "0 hr 0 min".
        guard let runtime, runtime > 0 else { return nil }
        return "\(runtime / 60) hr \(runtime % 60) min"
    }

    var primaryTrailer: MovieTrailer? {
        trailers?
            .filter { $0.site == "YouTube" && $0.isTrailer }
            .max { lhs, rhs in
                if lhs.primaryScore != rhs.primaryScore {
                    return lhs.primaryScore < rhs.primaryScore
                }
                return lhs.publishedAt < rhs.publishedAt
            }
    }

    var isExtraneousCredit: Bool {
        guard let role = creditRole?.lowercased() else { return false }
        if role == "self" || role.hasPrefix("self ") || role.hasPrefix("self-") { return true }
        if role.contains("thanks") { return true }
        return false
    }

    var genresString: String {
        switch genres?.count {
        case 1: return genres![0].shorten()
        case 2: return "\(genres![0].shorten()) &\n\(genres![1].shorten())"
        default: return "N/A"
        }
    }

    var bonusString: String {
        switch bonusCredits.raw {
        case (false, false): return "None"
        case (false, true): return "After"
        case (true, false): return "During"
        case (true, true): return "During + After"
        }
    }
}

extension Movie {
    struct Credits: Codable {
        var during: Bool
        var after: Bool

        init(during: Bool, after: Bool) {
            self.during = during
            self.after = after
        }

        init(_ val: (during: Bool, after: Bool)) {
            self.during = val.during
            self.after = val.after
        }

        var raw: (Bool, Bool) { (during, after) }
    }
}

// MARK: - Image Size Enumerations

extension Movie {
    enum PosterSize: String {
        case w92  = "w92"
        case w154 = "w154"
        case w185 = "w185"
        case w342 = "w342"
        case w500 = "w500"
        case w780 = "w780"
        case orig = "original"
    }

    enum BackgroundSize: String {
        case w300  = "w300"
        case w780  = "w780"
        case w1280 = "w1280"
        case orig  = "original"
    }

    func posterURL(_ size: PosterSize = .w342) -> URL? {
        TMDBWrapper.imageURL(path: poster, size: size.rawValue)
    }

    func backgroundURL(_ size: BackgroundSize = .w1280) -> URL? {
        TMDBWrapper.imageURL(path: background, size: size.rawValue)
    }
}

struct MovieTrailer: Identifiable, Codable {
    var id: String
    var title: String
    var key: String
    var type: TrailerType
    var site: String
    var official: Bool
    var publishedAt: String

    enum TrailerType: String, Codable {
        case Teaser = "Teaser"
        case Trailer = "Trailer"
        case Clip = "Clip"
        case Featurette = "Featurette"
        case other = "Other"
    }

    init(id: String, title: String, key: String, type: String, site: String, official: Bool, publishedAt: String) {
        self.id = id
        self.title = title
        self.key = key
        self.type = TrailerType(rawValue: type) ?? .other
        self.site = site
        self.official = official
        self.publishedAt = publishedAt
    }

    var isTrailer: Bool {
        type == .Trailer || type == .Teaser
    }

    var primaryScore: Int {
        var score: Int
        switch type {
        case .Trailer: score = 40
        case .Teaser: score = 30
        default: score = 0
        }
        if official { score += 5 }
        return score
    }

    var url: URL? {
        URL(string: "https://www.youtube.com/embed")?.appendingPathComponent(key)
    }

    var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}

// MARK: - Collection (franchise)

struct MovieCollection: Codable {
    var id: Int
    var name: String
    var poster: String?
    var background: String?
}
