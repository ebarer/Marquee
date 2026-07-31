//
//  FeaturedCollection.swift
//  MovieTracker
//
//  The two collections shown on the Featured screen.
//

import Foundation

enum FeaturedCollection: Int, CaseIterable, Identifiable {
    case nowPlaying
    case comingSoon

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: return "Now Playing"
        case .comingSoon: return "Coming Soon"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: return "popcorn.fill"
        case .comingSoon: return "calendar"
        }
    }
}
