//
//  PreviewData.swift
//  MovieTracker
//
//  Sample data and an in-memory SwiftData container for SwiftUI previews.
//  Kept lightweight (no network) so previews render instantly.
//

import SwiftUI
import SwiftData

// MARK: - Sample movies

extension Movie {
    /// A fully-populated sample movie for previews.
    static var preview: Movie {
        let movie = Movie(id: 1, title: "The Odyssey")
        movie.releaseDate = DateComponents(calendar: .current, year: 2026, month: 7, day: 17).date
        movie.overview = "Odysseus, the legendary King of Ithaca, embarks on a long and perilous "
            + "journey home following the Trojan War. Throughout his voyage, he is forced to confront "
            + "the whims of gods, mythological monsters, and trials that stretch both his cunning and heart."
        movie.runtime = 173
        movie.rating = 8.0
        movie.certification = "PG-13"
        movie.genres = ["Adventure", "Action"]
        movie.bonusCredits = Movie.Credits(during: false, after: true)
        movie.team = [.preview, .previewActor]
        return movie
    }

    /// A short list of sample movies for grids and lists.
    static var previewList: [Movie] {
        [
            Movie.preview,
            {
                let m = Movie(id: 2, title: "Supergirl")
                m.releaseDate = DateComponents(calendar: .current, year: 2026, month: 6, day: 26).date
                m.certification = "PG-13"
                return m
            }(),
            {
                let m = Movie(id: 3, title: "Spider-Man: Brand New Day")
                m.releaseDate = DateComponents(calendar: .current, year: 2026, month: 7, day: 31).date
                m.certification = "PG-13"
                return m
            }()
        ]
    }
}

// MARK: - Sample people

extension Person {
    /// A sample crew member (director).
    static var preview: Person {
        let person = Person(id: 10, name: "Christopher Nolan")
        person.role = "Director"
        person.type = .Crew
        person.birthday = DateComponents(calendar: .current, year: 1970, month: 7, day: 30).date
        person.placeOfBirth = "London, England, UK"
        person.bio = "Christopher Nolan is a British-American filmmaker known for his "
            + "distinctive nonlinear storytelling and large-format cinematography."
        person.credits = [
            {
                let m = Movie(id: 1, title: "The Odyssey")
                m.releaseDate = DateComponents(calendar: .current, year: 2026, month: 7, day: 17).date
                m.creditRole = "Director"
                m.poster = "/placeholder.jpg"
                m.popularity = 120
                return m
            }(),
            {
                let m = Movie(id: 20, title: "Oppenheimer")
                m.releaseDate = DateComponents(calendar: .current, year: 2023, month: 7, day: 21).date
                m.creditRole = "Director"
                m.poster = "/placeholder.jpg"
                m.popularity = 98
                return m
            }(),
            {
                let m = Movie(id: 21, title: "Tenet")
                m.releaseDate = DateComponents(calendar: .current, year: 2020, month: 9, day: 3).date
                m.creditRole = "Writer"
                m.poster = "/placeholder.jpg"
                m.popularity = 76
                return m
            }()
        ]
        return person
    }

    /// A sample cast member (actor).
    static var previewActor: Person {
        let person = Person(id: 11, name: "Matt Damon")
        person.role = "Odysseus"
        person.type = .Cast
        return person
    }
}

// MARK: - Sample SwiftData container

/// An in-memory container seeded with the Watch List, one custom list with a few
/// movies, and a watched + a viewed title for the derived views.
///
/// Everything is inserted directly (never fetched) — a freshly created in-memory
/// store has no connection until SwiftUI attaches it, so fetching here would crash
/// with "No eligible connection available". `@Query` picks the objects up once the
/// container is attached.
@MainActor
let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MediaItem.self, MediaList.self, ListEntry.self,
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
