//
//  TitleExtras.swift
//  MovieTracker
//

import Foundation

/// What Wikidata adds beyond TMDB's payload: awards, and the outside pages the nav bar links to.
struct TitleExtras: Equatable, Sendable {
    var awards = AwardsDigest()
    var links: [ExternalLink] = []
    // Separates "still fetching" from "fetched, and this title won nothing"; only the second may report "None".
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

    static var previewUnknown: TitleExtras {
        TitleExtras(awards: AwardsDigest(), links: [
            ExternalLink.rottenTomatoes(slug: nil, title: "Some Obscure Film"),
            ExternalLink.imdb(id: "tt0000001"),
        ].compactMap { $0 }, resolved: true)
    }
}
