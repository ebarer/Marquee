//
//  TMDBResponses+Person.swift
//  MovieTracker
//
//  Raw `Codable` shapes for TMDB person endpoints, movie and TV credits.
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

        // TMDB lists a title once per job, so a director who also wrote and produced appears three times.
        func credits() -> [Movie] {
            guard let creditsRaw = self.creditsRaw else { return [] }

            var byID = [Int: Movie]()
            var roles = [Int: [(kind: CreditKind, role: String?, isCast: Bool)]]()
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
                    roles[movie.id, default: []].append((credit.creditKind ?? .crew, movie.role,
                                                        isCast))
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
            var roles = [Int: [(kind: CreditKind, role: String?, isCast: Bool)]]()
            var creditIDs = [Int: [String]]()
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
                    roles[item.id, default: []].append((credit.creditKind ?? .crew, item.role,
                                                       isCast))
                    if let creditID = item.creditID {
                        creditIDs[item.id, default: []].append(creditID)
                    }
                    if let kept = byID[item.id], rank(kept.creditKind) <= rank(credit.creditKind) {
                        continue
                    }
                    byID[item.id] = credit
                }
            }

            return byID.values
                .map { show -> Show in
                    var credit = merging(show, roles: roles[show.id] ?? [])
                    credit.creditIDs = creditIDs[show.id] ?? []
                    return credit
                }
                .sorted {
                    guard let airA = $0.firstAirDate else { return false }
                    guard let airB = $1.firstAirDate else { return true }
                    return airA.compare(airB) == .orderedDescending
                }
        }

        private func rank(_ kind: CreditKind?) -> Int { (kind ?? .crew).rank }

        private func merging(_ credit: Movie,
                             roles: [(kind: CreditKind, role: String?, isCast: Bool)]) -> Movie {
            var credit = credit
            let merged = CreditKind.merge(roles)
            credit.creditRole = merged.character
            credit.creditJobs = merged.jobs
            credit.creditKind = merged.kind
            return credit
        }

        private func merging(_ credit: Show,
                             roles: [(kind: CreditKind, role: String?, isCast: Bool)]) -> Show {
            var credit = credit
            let merged = CreditKind.merge(roles)
            credit.creditRole = merged.character
            credit.creditJobs = merged.jobs
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
                var department: String?
                var popularity: Double?
                var voteCount: Int?
                var episodeCount: Int?
                var creditID: String?

                var role: String? { character ?? job }

                enum CodingKeys: String, CodingKey {
                    case id, name, overview, character, job, department, popularity
                    case voteCount = "vote_count"
                    case firstAirDateString = "first_air_date"
                    case poster = "poster_path"
                    case episodeCount = "episode_count"
                    case creditID = "credit_id"
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
                var department: String?
                var popularity: Double?
                var voteCount: Int?
                var order: Int?

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

    /// /credit/{credit_id}: the episode-level detail behind one TV credit.
    struct CreditRaw: Codable {
        var media: MediaRaw?

        func credit() -> EpisodeCredit {
            EpisodeCredit(seasons: media?.seasonCredits() ?? [])
        }

        struct MediaRaw: Codable {
            var episodes: [EpisodeRaw]?
            var seasons: [SeasonRaw]?

            // A regular who also has a named special carries both shapes at once; reading either/or loses one.
            func seasonCredits() -> [EpisodeCredit.SeasonCredit] {
                let listed = Dictionary(grouping: episodes ?? [], by: \.seasonNumber)
                var known: [Int: Season] = [:]
                for raw in seasons ?? [] { known[raw.seasonNumber] = raw.season() }

                // A season named with none of its episodes singled out is the person's whole run.
                var credits = known
                    .filter { listed[$0.key] == nil }
                    .map { EpisodeCredit.SeasonCredit(season: $0.value) }

                // Episodes named within a season are the credit. TMDB sometimes omits the season itself, so stand
                // any missing one up from its episodes.
                credits += listed.map { number, episodes in
                    let season = known[number] ?? standIn(number: number, from: episodes)
                    return EpisodeCredit.SeasonCredit(
                        season: season, episodeNumbers: Set(episodes.map(\.episodeNumber)))
                }

                return credits.sorted { $0.season.seasonNumber < $1.season.seasonNumber }
            }

            // Take the air date off the episodes, or every season files under the show's premiere year.
            private func standIn(number: Int, from episodes: [EpisodeRaw]) -> Season {
                var season = Season(id: -(number + 1), seasonNumber: number,
                                    name: "Season \(number)")
                season.airDate = episodes
                    .compactMap { $0.airDateString?.toDate(format: .iso8601DAw) }
                    .min()
                return season
            }
        }
    }
}
