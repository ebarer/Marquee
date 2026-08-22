//
//  WatchStats.swift
//  MovieTracker
//

import Foundation

/// Everything the Year in Review screen shows, derived from stored watch history.
struct WatchStats: Sendable, Equatable {
    struct MonthBucket: Sendable, Equatable, Identifiable {
        let month: Int
        var movies: Int
        var episodes: Int

        var id: Int { month }
        var total: Int { movies + episodes }
    }

    struct TopShow: Sendable, Equatable, Identifiable {
        let showTmdbID: Int
        let name: String
        var episodes: Int

        var id: Int { showTmdbID }
    }

    var scope: Scope = .allTime
    var availableYears: [Int] = []

    var moviesWatched = 0
    var movieMinutes = 0
    var moviesMissingRuntime = 0

    var episodesWatched = 0
    var episodeMinutes = 0
    var episodesMissingRuntime = 0
    var seasonsCompleted = 0
    var showsWatched = 0

    var months: [MonthBucket] = []
    var topShows: [TopShow] = []

    // Keyed by the star value doubled, so 7 means 3.5 stars.
    var ratings: [Int: Int] = [:]
    var ratedCount = 0
    var averageRating: Double?

    var longestStreakDays = 0
    var busiestMonth: MonthBucket?

    enum Scope: Sendable, Equatable, Hashable {
        case allTime
        case year(Int)

        var title: String {
            switch self {
            case .allTime: return "All Time"
            case .year(let year): return String(year)
            }
        }
    }

    var isEmpty: Bool {
        moviesWatched == 0 && episodesWatched == 0 && seasonsCompleted == 0
    }

    var titlesFinished: Int { moviesWatched + seasonsCompleted }

    var totalMinutes: Int { movieMinutes + episodeMinutes }
}
