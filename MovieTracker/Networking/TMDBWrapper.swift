//
//  TMDBWrapper.swift
//  MovieTracker
//
//  Created by Elliot Barer on 6/11/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import Foundation

class TMDBWrapper {
    private static let baseURL = "https://api.themoviedb.org"
    private static let imageBaseURL = "https://image.tmdb.org/t/p"
    private static let apiVersion = "/3"
    private static let apiKey = "da99299f02cd39e2736c97d08b459731"
    private static let regionCode = NSLocale.current.region?.identifier ?? "US"
    private static let languageCode = NSLocale.current.language.languageCode?.identifier ?? "en"

    // Keywords identifying during/after credit extras.
    private static let bonusKeywords = ["during": 179431, "after": 179430]
}

// MARK: - Requests

private extension TMDBWrapper {
    /// The locale/key query items sent with every request.
    static var localeQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "with_original_language", value: languageCode),
            URLQueryItem(name: "language", value: "\(languageCode)-\(regionCode)"),
            URLQueryItem(name: "region", value: regionCode),
        ]
    }

    /// Performs a GET against the API, appending the shared query items (plus a
    /// certification country for movie endpoints), and returns the raw response.
    static func fetch(_ path: String, queryItems: [URLQueryItem] = [],
                      certified: Bool = false) async throws -> Data {
        var components = URLComponents(string: baseURL)!
        components.path = apiVersion + path
        components.queryItems = queryItems + localeQueryItems
            + (certified ? [URLQueryItem(name: "certification_country", value: regionCode)] : [])

        guard let url = components.url else {
            throw FetchError.noData("Couldn't build request URL.")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw FetchError.decode("Couldn't decode JSON data: \(error)")
        }
    }
}

// MARK: - Movies

extension TMDBWrapper {
    static func getMovie(id: Int) async throws -> Movie {
        let data = try await fetch(
            "/movie/\(id)",
            queryItems: [
                URLQueryItem(name: "with_release_type", value: "3|2"),
                URLQueryItem(name: "append_to_response", value: "videos,release_dates,credits,keywords"),
            ],
            certified: true
        )
        return translate(movie: try decode(MovieRaw.self, from: data))
    }

    static func getCollection(id: Int) async throws -> [Movie] {
        let data = try await fetch("/collection/\(id)", certified: true)
        let collection = try decode(CollectionRaw.self, from: data)
        // Oldest-to-newest so the franchise reads chronologically.
        return collection.parts.map(translate(movie:)).sorted {
            guard let a = $0.releaseDate else { return false }
            guard let b = $1.releaseDate else { return true }
            return a < b
        }
    }

    static func moviesNowPlaying(page: Int) async throws -> PagedResult<Movie> {
        try await moviePage("/movie/now_playing", page: page)
    }

    static func moviesPopular(page: Int) async throws -> PagedResult<Movie> {
        try await moviePage("/movie/popular", page: page)
    }

    static func moviesComingSoon(page: Int) async throws -> PagedResult<Movie> {
        try await moviePage("/movie/upcoming", page: page)
    }

    static func movieRecommendations(id: Int, page: Int = 1) async throws -> PagedResult<Movie> {
        try await moviePage("/movie/\(id)/recommendations", page: page)
    }

    static func searchForMovies(query: String, page: Int = 1) async throws -> PagedResult<Movie> {
        guard !query.isEmpty else { return .empty }
        return try await moviePage("/search/movie", page: page,
                                   queryItems: [URLQueryItem(name: "query", value: query)])
    }

    /// Shared fetch/decode for the paged movie list and search endpoints.
    private static func moviePage(_ path: String, page: Int,
                                  queryItems: [URLQueryItem] = []) async throws -> PagedResult<Movie> {
        guard page > 0 else {
            throw FetchError.decode("Invalid page number (index starts at 1).")
        }
        let data = try await fetch(path, queryItems: queryItems + [
            URLQueryItem(name: "page", value: String(page))
        ], certified: true)
        let root = try decode(RootRaw<MovieRaw>.self, from: data)
        return PagedResult(items: root.results.map(translate(movie:)),
                           totalResults: root.totalResults, totalPages: root.totalPages)
    }
}

// MARK: - People

extension TMDBWrapper {
    static func getPerson(id: Int) async throws -> Person {
        let data = try await fetch("/person/\(id)",
                                   queryItems: [URLQueryItem(name: "append_to_response", value: "movie_credits")])
        return translate(person: try decode(PersonRaw.self, from: data))
    }

    static func searchForPeople(query: String, page: Int = 1) async throws -> PagedResult<Person> {
        guard !query.isEmpty else { return .empty }
        let data = try await fetch("/search/person", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
        ])
        let root = try decode(RootRaw<PersonRaw>.self, from: data)
        return PagedResult(items: root.results.map(translate(person:)),
                           totalResults: root.totalResults, totalPages: root.totalPages)
    }
}

// MARK: - Images

/// A page of results returned by a TMDB list/search endpoint.
struct PagedResult<Element> {
    let items: [Element]
    let totalResults: Int
    let totalPages: Int

    static var empty: PagedResult { PagedResult(items: [], totalResults: 0, totalPages: 1) }
}

extension TMDBWrapper {
    /// A fully-qualified TMDB image URL for the given path and size.
    static func imageURL(path: String?, size: String) -> URL? {
        guard let path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size)/\(path)")
    }

    /// Raw image data (e.g. for average-color extraction).
    static func imageData(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}

// MARK: - Decoding & translation

private extension TMDBWrapper {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            return DateFormatter.iso8601DAw.date(from: dateString)
                ?? DateFormatter.iso8601DTw.date(from: dateString)
                ?? Date()
        }
        return decoder
    }

    static func translate(movie mv: MovieRaw) -> Movie {
        var movie = Movie(id: mv.id, title: mv.title)

        if let overview = mv.overview, !overview.isEmpty {
            movie.overview = overview
        }

        movie.poster = mv.poster
        movie.background = mv.background
        movie.runtime = mv.runtime
        movie.rating = mv.rating
        movie.popularity = mv.popularity
        movie.imdbID = mv.imdbID

        let releaseInfo = mv.certification()
        if let releaseDate = releaseInfo.releaseDate {
            movie.releaseDate = releaseDate
        } else if let releaseDateString = mv.releaseDateString {
            movie.releaseDate = releaseDateString.toDate(format: .iso8601DAw)
        }

        movie.certification = releaseInfo.certification
        movie.genres = mv.genres()
        movie.bonusCredits = Movie.Credits(mv.bonusCredits())
        movie.team = mv.team()
        movie.trailers = mv.trailers()
        movie.collection = mv.collection()

        return movie
    }

    static func translate(person p: PersonRaw) -> Person {
        var person = Person(id: p.id, name: p.name)
        person.popularity = p.popularity
        person.profilePicture = p.profilePicture
        person.birthday = p.birthday
        person.placeOfBirth = p.placeOfBirth
        person.bio = p.biography
        person.imdbID = p.imdbID
        person.credits = p.credits()
        return person
    }
}

// MARK: - JSON structures

private extension TMDBWrapper {
    // Pass a Codable generic to specify the type of `results`.
    struct RootRaw<T: Codable>: Codable {
        var results: [T]
        var totalResults: Int
        var totalPages: Int

        private enum CodingKeys: String, CodingKey {
            case results
            case totalResults = "total_results"
            case totalPages = "total_pages"
        }
    }

    struct MovieRaw: Codable {
        var id: Int
        var title: String
        var releaseDateString: String?
        var overview: String?
        var poster: String?
        var background: String?
        var runtime: Int?
        var rating: Double?
        var popularity: Double?
        var releaseDates: ReleaseDatesRaw?
        var genresRaw: [GenreRaw]?
        var trailersRaw: TrailersRaw?
        var imdbID: String?
        var keywords: Keywords?
        var teamRaw: TeamRaw?
        var collectionRaw: CollectionStubRaw?

        func certification() -> (certification: String?, releaseDate: Date?) {
            let regionCode = NSLocale.current.region?.identifier ?? "US"

            guard let releases = self.releaseDates?.releases else {
                return (nil, nil)
            }

            let filteredReleases = releases.filter { $0.country == regionCode }
            guard filteredReleases.count > 0 else {
                return (nil, nil)
            }

            var release = filteredReleases[0].dates.filter { $0.type == .Theatrical }
            if release.count < 1 {
                release = filteredReleases[0].dates.filter { $0.type == .TheatricalLimited }
            }

            guard release.count > 0 else {
                return (nil, nil)
            }

            if !release[0].certification.isEmpty {
                return (release[0].certification, release[0].releaseDate)
            } else {
                return ("Unavailable", release[0].releaseDate)
            }
        }

        func genres() -> [String]? {
            guard let genres = genresRaw else { return nil }
            return genres.count > 2 ? genres[0..<2].map { $0.name } : genres.map { $0.name }
        }

        func bonusCredits() -> (during: Bool, after: Bool) {
            var duringCredits = false
            var afterCredits = false

            guard let keywords = keywords?.keywords else {
                return (duringCredits, afterCredits)
            }

            for keyword in keywords {
                if keyword.id == TMDBWrapper.bonusKeywords["during"] { duringCredits = true }
                if keyword.id == TMDBWrapper.bonusKeywords["after"] { afterCredits = true }
            }

            return (duringCredits, afterCredits)
        }

        func team() -> [Person] {
            guard let teamRaw = self.teamRaw else { return [] }

            var team = [Person]()
            for person in teamRaw.crew.filter({ $0.role == "Director" }) {
                team.append(Person(id: person.id, name: person.name, role: person.role,
                                   pic: person.profilePicture, type: .Crew))
            }
            for person in teamRaw.cast {
                team.append(Person(id: person.id, name: person.name, role: person.role,
                                   pic: person.profilePicture, type: .Cast))
            }
            return team
        }

        func trailers() -> [MovieTrailer]? {
            guard let trailersRaw = trailersRaw else { return nil }
            return trailersRaw.trailers.map {
                MovieTrailer(id: $0.id, title: $0.name, key: $0.key, type: $0.type,
                             site: $0.site, official: $0.official, publishedAt: $0.publishedAt)
            }
        }

        func collection() -> MovieCollection? {
            guard let stub = collectionRaw else { return nil }
            return MovieCollection(id: stub.id, name: stub.name,
                                   poster: stub.poster, background: stub.background)
        }

        enum CodingKeys: String, CodingKey {
            case id, title, overview, runtime, popularity, keywords
            case imdbID = "imdb_id"
            case releaseDateString = "release_date"
            case poster = "poster_path"
            case background = "backdrop_path"
            case rating = "vote_average"
            case releaseDates = "release_dates"
            case genresRaw = "genres"
            case trailersRaw = "videos"
            case teamRaw = "credits"
            case collectionRaw = "belongs_to_collection"
        }

        struct CollectionStubRaw: Codable {
            var id: Int
            var name: String
            var poster: String?
            var background: String?

            enum CodingKeys: String, CodingKey {
                case id, name
                case poster = "poster_path"
                case background = "backdrop_path"
            }
        }

        struct GenreRaw: Codable {
            var name: String
        }

        struct Keywords: Codable {
            var keywords: [KeywordRaw]
        }

        struct KeywordRaw: Codable {
            var id: Int
            var name: String
        }

        struct ReleaseDatesRaw: Codable {
            var releases: [ReleaseDateWrapperRaw]
            private enum CodingKeys: String, CodingKey {
                case releases = "results"
            }

            struct ReleaseDateWrapperRaw: Codable {
                var country: String
                var dates: [ReleaseDateRaw]

                enum CodingKeys: String, CodingKey {
                    case country = "iso_3166_1"
                    case dates = "release_dates"
                }

                struct ReleaseDateRaw: Codable {
                    var type: ReleaseType
                    var releaseDate: Date
                    var certification: String

                    enum CodingKeys: String, CodingKey {
                        case type, certification
                        case releaseDate = "release_date"
                    }

                    enum ReleaseType: Int, Codable {
                        case Premiere = 1
                        case TheatricalLimited = 2
                        case Theatrical = 3
                        case Digital = 4
                        case Physical = 5
                        case TV = 6
                    }
                }
            }
        }

        struct TeamRaw: Codable {
            var cast: [CastMemberRaw]
            var crew: [CrewMemberRaw]

            struct CastMemberRaw: Codable {
                var id: Int
                var order: Int
                var name: String
                var role: String
                var profilePicture: String?

                enum CodingKeys: String, CodingKey {
                    case name, id, order
                    case role = "character"
                    case profilePicture = "profile_path"
                }
            }

            struct CrewMemberRaw: Codable {
                var id: Int
                var name: String
                var role: String
                var profilePicture: String?

                enum CodingKeys: String, CodingKey {
                    case name, id
                    case role = "job"
                    case profilePicture = "profile_path"
                }
            }
        }

        struct TrailersRaw: Codable {
            var trailers: [Trailer]

            enum CodingKeys: String, CodingKey {
                case trailers = "results"
            }

            struct Trailer: Codable {
                var id: String
                var name: String
                var key: String
                var type: String
                var site: String
                var official: Bool
                var publishedAt: String

                enum CodingKeys: String, CodingKey {
                    case id, name, key, type, site, official
                    case publishedAt = "published_at"
                }
            }
        }
    }

    struct CollectionRaw: Codable {
        var id: Int
        var name: String
        var overview: String?
        var parts: [MovieRaw]
    }

    struct PersonRaw: Codable {
        var id: Int
        var name: String
        var popularity: Float
        var profilePicture: String?
        var birthday: Date?
        var placeOfBirth: String?
        var biography: String?
        var imdbID: String?
        var creditsRaw: CreditsRaw?

        func credits() -> [Movie] {
            guard let creditsRaw = self.creditsRaw else { return [] }

            var credits = [Movie]()
            for collection in [creditsRaw.cast, creditsRaw.crew] {
                for movie in collection {
                    var credit = Movie(id: movie.id, title: movie.title)
                    credit.poster = movie.poster
                    credit.creditRole = movie.role
                    credit.popularity = movie.popularity
                    if let releaseDateString = movie.releaseDateString, !releaseDateString.isEmpty {
                        credit.releaseDate = releaseDateString.toDate(format: .iso8601DAw)
                    }
                    credits.append(credit)
                }
            }

            // De-duplicate, then sort newest-first.
            return Set(credits).sorted {
                guard let releaseA = $0.releaseDate else { return false }
                guard let releaseB = $1.releaseDate else { return true }
                return releaseA.compare(releaseB) == .orderedDescending
            }
        }

        enum CodingKeys: String, CodingKey {
            case id, name, popularity
            case birthday, biography
            case imdbID = "imdb_id"
            case creditsRaw = "movie_credits"
            case profilePicture = "profile_path"
            case placeOfBirth = "place_of_birth"
        }

        struct CreditsRaw: Codable {
            var cast: [MovieCreditRaw]
            var crew: [MovieCreditRaw]

            struct MovieCreditRaw: Codable {
                var id: Int
                var title: String
                var releaseDateString: String?
                var overview: String?
                var poster: String?
                var character: String?
                var job: String?
                var popularity: Double?

                /// Cast credits carry a `character`; crew credits carry a `job`.
                var role: String? { character ?? job }

                enum CodingKeys: String, CodingKey {
                    case id, title, overview, character, job, popularity
                    case releaseDateString = "release_date"
                    case poster = "poster_path"
                }
            }
        }
    }
}

enum FetchError: Error {
    case noData(String)
    case decode(String)
    case image(String)
}

// MARK: - Model image URLs (for SwiftUI AsyncImage)

extension Movie {
    func posterURL(_ size: Movie.PosterSize = .w342) -> URL? {
        TMDBWrapper.imageURL(path: poster, size: size.rawValue)
    }

    func backgroundURL(_ size: Movie.BackgroundSize = .w1280) -> URL? {
        TMDBWrapper.imageURL(path: background, size: size.rawValue)
    }
}

extension Person {
    func profileURL(_ size: Person.ProfileSize = .w276) -> URL? {
        TMDBWrapper.imageURL(path: profilePicture, size: size.rawValue)
    }
}
