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
struct Movie: Hashable, Identifiable, Codable, Sendable {
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
    var trailers: [MediaTrailer]?
    var bonusCredits = Credits(during: false, after: false)
    var team: [Person] = []
    var creditRole: String?
    /// Billing position in the cast (from a person's movie credits), where 0 is top-billed.
    /// Nil for crew credits and outside that context.
    var creditOrder: Int?
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

    var primaryTrailer: MediaTrailer? {
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
    struct Credits: Codable, Sendable {
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

// MARK: - Image URLs

extension Movie {
    func posterURL(_ size: PosterSize = .w342) -> URL? {
        TMDBWrapper.imageURL(path: poster, size: size.rawValue)
    }

    func backgroundURL(_ size: BackgroundSize = .w1280) -> URL? {
        TMDBWrapper.imageURL(path: background, size: size.rawValue)
    }
}
