//
//  MediaType.swift
//  MovieTracker
//

import Foundation

/// The kind of title a MediaItem/ListEntry represents. Everything is `.movie`
/// today; `.tv` exists so the schema doesn't preclude shows later.
enum MediaType: Int, Codable, Sendable {
    case movie = 0
    case tv = 1
}
