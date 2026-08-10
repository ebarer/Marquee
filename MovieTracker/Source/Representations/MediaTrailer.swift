//
//  MediaTrailer.swift
//  MovieTracker
//

import Foundation

/// A trailer/teaser/clip for a movie or show, ranked by `primaryScore` to pick the best one.
struct MediaTrailer: Identifiable, Codable {
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
