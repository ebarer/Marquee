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
struct Movie: Hashable, Identifiable {
    var id: Int
    var title: String
    var releaseDate: Date?
    var overview: String?
    var poster: String?
    var background: String?
    var runtime: Int?
    var rating: Double?
    var popularity: Double?
    var certification: String?
    var imdbID: String?
    var genres: [String]?
    var trailers: [MovieTrailer]?
    var bonusCredits = Credits(during: false, after: false)
    var team: [Person] = []
    var creditRole: String?
    var collection: MovieCollection?

    init(id: Int, title: String) {
        self.id = id
        self.title = title
    }

    static func == (lhs: Movie, rhs: Movie) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var duration: String? {
        guard let runtime else { return nil }
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

    /// Credits for "self", "guest", "thanks", etc. that aren't primary roles.
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
    struct Credits {
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
}

struct MovieTrailer: Identifiable {
    var id: String
    var title: String
    var key: String
    var type: TrailerType
    var site: String
    var official: Bool
    var publishedAt: String

    enum TrailerType: String {
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

    /// Used to help identify the primary trailer.
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

    /// Standard YouTube watch URL, suitable for opening in Safari.
    var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}

// MARK: - Collection (franchise)

/// A collection of movies comprising a franchise (e.g. Star Wars).
struct MovieCollection {
    var id: Int
    var name: String
    var poster: String?
    var background: String?
}
