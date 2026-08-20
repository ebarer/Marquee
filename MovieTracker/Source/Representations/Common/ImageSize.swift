//
//  ImageSize.swift
//  MovieTracker
//

import Foundation

// TMDB image-size constants, shared by every media type (movies, shows, seasons, episodes).

enum PosterSize: String {
    case w92  = "w92"
    case w154 = "w154"
    case w185 = "w185"
    case w342 = "w342"
    case w500 = "w500"
    case w780 = "w780"
    case orig = "original"
}

enum BackgroundSize: String {
    case w300  = "w300"
    case w780  = "w780"
    case w1280 = "w1280"
    case orig  = "original"
}
