//
//  TMDBResponses+Movie.swift
//  MovieTracker
//
//  Raw `Codable` shapes for TMDB movie endpoints. Watch providers are shared with TV.
//

import Foundation

extension TMDBWrapper {
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
        var voteCount: Int?
        var releaseDates: ReleaseDatesRaw?
        var genresRaw: [GenreRaw]?
        var trailersRaw: TrailersRaw?
        var imdbID: String?
        var externalIDs: ExternalIDsRaw?
        var keywords: Keywords?
        var teamRaw: TeamRaw?
        var collectionRaw: CollectionStubRaw?
        var watchRaw: WatchProvidersRaw?

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

            // TMDB lists re-releases as additional Theatrical entries in no order, so `dates[0]` can surface
            // one over the original.
            guard let earliest = release.min(by: { $0.releaseDate < $1.releaseDate }) else {
                return (nil, nil)
            }

            let certification = release.first { !$0.certification.isEmpty }?.certification
            return (certification ?? "Unavailable", earliest.releaseDate)
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

            let crew = teamRaw.crew.filter { $0.role == "Director" }
                     + teamRaw.crew.filter { $0.role != "Director" }
            let crewMembers = Self.dedupedPeople(
                crew.map { ($0.id, $0.name, $0.role, $0.profilePicture) }, type: .Crew)
            let castMembers = Self.dedupedPeople(
                teamRaw.cast.map { ($0.id, $0.name, $0.role, $0.profilePicture) }, type: .Cast)

            return crewMembers + castMembers
        }

        // TMDB lists a separate credit per job, so repeated ids would break list identity.
        private static func dedupedPeople(
            _ raw: [(id: Int, name: String, role: String, pic: String?)],
            type: Person.PersonType
        ) -> [Person] {
            var order = [Int]()
            var people = [Int: Person]()
            var roles = [Int: [String]]()
            for entry in raw {
                if roles[entry.id] == nil {
                    order.append(entry.id)
                    roles[entry.id] = []
                    people[entry.id] = Person(id: entry.id, name: entry.name,
                                              role: nil, pic: entry.pic, type: type)
                }
                if !entry.role.isEmpty, !roles[entry.id]!.contains(entry.role) {
                    roles[entry.id]!.append(entry.role)
                }
            }
            return order.map { id in
                var person = people[id]!
                let joined = roles[id]!.joined(separator: ", ")
                person.role = joined.isEmpty ? nil : joined
                return person
            }
        }

        func trailers() -> [MediaTrailer]? {
            guard let trailersRaw = trailersRaw else { return nil }
            return trailersRaw.trailers.map {
                MediaTrailer(id: $0.id, title: $0.name, key: $0.key, type: $0.type,
                             site: $0.site, official: $0.official, publishedAt: $0.publishedAt)
            }
        }

        func collection() -> MovieCollection? {
            guard let stub = collectionRaw else { return nil }
            return MovieCollection(id: stub.id, name: stub.name,
                                   poster: stub.poster, background: stub.background)
        }

        func watchByRegion() -> [String: WatchAvailability] {
            watchRaw?.availabilityByRegion() ?? [:]
        }

        enum CodingKeys: String, CodingKey {
            case id, title, overview, runtime, popularity, keywords
            case voteCount = "vote_count"
            case imdbID = "imdb_id"
            case externalIDs = "external_ids"
            case releaseDateString = "release_date"
            case poster = "poster_path"
            case background = "backdrop_path"
            case rating = "vote_average"
            case releaseDates = "release_dates"
            case genresRaw = "genres"
            case trailersRaw = "videos"
            case teamRaw = "credits"
            case collectionRaw = "belongs_to_collection"
            case watchRaw = "watch/providers"
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

        struct WatchProvidersRaw: Codable {
            var results: [String: RegionRaw]

            struct RegionRaw: Codable {
                var link: String?
                var flatrate: [ProviderRaw]?
                var free: [ProviderRaw]?
                var ads: [ProviderRaw]?
            }

            struct ProviderRaw: Codable {
                var providerId: Int
                var providerName: String
                var logoPath: String?
                var displayPriority: Int?
                var displayPriorities: [String: Int]?

                enum CodingKeys: String, CodingKey {
                    case providerId = "provider_id"
                    case providerName = "provider_name"
                    case logoPath = "logo_path"
                    case displayPriority = "display_priority"
                    case displayPriorities = "display_priorities"
                }

                func isAvailable(in region: String) -> Bool {
                    guard let displayPriorities else { return true }
                    return displayPriorities[region] != nil
                }

                // A lower priority number is more popular in the region.
                func priority(in region: String) -> Int {
                    displayPriorities?[region] ?? displayPriority ?? .max
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

    /// TMDB gives TV's `imdb_id` only under `append_to_response=external_ids`, never at the top level of /tv/{id}.
    struct ExternalIDsRaw: Codable {
        var imdbID: String?
        var wikidataID: String?

        enum CodingKeys: String, CodingKey {
            case imdbID = "imdb_id"
            case wikidataID = "wikidata_id"
        }
    }

    struct ProviderListRaw: Codable {
        var results: [MovieRaw.WatchProvidersRaw.ProviderRaw]
    }
}

// MARK: - Shared watch-provider mapping (movies + TV)

extension TMDBWrapper.MovieRaw.WatchProvidersRaw {
    func availabilityByRegion() -> [String: WatchAvailability] {
        var out: [String: WatchAvailability] = [:]
        for (code, region) in results {
            let buckets = [region.flatrate, region.free, region.ads]
                .compactMap { $0 }.flatMap { $0 }
            var seen = Set<Int>()
            let providers = buckets
                .sorted { ($0.displayPriority ?? .max) < ($1.displayPriority ?? .max) }
                .compactMap { raw -> WatchProvider? in
                    guard seen.insert(raw.providerId).inserted else { return nil }
                    return WatchProvider(id: raw.providerId, name: raw.providerName,
                                         logoPath: raw.logoPath)
                }
            guard !providers.isEmpty else { continue }
            out[code] = WatchAvailability(providers: providers,
                                          justWatchLink: region.link.flatMap { URL(string: $0) })
        }
        return out
    }
}
