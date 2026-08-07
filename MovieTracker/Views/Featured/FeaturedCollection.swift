//
//  FeaturedCollection.swift
//  MovieTracker
//

import Foundation

enum FeaturedCollection: Int, CaseIterable, Identifiable {
    case popular
    case nowPlaying
    case comingSoon

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .popular: return "Popular"
        case .nowPlaying: return "Now Playing"
        case .comingSoon: return "Coming Soon"
        }
    }

    var symbol: String {
        switch self {
        case .popular: return "star.fill"
        case .nowPlaying: return "popcorn.fill"
        case .comingSoon: return "calendar"
        }
    }
}
