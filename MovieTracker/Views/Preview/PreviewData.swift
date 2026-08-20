//
//  PreviewData.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

// MARK: - Sample movies

extension Movie {
    static var preview: Movie {
        var movie = Movie(id: 1, title: "The Odyssey")
        movie.releaseDate = DateComponents(calendar: .current, year: 2026, month: 7, day: 17).date
        movie.overview = "Odysseus, the legendary King of Ithaca, embarks on a long and perilous "
            + "journey home following the Trojan War. Throughout his voyage, he is forced to confront "
            + "the whims of gods, mythological monsters, and trials that stretch both his cunning and heart."
        movie.runtime = 173
        movie.rating = 8.0
        movie.certification = "PG-13"
        movie.genres = ["Adventure", "Action"]
        movie.poster = "preview-poster"
        movie.background = "preview-backdrop"
        movie.bonusCredits = Movie.Credits(during: false, after: true)
        movie.team = Person.previewTeam
        movie.watchByRegion = [
            Region.device: WatchAvailability(
                providers: [
                    WatchProvider(id: 8, name: "Netflix", logoPath: nil),
                    WatchProvider(id: 337, name: "Disney+", logoPath: nil),
                    WatchProvider(id: 350, name: "Apple TV+", logoPath: nil),
                    WatchProvider(id: 1899, name: "Max", logoPath: nil),
                ],
                justWatchLink: URL(string: "https://www.justwatch.com"))
        ]
        return movie
    }

    static var previewList: [Movie] {
        [
            Movie.preview,
            {
                var movie = Movie(id: 2, title: "Supergirl")
                movie.releaseDate = DateComponents(calendar: .current, year: 2026, month: 6, day: 26).date
                movie.certification = "PG-13"
                movie.poster = "preview-poster-alt"
                return movie
            }(),
            {
                var movie = Movie(id: 3, title: "Spider-Man: Brand New Day")
                movie.releaseDate = DateComponents(calendar: .current, year: 2026, month: 7, day: 31).date
                movie.certification = "PG-13"
                movie.poster = "preview-poster"
                return movie
            }()
        ]
    }

    /// Under ten minutes, so its cell carries the "(Short)" tag.
    static var previewShort: Movie {
        var movie = Movie(id: 7, title: "Peter's To-Do List")
        movie.releaseDate = DateComponents(calendar: .current, year: 2019, month: 9, day: 17).date
        movie.runtime = 4
        movie.poster = "preview-poster-alt"
        return movie
    }

    /// A movie that belongs to a franchise — drives the "Related" strip in the detail.
    static var previewSeries: Movie {
        var movie = Movie(id: 3, title: "Spider-Man: Brand New Day")
        movie.releaseDate = DateComponents(calendar: .current, year: 2026, month: 7, day: 31).date
        movie.overview = "Peter Parker's world is upended when a new threat forces him to rebuild "
            + "everything he thought he knew about being Spider-Man."
        movie.runtime = 128
        movie.rating = 7.6
        movie.certification = "PG-13"
        movie.genres = ["Action", "Adventure"]
        movie.poster = "preview-poster"
        movie.background = "preview-backdrop"
        movie.team = Person.previewTeam
        movie.collection = MovieCollection(id: 900, name: "Spider-Man Collection",
                                           poster: "preview-poster", background: "preview-backdrop")
        return movie
    }

    /// Sibling films of `previewSeries`, for the franchise strip.
    static var previewSeriesCollection: [Movie] {
        [(4, "Spider-Man: Homecoming", 2017), (5, "Spider-Man: Far From Home", 2019),
         (6, "Spider-Man: No Way Home", 2021)].map { id, title, year in
            var movie = Movie(id: id, title: title)
            movie.releaseDate = DateComponents(calendar: .current, year: year, month: 7, day: 5).date
            movie.poster = id % 2 == 0 ? "preview-poster" : "preview-poster-alt"
            return movie
        }
    }

    /// The standard movie under a distinct id, so a "watched" preview can mark it seen
    /// without also flipping the unwatched Standard preview (same shared container).
    static var previewWatched: Movie {
        var movie = Movie.preview
        movie.id = 7
        return movie
    }
}

// MARK: - Sample people

extension Person {
    static var preview: Person {
        var person = Person(id: 10, name: "Christopher Nolan")
        person.role = "Director"
        person.type = .Crew
        person.birthday = DateComponents(calendar: .current, year: 1970, month: 7, day: 30).date
        person.placeOfBirth = "London, England, UK"
        person.profilePicture = "preview-profile"
        person.bio = "Christopher Nolan is a British-American filmmaker known for his "
            + "distinctive nonlinear storytelling and large-format cinematography."
        person.credits = [
            {
                var movie = Movie(id: 1, title: "The Odyssey")
                movie.releaseDate = DateComponents(calendar: .current, year: 2026, month: 7, day: 17).date
                movie.creditJobs = ["Director"]
                movie.creditKind = .directing
                movie.poster = "preview-poster"
                movie.popularity = 120
                movie.voteCount = 1_400
                return movie
            }(),
            {
                var movie = Movie(id: 20, title: "Oppenheimer")
                movie.releaseDate = DateComponents(calendar: .current, year: 2023, month: 7, day: 21).date
                movie.creditJobs = ["Director"]
                movie.creditKind = .directing
                movie.poster = "preview-poster-alt"
                movie.popularity = 98
                movie.voteCount = 9_800
                return movie
            }(),
            {
                // Credited three ways on Tenet: all of them listed, most prominent first.
                var movie = Movie(id: 21, title: "Tenet")
                movie.releaseDate = DateComponents(calendar: .current, year: 2020, month: 9, day: 3).date
                movie.creditJobs = ["Director", "Writer", "Executive Producer"]
                movie.creditKind = .directing
                movie.poster = "preview-poster"
                movie.popularity = 76
                movie.voteCount = 7_600
                return movie
            }(),
            {
                var movie = Movie(id: 22, title: "Man of Steel")
                movie.releaseDate = DateComponents(calendar: .current, year: 2013, month: 6, day: 14).date
                movie.creditJobs = ["Story"]
                movie.creditKind = .writing
                movie.poster = "preview-poster-alt"
                movie.popularity = 54
                movie.voteCount = 15_000
                return movie
            }()
        ]
        person.tvCredits = [
            {
                var show = Show(id: 1001, name: "Nightfall")
                show.firstAirDate = DateComponents(calendar: .current, year: 2021, month: 9, day: 12).date
                show.creditJobs = ["Executive Producer", "Creator"]
                show.creditKind = .producing
                show.poster = "preview-poster"
                show.popularity = 64
                show.voteCount = 2_900
                show.episodeCount = 28
                show.seasons = [Season(id: 1, seasonNumber: 1, name: "Season 1", episodeCount: 10)]
                return show
            }(),
            {
                var show = Show(id: 1002, name: "The Lighthouse Files")
                show.firstAirDate = DateComponents(calendar: .current, year: 2018, month: 3, day: 4).date
                show.creditRole = "Self"
                show.creditKind = .appearance
                show.poster = "preview-poster-alt"
                show.popularity = 21
                show.voteCount = 480
                show.episodeCount = 1
                return show
            }()
        ]
        return person
    }

    static var previewActor: Person {
        var person = Person(id: 11, name: "Matt Damon")
        person.role = "Odysseus"
        person.type = .Cast
        person.profilePicture = "preview-profile"
        return person
    }

    static var previewTeam: [Person] {
        func member(_ id: Int, _ name: String, _ role: String, _ type: PersonType) -> Person {
            var person = Person(id: id, name: name)
            person.role = role
            person.type = type
            person.profilePicture = "preview-profile"
            return person
        }
        return [
            .preview,
            member(11, "Matt Damon", "Odysseus", .Cast),
            member(12, "Tom Holland", "Telemachus", .Cast),
            member(13, "Anne Hathaway", "Penelope", .Cast),
            member(14, "Zendaya", "Athena", .Cast),
            member(15, "Robert Pattinson", "Antinous", .Cast),
            member(16, "Charlize Theron", "Circe", .Cast),
            member(17, "Lupita Nyong'o", "Calypso", .Cast),
            member(18, "John Leguizamo", "Eurylochus", .Cast),
            member(19, "Benny Safdie", "Poseidon", .Cast),
            member(20, "Mia Threapleton", "Nausicaa", .Cast),
            member(21, "Cosmo Jarvis", "Polites", .Cast),
            member(22, "Corey Hawkins", "Perimedes", .Cast),
            member(30, "Hoyte van Hoytema", "Director of Photography", .Crew),
            member(31, "Jennifer Lame", "Editor", .Crew),
            member(32, "Ludwig Göransson", "Original Music Composer", .Crew),
        ]
    }
}

// MARK: - Sample SwiftData container

/// Everything is inserted, never fetched — a fresh in-memory store has no connection until
/// SwiftUI attaches it, so fetching here crashes with "No eligible connection available".
@MainActor
let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MarqueeSchema.schema, configurations: configuration)
    let context = container.mainContext

    let watchList = MediaList(name: "Watch List", symbol: "bookmark", sortOrder: 0, isWatchList: true)
    context.insert(watchList)
    context.insert(MediaList(name: "Favorites", symbol: "heart", sortOrder: 1, colorIndex: 2))

    for movie in Movie.previewList {
        let entry = ListEntry(movie: movie)
        entry.list = watchList
        context.insert(entry)
    }

    let watched = MediaItem(movie: Movie.previewList[1])
    watched.watchedAt = MediaItem.floatingDay(from: Date())
    watched.userRating = 4.0
    context.insert(watched)

    let viewed = MediaItem(movie: .preview)
    viewed.lastViewedAt = Date()
    context.insert(viewed)

    return container
}()

// MARK: - Detail-screen preview store

/// One shared in-memory store for the Movie/Show detail previews (a fresh `ModelContainer` per
/// preview is the slow part). Scenario state is keyed to distinct sample ids, so none bleed.
@MainActor
let detailPreviewContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MarqueeSchema.schema, configurations: configuration)
    let context = container.mainContext
    context.insert(MediaList(name: "Watch List", symbol: "bookmark", sortOrder: 0, isWatchList: true))
    context.insert(MediaList(name: "Favorites", symbol: "heart", sortOrder: 1, colorIndex: 2))

    // Movie "Watched": a rated, watched movie.
    let watched = MediaItem(movie: .previewWatched)
    watched.watchedAt = MediaItem.floatingDay(from: Date())
    watched.userRating = 4.0
    context.insert(watched)

    // Show "Season watched" (id 1010): all of S1. "Season partial" (id 1011): two of three.
    for episode in 1...3 {
        context.insert(WatchedEpisode(showTmdbID: 1010, seasonNumber: 1, episodeNumber: episode))
    }
    for episode in 1...2 {
        context.insert(WatchedEpisode(showTmdbID: 1011, seasonNumber: 1, episodeNumber: episode))
    }
    return container
}()
