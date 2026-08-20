//
//  ExternalLink.swift
//  MovieTracker
//

import Foundation

/// A title's page on an outside site, opened in an in-app Safari view.
struct ExternalLink: Identifiable, Hashable, Sendable {
    enum Site: String, Sendable {
        case rottenTomatoes = "Rotten Tomatoes"
        case imdb = "IMDb"

        var symbol: String {
            switch self {
            case .rottenTomatoes: return "percent"   // the Tomatometer is a percentage
            case .imdb: return "film"
            }
        }
    }

    var site: Site
    var url: URL
    var isExact: Bool = true

    var id: String { site.rawValue }
}

extension ExternalLink {
    static func imdb(id: String?) -> ExternalLink? {
        guard let id, !id.isEmpty,
              let url = URL(string: "https://www.imdb.com/title/\(id)/") else { return nil }
        return ExternalLink(site: .imdb, url: url)
    }

    // TMDB carries no Rotten Tomatoes id, and a slug guessed from the title often 404s, so search is the fallback.
    static func rottenTomatoes(slug: String?, title: String) -> ExternalLink? {
        if let slug, !slug.isEmpty,
           let url = URL(string: "https://www.rottentomatoes.com/\(slug)") {
            return ExternalLink(site: .rottenTomatoes, url: url)
        }
        var components = URLComponents(string: "https://www.rottentomatoes.com/search")
        components?.queryItems = [URLQueryItem(name: "search", value: title)]
        guard let url = components?.url else { return nil }
        return ExternalLink(site: .rottenTomatoes, url: url, isExact: false)
    }
}
