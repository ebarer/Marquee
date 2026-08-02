//
//  TMDBWrapper.swift
//  MovieTracker
//
//  Created by Elliot Barer on 6/11/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import UIKit

class TMDBWrapper {
    private static let baseURL = "https://api.themoviedb.org"
    private static let imageBaseURL = "https://image.tmdb.org/t/p"
    private static let apiVersion = "/3"
    private static let apiKey = "da99299f02cd39e2736c97d08b459731"
    private static let regionCode = NSLocale.current.region?.identifier ?? "US"
    private static let languageCode = NSLocale.current.language.languageCode?.identifier ?? "en"
    
    // Keywords to identify during/after credit extras
    private static let bonusKeywords = ["during" : 179431, "after" : 179430]
}

// MARK: - API Accessors

extension TMDBWrapper {
    static func getMovie(id: Int, completionHandler: @escaping (Movie?, Error?) -> Void) {
        let appendString = "videos,release_dates,credits,keywords"
        var searchURLComponents = URLComponents(string: self.baseURL)!
        searchURLComponents.path = "\(self.apiVersion)/movie/\(id)"
        searchURLComponents.queryItems = [
            URLQueryItem(name: "with_release_type", value: "3|2"),
            URLQueryItem(name: "append_to_response", value: appendString),
        ]
        
        self.fetchMovieData(url: searchURLComponents) { (data, error) in
            guard error == nil, let data = data else {
                completionHandler(nil, error)
                return
            }
            
            do {
                let movieRaw = try decoder.decode(MovieRaw.self, from: data)
                let movie = self.translate(movie: movieRaw)
                completionHandler(movie, nil)
            } catch {
                completionHandler(nil, FetchError.decode("Couldn't decode JSON data: \(error)"))
            }
        }
    }
    
    static func getCollection(id: Int, completionHandler: @escaping ([Movie]?, Error?) -> Void) {
        var searchURLComponents = URLComponents(string: self.baseURL)!
        searchURLComponents.path = "\(self.apiVersion)/collection/\(id)"

        self.fetchMovieData(url: searchURLComponents) { (data, error) in
            guard error == nil, let data = data else {
                completionHandler(nil, error)
                return
            }

            do {
                let collection = try decoder.decode(CollectionRaw.self, from: data)
                // Sort returned collection chronologically so the franchise reads oldest-to-newest
                let movies = collection.parts
                    .map { self.translate(movie: $0) }
                    .sorted {
                        guard let a = $0.releaseDate else { return false }
                        guard let b = $1.releaseDate else { return true }
                        return a < b
                    }
                completionHandler(movies, nil)
            } catch {
                completionHandler(nil, FetchError.decode("Couldn't decode JSON data: \(error)"))
            }
        }
    }

    static func getMoviesNowPlaying(page: Int, completionHandler: @escaping ([Movie]?, Error?, (results: Int, pages: Int)?) -> Void) {
        guard page > 0 else {
            completionHandler(nil, FetchError.decode("Invalid page number (index starts at 1)."), nil)
            return
        }
        
        var searchURLComponents = URLComponents(string: self.baseURL)!
        searchURLComponents.path = "\(self.apiVersion)/movie/now_playing"
        searchURLComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]

        self.fetchMovieData(url: searchURLComponents) { (data, error) in
            guard error == nil, let data = data else {
                completionHandler(nil, error, nil)
                return
            }
            
            do {
                let root = try decoder.decode(RootRaw<MovieRaw>.self, from: data)
                let movies = root.results.map({ self.translate(movie: $0) })
                completionHandler(movies, nil, (root.totalResults, root.totalPages))
            } catch {
                completionHandler(nil, FetchError.decode("Couldn't decode JSON data: \(error)"), nil)
            }
        }
    }
    
    static func getMoviesPopular(page: Int, completionHandler: @escaping ([Movie]?, Error?, (results: Int, pages: Int)?) -> Void) {
        guard page > 0 else {
            completionHandler(nil, FetchError.decode("Invalid page number (index starts at 1)."), nil)
            return
        }

        var searchURLComponents = URLComponents(string: self.baseURL)!
        searchURLComponents.path = "\(self.apiVersion)/movie/popular"
        searchURLComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]

        self.fetchMovieData(url: searchURLComponents) { (data, error) in
            guard error == nil, let data = data else {
                completionHandler(nil, error, nil)
                return
            }

            do {
                let root = try decoder.decode(RootRaw<MovieRaw>.self, from: data)
                let movies = root.results.map({ self.translate(movie: $0) })
                completionHandler(movies, nil, (root.totalResults, root.totalPages))
            } catch {
                completionHandler(nil, FetchError.decode("Couldn't decode JSON data: \(error)"), nil)
            }
        }
    }
    
    static func getMovieRecommendations(id: Int, page: Int, completionHandler: @escaping ([Movie]?, Error?, (results: Int, pages: Int)?) -> Void) {
        guard page > 0 else {
            completionHandler(nil, FetchError.decode("Invalid page number (index starts at 1)."), nil)
            return
        }

        var searchURLComponents = URLComponents(string: self.baseURL)!
        searchURLComponents.path = "\(self.apiVersion)/movie/\(id)/recommendations"
        searchURLComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]

        self.fetchMovieData(url: searchURLComponents) { (data, error) in
            guard error == nil, let data = data else {
                completionHandler(nil, error, nil)
                return
            }

            do {
                let root = try decoder.decode(RootRaw<MovieRaw>.self, from: data)
                let movies = root.results.map({ self.translate(movie: $0) })
                completionHandler(movies, nil, (root.totalResults, root.totalPages))
            } catch {
                completionHandler(nil, FetchError.decode("Couldn't decode JSON data: \(error)"), nil)
            }
        }
    }

    static func getMoviesComingSoon(page: Int, completionHandler: @escaping ([Movie]?, Error?, (results: Int, pages: Int)?) -> Void) {
        guard page > 0 else {
            completionHandler(nil, FetchError.decode("Invalid page number (index starts at 1)."), nil)
            return
        }
        
        var searchURLComponents = URLComponents(string: self.baseURL)!
        searchURLComponents.path = "\(self.apiVersion)/movie/upcoming"
        searchURLComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]
        
        self.fetchMovieData(url: searchURLComponents) { (data, error) in
            guard error == nil, let data = data else {
                completionHandler(nil, error, nil)
                return
            }
            
            do {
                let root = try decoder.decode(RootRaw<MovieRaw>.self, from: data)
                let movies = root.results.map({ self.translate(movie: $0) })
                completionHandler(movies, nil, (root.totalResults, root.totalPages))
            } catch {
                completionHandler(nil, FetchError.decode("Couldn't decode JSON data: \(error)"), nil)
            }
        }
    }
    
    static func searchForMovies(query: String, page: Int, completionHandler: @escaping ([Movie]?, Error?, (results: Int, pages: Int)?) -> Void) {
        guard page > 0 else {
            completionHandler(nil, FetchError.decode("Invalid page number (index starts at 1)."), nil)
            return
        }
        
        if query.count == 0 {
            completionHandler([], nil, nil)
            return
        }
        
        var searchURLComponents = URLComponents(string: self.baseURL)!
        searchURLComponents.path = "\(self.apiVersion)/search/movie"
        searchURLComponents.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        self.fetchMovieData(url: searchURLComponents) { (data, error) in
            guard error == nil, let data = data else {
                completionHandler(nil, error, nil)
                return
            }
            
            do {
                let root = try decoder.decode(RootRaw<MovieRaw>.self, from: data)
                let movies = root.results.map({ self.translate(movie: $0) })
                completionHandler(movies, nil, (root.totalResults, root.totalPages))
            } catch {
                completionHandler(nil, FetchError.decode("Couldn't decode JSON data: \(error)"), nil)
            }
        }
    }
    
    static func getPerson(id: Int, completionHandler: @escaping (Person?, Error?) -> Void) {
        let appendString = "movie_credits"
        var searchURLComponents = URLComponents(string: self.baseURL)!
        searchURLComponents.path = "\(self.apiVersion)/person/\(id)"
        searchURLComponents.queryItems = [
            URLQueryItem(name: "append_to_response", value: appendString),
        ]
        
        self.fetchPersonData(url: searchURLComponents) { (data, error) in
            guard error == nil, let data = data else {
                completionHandler(nil, error)
                return
            }
            
            do {
                let personRaw = try decoder.decode(PersonRaw.self, from: data)
                let person = self.translate(person: personRaw)
                completionHandler(person, nil)
            } catch {
                completionHandler(nil, FetchError.decode("Couldn't decode JSON data: \(error)"))
            }
        }
    }
    
    static func searchForPeople(query: String, page: Int, completionHandler: @escaping ([Person]?, Error?, (results: Int, pages: Int)?) -> Void) {
        guard page > 0 else {
            completionHandler(nil, FetchError.decode("Invalid page number (index starts at 1)."), nil)
            return
        }
        
        if query.count == 0 {
            completionHandler([], nil, nil)
            return
        }
        
        var searchURLComponents = URLComponents(string: self.baseURL)!
        searchURLComponents.path = "\(self.apiVersion)/search/person"
        searchURLComponents.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        self.fetchPersonData(url: searchURLComponents) { (data, error) in
            guard error == nil, let data = data else {
                completionHandler(nil, error, nil)
                return
            }
            
            do {
                let root = try decoder.decode(RootRaw<PersonRaw>.self, from: data)
                let people = root.results.map({ self.translate(person: $0) })
                completionHandler(people, nil, (root.totalResults, root.totalPages))
            } catch {
                completionHandler(nil, FetchError.decode("Couldn't decode JSON data: \(error)"), nil)
            }
        }
    }
}

// MARK: - API Fetchers

extension TMDBWrapper {
    static func fetchMovieData(url: URLComponents, completionHandler: @escaping (Data?, Error?) -> Void) {
        
        let queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "with_original_language", value: languageCode),
            URLQueryItem(name: "language", value: "\(languageCode)-\(regionCode)"),
            URLQueryItem(name: "region", value: regionCode),
            URLQueryItem(name: "certification_country", value: regionCode)
        ]
        
        var queryURL = url
        if queryURL.queryItems == nil {
            queryURL.queryItems = queryItems
        } else {
            queryURL.queryItems?.append(contentsOf: queryItems)
        }
        
        fetchData(url: queryURL, completionHandler: completionHandler)
    }
    
    static func fetchPersonData(url: URLComponents, completionHandler: @escaping (Data?, Error?) -> Void) {
        let queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "with_original_language", value: languageCode),
            URLQueryItem(name: "language", value: "\(languageCode)-\(regionCode)"),
            URLQueryItem(name: "region", value: regionCode)
        ]
        
        var queryURL = url
        if queryURL.queryItems == nil {
            queryURL.queryItems = queryItems
        } else {
            queryURL.queryItems?.append(contentsOf: queryItems)
        }
        
        fetchData(url: queryURL, completionHandler: completionHandler)
    }
    
    static func fetchData(url: URLComponents, completionHandler: @escaping (Data?, Error?) -> Void) {
        guard let queryURL = url.url else { return }
        
        var request = URLRequest(url: queryURL)
        request.httpMethod = "GET"
        request.cachePolicy = .useProtocolCachePolicy
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                completionHandler(nil, error)
                return
            }
            
            guard let responseData = data else {
                completionHandler(nil, FetchError.noData("Response didn't contain any data."))
                return
            }
            
            completionHandler(responseData, nil)
        }.resume()
    }
    
    static func fetchImage(url: String?, width: ImageSize, completionHandler: @escaping (UIImage?, Error?) -> Void) {
        guard let url = url else {
            completionHandler(nil, FetchError.image("No image URL supplied"))
            return
        }
        
        var imageURL: URL?
        
        if let width = (width as? Movie.PosterSize)?.rawValue {
            imageURL = URL(string: "\(self.imageBaseURL)/\(width)/\(url)")
        } else if let width = (width as? Movie.BackgroundSize)?.rawValue {
            imageURL = URL(string: "\(self.imageBaseURL)/\(width)/\(url)")
        } else if let width = (width as? Person.ProfileSize)?.rawValue {
            imageURL = URL(string: "\(self.imageBaseURL)/\(width)/\(url)")
        }
        
        guard imageURL != nil else {
            completionHandler(nil, FetchError.image("Couldn't generate image URL"))
            return
        }
        
        URLSession.shared.dataTask(with: imageURL!) { (data, response, error) in
            DispatchQueue.main.async {
                guard error == nil else {
                    completionHandler(nil, error)
                    return
                }
                
                guard let imageData = data else {
                    completionHandler(nil, FetchError.noData("Response didn't contain any data."))
                    return
                }
                
                let image = UIImage(data: imageData)
                completionHandler(image, nil)
            }
        }.resume()
    }
}

// MARK: - Local JSON Fetch

extension TMDBWrapper {
    private static func fetchLocalData(url: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        guard let path = Bundle.main.path(forResource: url, ofType: "json") else {
            completionHandler(nil, FetchError.noData("Invalid JSON file"))
            return
        }
        
        do {
            let responseData = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            completionHandler(responseData, nil)
        } catch {
            completionHandler(nil, FetchError.noData("File didn't contain valid JSON data."))
            return
        }
    }
    
    private static func fetchLocalImage(url: String?, width: ImageSize, completionHandler: @escaping (UIImage?, Error?) -> Void) {
        guard let url = url else {
            completionHandler(nil, FetchError.image("No image URL supplied"))
            return
        }

        guard let path = Bundle.main.path(forResource: url, ofType: nil) else {
            completionHandler(nil, FetchError.noData("Invalid JSON file"))
            return
        }

        if let imageData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
            let poster = UIImage(data: imageData)
            
            DispatchQueue.main.async {
                completionHandler(poster, nil)
            }
        }
    }
}

// MARK: - JSON Decoder and Transformer

extension TMDBWrapper {
    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.custom({ (decoder) -> Date in
            do {
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
            
                if let date = DateFormatter.iso8601DAw.date(from: dateString) {
                    return date
                }
                
                if let date = DateFormatter.iso8601DTw.date(from: dateString) {
                    return date
                }
                
                print("Error: Unable to create date object for string: \(dateString)")
            } catch {
                print("Error: \(error)")
            }
            
            return Date()
        })
        
        return decoder
    }
    
    private static func translate(movie mv: MovieRaw) -> Movie {
        let movie = Movie(id: mv.id, title: mv.title)
        
        if let overview = mv.overview, overview.count > 0 {
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

        movie.certification = releaseInfo.0
        movie.genres = mv.genres()
        movie.bonusCredits = Movie.Credits(mv.bonusCredits())
        movie.team = mv.team()
        movie.trailers = mv.trailers()
        movie.collection = mv.collection()

        for trailer in movie.trailers ?? [] {
            print(trailer.url ?? "No URL")
        }
        
        return movie
    }
    
    private static func translate(person p: PersonRaw) -> Person {
        let person = Person(id: p.id, name: p.name)
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

// MARK: - JSON Structures

extension TMDBWrapper {
    // Pass codable generic to specify type of results
    private struct RootRaw<T:Codable>: Codable {
        var results: [T]
        var totalResults: Int
        var totalPages: Int
        
        private enum CodingKeys : String, CodingKey {
            case results
            case totalResults = "total_results"
            case totalPages = "total_pages"
        }
    }
    
    private struct MovieRaw: Codable {
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
            
            let filteredReleases = releases.filter({ $0.country == regionCode })
            guard filteredReleases.count > 0 else {
                return (nil, nil)
            }

            var release = filteredReleases[0].dates.filter({ $0.type == .Theatrical })
            if release.count < 1 {
                release = filteredReleases[0].dates.filter({ $0.type == .TheatricalLimited })
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
            guard let genres = genresRaw else {
                return nil
            }
            
            if genres.count > 2 {
                return genres[0..<2].map({ $0.name })
            } else{
                return genres.map({ $0.name })
            }
        }
        
        func bonusCredits() -> (during: Bool, after: Bool) {
            var duringCredits = false
            var afterCredits = false
            
            guard keywords != nil, let keywords = keywords?.keywords else {
                return (duringCredits, afterCredits)
            }
            
            for keyword in keywords {
                if keyword.id == TMDBWrapper.bonusKeywords["during"] {
                    duringCredits = true
                }
                
                if keyword.id == TMDBWrapper.bonusKeywords["after"] {
                    afterCredits = true
                }
            }
            
            return (duringCredits, afterCredits)
        }
        
        func team() -> [Person] {
            var team = [Person]()
            
            guard let teamRaw = self.teamRaw else {
                return team
            }

            for person in teamRaw.crew.filter({ $0.role == "Director" }) {
                let member = Person(id:     person.id,
                                    name:   person.name,
                                    role:   person.role,
                                    pic:    person.profilePicture,
                                    type:   .Crew)
                team.append(member)
            }

            for person in teamRaw.cast {
                let member = Person(id:     person.id,
                                    name:   person.name,
                                    role:   person.role,
                                    pic:    person.profilePicture,
                                    type:   .Cast)
                team.append(member)
            }
            
            return team
        }
        
        func trailers() -> [MovieTrailer]? {
            guard let trailersRaw = trailersRaw else {
                return nil
            }
            var trailers = [MovieTrailer]()
            for t in trailersRaw.trailers {
                let trailer = MovieTrailer(id: t.id,
                                           title: t.name,
                                           key: t.key,
                                           type: t.type,
                                           site: t.site,
                                           official: t.official,
                                           publishedAt: t.publishedAt)
                trailers.append(trailer)
            }

            return trailers
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

        func collection() -> MovieCollection? {
            guard let stub = collectionRaw else { return nil }
            return MovieCollection(id: stub.id, name: stub.name,
                                   poster: stub.poster, background: stub.background)
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
            private enum CodingKeys : String, CodingKey {
                case releases = "results"
            }
        
            struct ReleaseDateWrapperRaw: Codable {
                var country: String
                var dates: [ReleaseDateRaw]
                
                enum CodingKeys : String, CodingKey {
                    case country = "iso_3166_1"
                    case dates = "release_dates"
                }
                
                struct ReleaseDateRaw: Codable {
                    var type: ReleaseType
                    var releaseDate: Date
                    var certification: String
                    
                    enum CodingKeys : String, CodingKey {
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
                
                enum CodingKeys : String, CodingKey {
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
                
                enum CodingKeys : String, CodingKey {
                    case name, id
                    case role = "job"
                    case profilePicture = "profile_path"
                }
            }
        }

        struct TrailersRaw: Codable {
            var trailers: [Trailer]
            
            enum CodingKeys : String, CodingKey {
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
    
    private struct CollectionRaw: Codable {
        var id: Int
        var name: String
        var overview: String?
        var parts: [MovieRaw]
    }

    private struct PersonRaw: Codable {
        var id: Int
        var name: String
        var popularity: Float
        var profilePicture: String?
        var birthday: Date?
        var placeOfBirth: String?
        var biography: String?
        var imdbID: String?
        var test: String?
        var creditsRaw: CreditsRaw?
        
        func credits() -> [Movie] {
            var credits = [Movie]()
            guard let creditsRaw = self.creditsRaw else {
                return credits
            }

            for collection in [creditsRaw.cast, creditsRaw.crew] {
                for movie in collection {
                    let credit = Movie(id: movie.id, title: movie.title)
                    credit.poster = movie.poster
                    credit.creditRole = movie.role
                    credit.popularity = movie.popularity
                    if let releaseDateString = movie.releaseDateString {
                        if releaseDateString.isEmpty == false {
                            credit.releaseDate = releaseDateString.toDate(format: .iso8601DAw)
                        }
                    }

                    credits.append(credit)
                }
            }
            
            // Convert to set to remove duplicates, then sort by release date
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
