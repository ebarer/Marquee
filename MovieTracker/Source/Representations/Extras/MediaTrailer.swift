//
//  MediaTrailer.swift
//  MovieTracker
//

import Foundation

/// A trailer/teaser/clip for a movie or show, ranked by `primaryScore` to pick the best one.
struct MediaTrailer: Identifiable, Codable, Sendable {
    var id: String
    var title: String
    var key: String
    var type: TrailerType
    var site: String
    var official: Bool
    var publishedAt: String

    enum TrailerType: String, Codable, Sendable {
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

    // TMDB sends a full timestamp, but cached and test payloads carry a bare day.
    var publishedDate: Date? {
        DateFormatter.iso8601DTw.date(from: publishedAt)
            ?? DateFormatter.iso8601DAw.date(from: publishedAt)
    }

    var subtitle: String {
        guard let published = publishedDate else { return type.rawValue }
        return "\(type.rawValue) · \(published.toString())"
    }

    /// Playable trailers and teasers, best first.
    static func ranked(_ trailers: [MediaTrailer]?) -> [MediaTrailer] {
        (trailers ?? [])
            .filter { $0.site == "YouTube" && $0.isTrailer }
            .sorted { lhs, rhs in
                if lhs.primaryScore != rhs.primaryScore {
                    return lhs.primaryScore > rhs.primaryScore
                }
                return lhs.publishedAt > rhs.publishedAt
            }
    }
}
