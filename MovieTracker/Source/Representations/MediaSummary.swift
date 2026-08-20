//
//  MediaSummary.swift
//  MovieTracker
//

import Foundation

/// A read-only view over a movie or show, for shared row and card rendering.
protocol MediaSummary: Identifiable, Hashable {
    var id: Int { get }
    var title: String { get }
    var posterPath: String? { get }
    var year: Int? { get }
    var mediaType: MediaType { get }
}

extension Movie: MediaSummary {
    var posterPath: String? { poster }
    var year: Int? { releaseDate?.year }
    var mediaType: MediaType { .movie }
}

extension Show: MediaSummary {
    var title: String { name }
    var posterPath: String? { poster }
    var year: Int? { firstAirDate?.year }
    var mediaType: MediaType { .tv }
}
