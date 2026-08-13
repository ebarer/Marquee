//
//  TMDBResponses+Person.swift
//  MovieTracker
//
//  Raw `Codable` shapes for TMDB person endpoints (movie + TV credits).
//

import Foundation

extension TMDBWrapper {
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
        var tvCreditsRaw: TVCreditsRaw?

        func credits() -> [Movie] {
            guard let creditsRaw = self.creditsRaw else { return [] }

            var credits = [Movie]()
            for collection in [creditsRaw.cast, creditsRaw.crew] {
                for movie in collection {
                    var credit = Movie(id: movie.id, title: movie.title)
                    credit.poster = movie.poster
                    credit.creditRole = movie.role
                    credit.creditOrder = movie.order
                    credit.popularity = movie.popularity
                    credit.voteCount = movie.voteCount
                    if let releaseDateString = movie.releaseDateString, !releaseDateString.isEmpty {
                        credit.releaseDate = releaseDateString.toDate(format: .iso8601DAw)
                    }
                    credits.append(credit)
                }
            }

            return Set(credits).sorted {
                guard let releaseA = $0.releaseDate else { return false }
                guard let releaseB = $1.releaseDate else { return true }
                return releaseA.compare(releaseB) == .orderedDescending
            }
        }

        func tvCredits() -> [Show] {
            guard let raw = tvCreditsRaw else { return [] }

            var credits = [Show]()
            for collection in [raw.cast, raw.crew] {
                for item in collection {
                    var credit = Show(id: item.id, name: item.name)
                    credit.poster = item.poster
                    credit.creditRole = item.role
                    credit.popularity = item.popularity
                    credit.voteCount = item.voteCount
                    credit.episodeCount = item.episodeCount
                    if let airDateString = item.firstAirDateString, !airDateString.isEmpty {
                        credit.firstAirDate = airDateString.toDate(format: .iso8601DAw)
                    }
                    credits.append(credit)
                }
            }

            return Set(credits).sorted {
                guard let airA = $0.firstAirDate else { return false }
                guard let airB = $1.firstAirDate else { return true }
                return airA.compare(airB) == .orderedDescending
            }
        }

        enum CodingKeys: String, CodingKey {
            case id, name, popularity
            case birthday, biography
            case imdbID = "imdb_id"
            case creditsRaw = "movie_credits"
            case tvCreditsRaw = "tv_credits"
            case profilePicture = "profile_path"
            case placeOfBirth = "place_of_birth"
        }

        struct TVCreditsRaw: Codable {
            var cast: [TVCreditRaw]
            var crew: [TVCreditRaw]

            struct TVCreditRaw: Codable {
                var id: Int
                var name: String
                var firstAirDateString: String?
                var overview: String?
                var poster: String?
                var character: String?
                var job: String?
                var popularity: Double?
                var voteCount: Int?
                var episodeCount: Int?

                var role: String? { character ?? job }

                enum CodingKeys: String, CodingKey {
                    case id, name, overview, character, job, popularity
                    case voteCount = "vote_count"
                    case firstAirDateString = "first_air_date"
                    case poster = "poster_path"
                    case episodeCount = "episode_count"
                }
            }
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
                var voteCount: Int?
                var order: Int?

                /// Cast credits carry a `character`; crew credits carry a `job`.
                var role: String? { character ?? job }

                enum CodingKeys: String, CodingKey {
                    case id, title, overview, character, job, popularity, order
                    case voteCount = "vote_count"
                    case releaseDateString = "release_date"
                    case poster = "poster_path"
                }
            }
        }
    }
}
