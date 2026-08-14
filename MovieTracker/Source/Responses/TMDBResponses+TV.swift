//
//  TMDBResponses+TV.swift
//  MovieTracker
//
//  Raw `Codable` shapes for TMDB TV endpoints. Reuses the movie DTOs for
//  watch providers (see TMDBResponses+Movie), trailers, genres, and cast where identical.
//

import Foundation

extension TMDBWrapper {
    struct ShowRaw: Codable {
        var id: Int
        var name: String
        var overview: String?
        var firstAirDateString: String?
        var lastAirDateString: String?
        var nextEpisodeRaw: ScheduledEpisodeRaw?
        var status: String?
        var poster: String?
        var background: String?
        var rating: Double?
        var popularity: Double?
        var voteCount: Int?
        var genresRaw: [MovieRaw.GenreRaw]?
        var networksRaw: [NetworkRaw]?
        var originCountry: [String]?
        var createdByRaw: [PersonStubRaw]?
        var seasonsRaw: [SeasonRaw]?
        var trailersRaw: MovieRaw.TrailersRaw?
        var aggregateCreditsRaw: AggregateCreditsRaw?
        var contentRatingsRaw: ContentRatingsRaw?
        var watchRaw: MovieRaw.WatchProvidersRaw?

        /// The US-style TV rating for the user's region, falling back to the US entry.
        func certification() -> String? {
            guard let results = contentRatingsRaw?.results, !results.isEmpty else { return nil }
            let region = NSLocale.current.region?.identifier ?? "US"
            let pick = results.first { $0.country == region && !$0.rating.isEmpty }
                ?? results.first { $0.country == "US" && !$0.rating.isEmpty }
            return pick?.rating
        }

        func genres() -> [String]? {
            guard let genres = genresRaw else { return nil }
            return genres.count > 2 ? genres[0..<2].map { $0.name } : genres.map { $0.name }
        }

        func networks() -> [String]? {
            guard let networks = networksRaw, !networks.isEmpty else { return nil }
            return networks.map { $0.name }
        }

        func creators() -> [Person] {
            (createdByRaw ?? []).map {
                Person(id: $0.id, name: $0.name, role: "Creator", pic: $0.profilePicture, type: .Crew)
            }
        }

        /// Cast ranked by episodes appeared in, so the enduring regulars surface first.
        func recurringCast(limit: Int = 15) -> [Person] {
            aggregateCreditsRaw?.rankedCast(limit: limit) ?? []
        }

        func trailers() -> [MediaTrailer]? {
            guard let trailersRaw else { return nil }
            return trailersRaw.trailers.map {
                MediaTrailer(id: $0.id, title: $0.name, key: $0.key, type: $0.type,
                             site: $0.site, official: $0.official, publishedAt: $0.publishedAt)
            }
        }

        func seasonsList() -> [Season] {
            (seasonsRaw ?? []).map { $0.season() }
        }

        func watchByRegion() -> [String: WatchAvailability] {
            watchRaw?.availabilityByRegion() ?? [:]
        }

        enum CodingKeys: String, CodingKey {
            case id, name, overview, status, popularity
            case firstAirDateString = "first_air_date"
            case lastAirDateString = "last_air_date"
            case nextEpisodeRaw = "next_episode_to_air"
            case poster = "poster_path"
            case background = "backdrop_path"
            case rating = "vote_average"
            case voteCount = "vote_count"
            case genresRaw = "genres"
            case networksRaw = "networks"
            case originCountry = "origin_country"
            case createdByRaw = "created_by"
            case seasonsRaw = "seasons"
            case trailersRaw = "videos"
            case aggregateCreditsRaw = "aggregate_credits"
            case contentRatingsRaw = "content_ratings"
            case watchRaw = "watch/providers"
        }

        struct NetworkRaw: Codable {
            var id: Int
            var name: String
        }

        /// Just the air date of `next_episode_to_air` — the rest of that payload duplicates
        /// what the season fetch already carries.
        struct ScheduledEpisodeRaw: Codable {
            var airDateString: String?

            enum CodingKeys: String, CodingKey {
                case airDateString = "air_date"
            }
        }

        struct PersonStubRaw: Codable {
            var id: Int
            var name: String
            var profilePicture: String?

            enum CodingKeys: String, CodingKey {
                case id, name
                case profilePicture = "profile_path"
            }
        }
    }

    struct SeasonRaw: Codable {
        var id: Int
        var seasonNumber: Int
        var name: String
        var overview: String?
        var poster: String?
        var airDateString: String?
        var episodeCount: Int?
        var episodes: [EpisodeRaw]?
        /// Present only when the season is fetched with `append_to_response=aggregate_credits`.
        var aggregateCreditsRaw: AggregateCreditsRaw?

        func season() -> Season {
            var season = Season(id: id, seasonNumber: seasonNumber, name: name,
                                episodeCount: episodeCount ?? episodes?.count ?? 0)
            season.overview = overview
            season.poster = poster
            season.airDate = airDateString?.toDate(format: .iso8601DAw)
            season.episodes = (episodes ?? [])
                .map { $0.episode() }
                .sorted { $0.episodeNumber < $1.episodeNumber }
            season.cast = aggregateCreditsRaw?.rankedCast(limit: 15) ?? []
            return season
        }

        enum CodingKeys: String, CodingKey {
            case id, name, overview, episodes
            case seasonNumber = "season_number"
            case poster = "poster_path"
            case airDateString = "air_date"
            case episodeCount = "episode_count"
            case aggregateCreditsRaw = "aggregate_credits"
        }
    }

    struct EpisodeRaw: Codable {
        var id: Int
        var name: String
        var overview: String?
        var still: String?
        var runtime: Int?
        var rating: Double?
        var airDateString: String?
        var episodeNumber: Int
        var seasonNumber: Int
        var guestStars: [MovieRaw.TeamRaw.CastMemberRaw]?
        var crew: [MovieRaw.TeamRaw.CrewMemberRaw]?

        func episode() -> Episode {
            var episode = Episode(id: id, seasonNumber: seasonNumber,
                                  episodeNumber: episodeNumber, name: name)
            episode.overview = overview
            episode.still = still
            episode.runtime = runtime
            episode.rating = rating
            episode.airDate = airDateString?.toDate(format: .iso8601DAw)
            episode.guestCast = (guestStars ?? [])
                .sorted { $0.order < $1.order }
                .map { Person(id: $0.id, name: $0.name, role: $0.role,
                              pic: $0.profilePicture, type: .Cast) }
            // Directors first, then the rest, so `CastSection` surfaces them on top.
            // Dedupe by id (a person may hold several jobs) to keep list identity stable.
            let directors = (crew ?? []).filter { $0.role == "Director" }
            let others = (crew ?? []).filter { $0.role != "Director" }
            var seen = Set<Int>()
            episode.crew = (directors + others)
                .filter { seen.insert($0.id).inserted }
                .map { Person(id: $0.id, name: $0.name, role: $0.role,
                              pic: $0.profilePicture, type: .Crew) }
            return episode
        }

        enum CodingKeys: String, CodingKey {
            case id, name, overview, runtime, crew
            case still = "still_path"
            case rating = "vote_average"
            case airDateString = "air_date"
            case episodeNumber = "episode_number"
            case seasonNumber = "season_number"
            case guestStars = "guest_stars"
        }
    }

    struct AggregateCreditsRaw: Codable {
        var cast: [AggregateCastRaw]

        /// Cast ranked by episodes appeared in (then billing order), capped at `limit`.
        /// Shared by the show's recurring cast and a season's cast.
        func rankedCast(limit: Int) -> [Person] {
            cast
                .sorted {
                    if $0.totalEpisodeCount != $1.totalEpisodeCount {
                        return $0.totalEpisodeCount > $1.totalEpisodeCount
                    }
                    return ($0.order ?? .max) < ($1.order ?? .max)
                }
                .prefix(limit)
                .map { Person(id: $0.id, name: $0.name, role: $0.characterName,
                              pic: $0.profilePicture, type: .Cast) }
        }

        struct AggregateCastRaw: Codable {
            var id: Int
            var name: String
            var profilePicture: String?
            var order: Int?
            var totalEpisodeCount: Int
            var roles: [RoleRaw]?

            /// The first non-empty character the actor plays across the series.
            var characterName: String? {
                roles?.compactMap { $0.character.isEmpty ? nil : $0.character }.first
            }

            enum CodingKeys: String, CodingKey {
                case id, name, roles, order
                case profilePicture = "profile_path"
                case totalEpisodeCount = "total_episode_count"
            }

            struct RoleRaw: Codable {
                var character: String
            }
        }
    }

    struct ContentRatingsRaw: Codable {
        var results: [RatingRaw]

        struct RatingRaw: Codable {
            var country: String
            var rating: String

            enum CodingKeys: String, CodingKey {
                case country = "iso_3166_1"
                case rating
            }
        }
    }
}
