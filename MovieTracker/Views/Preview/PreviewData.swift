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
                var m = Movie(id: 2, title: "Supergirl")
                m.releaseDate = DateComponents(calendar: .current, year: 2026, month: 6, day: 26).date
                m.certification = "PG-13"
                return m
            }(),
            {
                var m = Movie(id: 3, title: "Spider-Man: Brand New Day")
                m.releaseDate = DateComponents(calendar: .current, year: 2026, month: 7, day: 31).date
                m.certification = "PG-13"
                return m
            }()
        ]
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
        person.bio = "Christopher Nolan is a British-American filmmaker known for his "
            + "distinctive nonlinear storytelling and large-format cinematography."
        person.credits = [
            {
                var m = Movie(id: 1, title: "The Odyssey")
                m.releaseDate = DateComponents(calendar: .current, year: 2026, month: 7, day: 17).date
                m.creditRole = "Director"
                m.poster = "/placeholder.jpg"
                m.popularity = 120
                return m
            }(),
            {
                var m = Movie(id: 20, title: "Oppenheimer")
                m.releaseDate = DateComponents(calendar: .current, year: 2023, month: 7, day: 21).date
                m.creditRole = "Director"
                m.poster = "/placeholder.jpg"
                m.popularity = 98
                return m
            }(),
            {
                var m = Movie(id: 21, title: "Tenet")
                m.releaseDate = DateComponents(calendar: .current, year: 2020, month: 9, day: 3).date
                m.creditRole = "Writer"
                m.poster = "/placeholder.jpg"
                m.popularity = 76
                return m
            }()
        ]
        return person
    }

    static var previewActor: Person {
        var person = Person(id: 11, name: "Matt Damon")
        person.role = "Odysseus"
        person.type = .Cast
        return person
    }

    static var previewTeam: [Person] {
        func member(_ id: Int, _ name: String, _ role: String, _ type: PersonType) -> Person {
            var person = Person(id: id, name: name)
            person.role = role
            person.type = type
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

/// Everything is inserted directly (never fetched) — a freshly created in-memory
/// store has no connection until SwiftUI attaches it, so fetching here would crash
/// with "No eligible connection available". `@Query` picks the objects up once the
/// container is attached.
@MainActor
let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MediaItem.self, MediaList.self, ListEntry.self,
                                        WatchedEpisode.self, WatchedSeason.self, TrackedSeason.self,
                                        configurations: configuration)
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
