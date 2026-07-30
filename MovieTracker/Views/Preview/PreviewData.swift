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
        person.bio = "Christopher Nolan is a British-American filmmaker known for his "
            + "distinctive nonlinear storytelling and large-format cinematography."
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

/// An in-memory container seeded with the built-in lists plus one custom list.
@MainActor
let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WatchListEntry.self, MovieList.self,
                                        configurations: configuration)
    let context = container.mainContext
    WatchListStore.ensureDefaultLists(in: context)
    context.insert(MovieList(name: "Favorites", symbol: "heart", kind: .custom, sortOrder: 2))
    return container
}()
