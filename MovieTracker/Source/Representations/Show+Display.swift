//
//  Show+Display.swift
//  MovieTracker
//
//  Presentation-only derivations used by rows, cards, and the detail screen.
//

import Foundation

extension Show {
    /// Genres for the metadata strip: at most two, but a compound TMDB genre ("Sci-Fi &
    /// Fantasy") already reads as two, so it fills both slots on its own.
    var genresString: String {
        let chosen = Self.displayGenres(genres ?? [])
        switch chosen.count {
        // A lone compound genre wraps at its ampersand ("Sci-Fi &\nFantasy") so it reads
        // on two lines like a real two-genre pair.
        case 1: return chosen[0].shorten().replacingOccurrences(of: " & ", with: " &\n")
        case 2: return "\(chosen[0].shorten()) &\n\(chosen[1].shorten())"
        default: return "N/A"
        }
    }

    /// Picks genres greedily up to two "visual" slots, where an ampersand genre costs two.
    static func displayGenres(_ genres: [String]) -> [String] {
        var chosen: [String] = []
        var slots = 0
        for genre in genres {
            let cost = genre.contains("&") ? 2 : 1
            if slots + cost > 2 { break }
            chosen.append(genre)
            slots += cost
            if slots >= 2 { break }
        }
        return chosen
    }

    /// Regular (non-specials) season count, and its "3 Seasons" label for rows/cards.
    var seasonCount: Int { regularSeasons.count }

    var seasonCountLabel: String? {
        guard seasonCount > 0 else { return nil }
        return seasonCount == 1 ? "1 Season" : "\(seasonCount) Seasons"
    }

    /// Places a show on a release timeline by its most recent air date, not its premiere, so
    /// an ongoing show sorts near "now". Falls back to the premiere when last-air is unknown.
    var timelineDate: Date? { lastAirDate ?? firstAirDate }

    /// Total episodes across regular seasons (specials excluded).
    var totalEpisodes: Int {
        regularSeasons.reduce(0) { $0 + $1.episodeCount }
    }

    var isExtraneousCredit: Bool { CreditKind.isExtraneous(creditRole) }

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
}
