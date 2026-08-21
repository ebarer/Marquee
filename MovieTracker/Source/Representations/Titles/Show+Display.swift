//
//  Show+Display.swift
//  MovieTracker
//
//  Presentation-only derivations used by rows, cards, and the detail screen.
//

import Foundation

extension Show {
    // A compound TMDB genre ("Sci-Fi & Fantasy") already reads as two, so it fills both slots.
    var genresString: String {
        let chosen = Self.displayGenres(genres ?? [])
        switch chosen.count {
        // A lone compound genre wraps at its ampersand so it reads on two lines like a real pair.
        case 1: return chosen[0].shorten().replacingOccurrences(of: " & ", with: " &\n")
        case 2: return "\(chosen[0].shorten()) &\n\(chosen[1].shorten())"
        default: return "N/A"
        }
    }

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

    var seasonCount: Int { regularSeasons.count }

    var seasonCountLabel: String? {
        guard seasonCount > 0 else { return nil }
        return seasonCount == 1 ? "1 Season" : "\(seasonCount) Seasons"
    }

    var timelineDate: Date? { lastAirDate ?? firstAirDate }

    var totalEpisodes: Int {
        regularSeasons.reduce(0) { $0 + $1.episodeCount }
    }

    var creditRoleSummary: String? {
        let parts = ([creditRole] + (creditJobs ?? [])).compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // The resolved kinds where they exist: the role line is edited for reading and no longer says
    // "Self" for every appearance. Credits that never went through the merge keep the text test.
    var isExtraneousCredit: Bool {
        if let creditKinds { return creditKinds == [.appearance] }
        return CreditKind.isExtraneous(creditRoleSummary)
    }

    var rankedTrailers: [MediaTrailer] { MediaTrailer.ranked(trailers) }

    var primaryTrailer: MediaTrailer? { rankedTrailers.first }
}
