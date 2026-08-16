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

        // TMDB lists a title once per job, so a director who also wrote and produced appears
        // three times. Each title becomes one credit listing every role they had.
        func credits() -> [Movie] {
            guard let creditsRaw = self.creditsRaw else { return [] }

            var byID = [Int: Movie]()
            var roles = [Int: [(kind: CreditKind, role: String?)]]()
            for (isCast, collection) in [(true, creditsRaw.cast), (false, creditsRaw.crew)] {
                for movie in collection {
                    var credit = Movie(id: movie.id, title: movie.title)
                    credit.poster = movie.poster
                    credit.creditRole = movie.role
                    credit.creditKind = .resolve(isCast: isCast, role: movie.role,
                                                 department: movie.department)
                    credit.creditOrder = movie.order
                    credit.popularity = movie.popularity
                    credit.voteCount = movie.voteCount
                    if let releaseDateString = movie.releaseDateString, !releaseDateString.isEmpty {
                        credit.releaseDate = releaseDateString.toDate(format: .iso8601DAw)
                    }
                    roles[movie.id, default: []].append((credit.creditKind ?? .crew, movie.role))
                    if let kept = byID[movie.id], rank(kept.creditKind) <= rank(credit.creditKind) {
                        continue
                    }
                    byID[movie.id] = credit
                }
            }

            return byID.values
                .map { merging($0, roles: roles[$0.id] ?? []) }
                .sorted {
                    guard let releaseA = $0.releaseDate else { return false }
                    guard let releaseB = $1.releaseDate else { return true }
                    return releaseA.compare(releaseB) == .orderedDescending
                }
        }

        func tvCredits() -> [Show] {
            guard let raw = tvCreditsRaw else { return [] }

            var byID = [Int: Show]()
            var roles = [Int: [(kind: CreditKind, role: String?)]]()
            for (isCast, collection) in [(true, raw.cast), (false, raw.crew)] {
                for item in collection {
                    var credit = Show(id: item.id, name: item.name)
                    credit.poster = item.poster
                    credit.creditRole = item.role
                    credit.creditKind = .resolve(isCast: isCast, role: item.role,
                                                 department: item.department)
                    credit.popularity = item.popularity
                    credit.voteCount = item.voteCount
                    credit.episodeCount = item.episodeCount
                    if let airDateString = item.firstAirDateString, !airDateString.isEmpty {
                        credit.firstAirDate = airDateString.toDate(format: .iso8601DAw)
                    }
                    roles[item.id, default: []].append((credit.creditKind ?? .crew, item.role))
                    if let kept = byID[item.id], rank(kept.creditKind) <= rank(credit.creditKind) {
                        continue
                    }
                    byID[item.id] = credit
                }
            }

            return byID.values
                .map { merging($0, roles: roles[$0.id] ?? []) }
                .sorted {
                    guard let airA = $0.firstAirDate else { return false }
                    guard let airB = $1.firstAirDate else { return true }
                    return airA.compare(airB) == .orderedDescending
                }
        }

        private func rank(_ kind: CreditKind?) -> Int { (kind ?? .crew).rank }

        private func merging(_ credit: Movie,
                             roles: [(kind: CreditKind, role: String?)]) -> Movie {
            var credit = credit
            let merged = CreditKind.merge(roles)
            credit.creditRole = merged.role
            credit.creditKind = merged.kind
            return credit
        }

        private func merging(_ credit: Show,
                             roles: [(kind: CreditKind, role: String?)]) -> Show {
            var credit = credit
            let merged = CreditKind.merge(roles)
            credit.creditRole = merged.role
            credit.creditKind = merged.kind
            return credit
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
                /// TMDB's crew department ("Directing", "Writing", "Production", …), which
                /// groups a job without having to know the job itself. Nil for cast credits.
                var department: String?
                var popularity: Double?
                var voteCount: Int?
                var episodeCount: Int?

                var role: String? { character ?? job }

                enum CodingKeys: String, CodingKey {
                    case id, name, overview, character, job, department, popularity
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
                /// TMDB's crew department ("Directing", "Writing", "Production", …), which
                /// groups a job without having to know the job itself. Nil for cast credits.
                var department: String?
                var popularity: Double?
                var voteCount: Int?
                var order: Int?

                /// Cast credits carry a `character`; crew credits carry a `job`.
                var role: String? { character ?? job }

                enum CodingKeys: String, CodingKey {
                    case id, title, overview, character, job, department, popularity, order
                    case voteCount = "vote_count"
                    case releaseDateString = "release_date"
                    case poster = "poster_path"
                }
            }
        }
    }
}
