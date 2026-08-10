//
//  WatchProvider.swift
//  MovieTracker
//

import Foundation

struct WatchAvailability: Codable, Hashable {
    var providers: [WatchProvider]
    var justWatchLink: URL?
}

struct WatchProvider: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var logoPath: String?

    func logoURL(size: String = "w92") -> URL? {
        TMDBWrapper.imageURL(path: logoPath, size: size)
    }
}
