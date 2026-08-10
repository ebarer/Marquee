//
//  MovieCollection.swift
//  MovieTracker
//

import Foundation

/// A movie franchise/collection (e.g. a trilogy) that a `Movie` may belong to.
struct MovieCollection: Codable {
    var id: Int
    var name: String
    var poster: String?
    var background: String?
}
