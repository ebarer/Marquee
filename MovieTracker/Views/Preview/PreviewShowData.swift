//
//  PreviewShowData.swift
//  MovieTracker
//

import Foundation

// MARK: - Sample shows

extension Show {
    static var preview: Show {
        var show = Show(id: 1001, name: "Nightfall")
        show.firstAirDate = DateComponents(calendar: .current, year: 2021, month: 9, day: 12).date
        show.status = "Returning Series"
        show.overview = "In a coastal city where the sun never fully rises, detective Mara Voss "
            + "untangles disappearances that seem to bend the rules of time itself — while the "
            + "people closest to her keep vanishing from the record."
        show.rating = 8.4
        show.certification = "TV-MA"
        show.genres = ["Drama", "Mystery"]
        show.networks = ["Apple TV+"]
        show.creators = [{
            var p = Person(id: 500, name: "Dana Whitfield")
            p.role = "Creator"
            p.type = .Crew
            return p
        }()]
        show.recurringCast = Person.previewTeam.filter { $0.type == .Cast }
        show.seasons = Season.previewSeasons
        show.watchByRegion = [
            Region.device: WatchAvailability(
                providers: [WatchProvider(id: 350, name: "Apple TV+", logoPath: nil)],
                justWatchLink: URL(string: "https://www.justwatch.com"))
        ]
        return show
    }

    static var previewList: [Show] {
        [
            .preview,
            {
                var s = Show(id: 1002, name: "The Lighthouse Files")
                s.firstAirDate = DateComponents(calendar: .current, year: 2018, month: 3, day: 4).date
                s.lastAirDate = DateComponents(calendar: .current, year: 2022, month: 5, day: 20).date
                s.status = "Ended"
                s.certification = "TV-14"
                s.seasons = [Season(id: 1, seasonNumber: 1, name: "Season 1", episodeCount: 8)]
                return s
            }()
        ]
    }
}

extension Season {
    static var previewSeasons: [Season] {
        [
            {
                var s = Season(id: 11, seasonNumber: 1, name: "Season 1", episodeCount: 3)
                s.airDate = DateComponents(calendar: .current, year: 2021, month: 9, day: 12).date
                s.episodes = Episode.previewEpisodes
                return s
            }(),
            {
                var s = Season(id: 12, seasonNumber: 2, name: "Season 2", episodeCount: 10)
                s.airDate = DateComponents(calendar: .current, year: 2022, month: 10, day: 2).date
                return s
            }(),
            {
                var s = Season(id: 13, seasonNumber: 3, name: "Season 3", episodeCount: 8)
                s.airDate = DateComponents(calendar: .current, year: 2024, month: 1, day: 14).date
                return s
            }()
        ]
    }
}

extension Episode {
    static var previewEpisodes: [Episode] {
        func ep(_ n: Int, _ title: String, _ overview: String, _ runtime: Int, _ rating: Double) -> Episode {
            var e = Episode(id: 100 + n, seasonNumber: 1, episodeNumber: n, name: title)
            e.overview = overview
            e.runtime = runtime
            e.rating = rating
            e.airDate = DateComponents(calendar: .current, year: 2021, month: 9, day: 12 + (n - 1) * 7).date
            return e
        }
        return [
            ep(1, "First Light", "The city wakes to a disappearance that shouldn't be possible.", 58, 8.1),
            ep(2, "Long Shadows", "Mara follows a lead into the flooded lower districts.", 52, 8.3),
            ep(3, "The Vigil", "An old friend returns with a warning Mara can't ignore.", 55, 8.7),
        ]
    }
}
