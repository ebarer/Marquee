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
        // Relative so the "next episode" cell keeps reading as upcoming in previews.
        show.nextAirDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        show.overview = "In a coastal city where the sun never fully rises, detective Mara Voss "
            + "untangles disappearances that seem to bend the rules of time itself — while the "
            + "people closest to her keep vanishing from the record."
        show.rating = 8.4
        show.certification = "TV-MA"
        show.genres = ["Drama", "Mystery"]
        show.networks = ["Apple TV+"]
        show.poster = "preview-poster"
        show.background = "preview-backdrop"
        show.creators = [{
            var creator = Person(id: 500, name: "Dana Whitfield")
            creator.role = "Creator"
            creator.type = .Crew
            return creator
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

    /// What a list row or search result carries: no seasons, status, network or overview, so the
    /// detail screen opens on this and faults the rest in.
    static var previewStub: Show {
        var stub = Show(id: Show.preview.id, name: Show.preview.name)
        stub.poster = Show.preview.poster
        stub.firstAirDate = Show.preview.firstAirDate
        return stub
    }

    /// Nightfall under distinct ids so the season-watched and season-partial previews can carry
    /// different watched progress in the one shared `detailPreviewContainer` without colliding.
    static var previewWatched: Show {
        var show = Show.preview
        show.id = 1010
        return show
    }

    static var previewPartial: Show {
        var show = Show.preview
        show.id = 1011
        return show
    }

    static var previewList: [Show] {
        [
            .preview,
            {
                var show = Show(id: 1002, name: "The Lighthouse Files")
                show.firstAirDate = DateComponents(calendar: .current, year: 2018, month: 3, day: 4).date
                show.lastAirDate = DateComponents(calendar: .current, year: 2022, month: 5, day: 20).date
                show.status = "Ended"
                show.certification = "TV-14"
                show.poster = "preview-poster-alt"
                show.background = "preview-backdrop"
                show.seasons = [Season(id: 1, seasonNumber: 1, name: "Season 1", episodeCount: 8)]
                return show
            }()
        ]
    }
}

extension Season {
    static var previewSeasons: [Season] {
        [
            {
                var season = Season(id: 11, seasonNumber: 1, name: "Season 1", episodeCount: 3)
                season.airDate = DateComponents(calendar: .current, year: 2021, month: 9, day: 12).date
                season.poster = "preview-poster"
                season.episodes = Episode.previewEpisodes
                return season
            }(),
            {
                var season = Season(id: 12, seasonNumber: 2, name: "Season 2", episodeCount: 10)
                season.airDate = DateComponents(calendar: .current, year: 2022, month: 10, day: 2).date
                season.poster = "preview-poster-alt"
                return season
            }(),
            {
                var season = Season(id: 13, seasonNumber: 3, name: "Season 3", episodeCount: 8)
                season.airDate = DateComponents(calendar: .current, year: 2024, month: 1, day: 14).date
                season.poster = "preview-poster"
                return season
            }()
        ]
    }
}

extension Episode {
    static var previewEpisodes: [Episode] {
        func episode(_ number: Int, _ title: String, _ overview: String,
                     _ runtime: Int, _ rating: Double) -> Episode {
            var episode = Episode(id: 100 + number, seasonNumber: 1,
                                  episodeNumber: number, name: title)
            episode.overview = overview
            episode.still = "preview-still"
            episode.runtime = runtime
            episode.rating = rating
            episode.airDate = DateComponents(calendar: .current, year: 2021, month: 9,
                                             day: 12 + (number - 1) * 7).date
            return episode
        }
        return [
            episode(1, "First Light", "The city wakes to a disappearance that shouldn't be possible.", 58, 8.1),
            episode(2, "Long Shadows", "Mara follows a lead into the flooded lower districts.", 52, 8.3),
            episode(3, "The Vigil", "An old friend returns with a warning Mara can't ignore.", 55, 8.7),
        ]
    }
}
