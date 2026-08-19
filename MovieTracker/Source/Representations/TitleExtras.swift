//
//  TitleExtras.swift
//  MovieTracker
//

import Foundation

/// What Wikidata adds to a title beyond TMDB's payload: the awards behind the metadata cell,
/// and the outside pages the nav bar links to. Both land after the detail request.
struct TitleExtras: Equatable, Sendable {
    var awards = AwardsDigest()
    var links: [ExternalLink] = []
    /// Wikidata has answered. Separates "still fetching" from "fetched, and this title won
    /// nothing" — only the second may report "None".
    var resolved = false
}

// MARK: - Previews

extension TitleExtras {
    static var preview: TitleExtras {
        TitleExtras(awards: .preview, links: [
            ExternalLink.rottenTomatoes(slug: "m/inception", title: "Inception"),
            ExternalLink.imdb(id: "tt1375666"),
        ].compactMap { $0 }, resolved: true)
    }

    /// The common thin case: TMDB knows the IMDb id, Wikidata has no entry — so the awards cell
    /// reads "None", and Rotten Tomatoes falls back to a search.
    static var previewUnknown: TitleExtras {
        TitleExtras(awards: AwardsDigest(), links: [
            ExternalLink.rottenTomatoes(slug: nil, title: "Some Obscure Film"),
            ExternalLink.imdb(id: "tt0000001"),
        ].compactMap { $0 }, resolved: true)
    }
}
