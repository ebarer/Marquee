//
//  TMDBDecodingTests.swift
//  MarqueeTests
//
//  Raw-response decoding and raw->domain translation, offline.
//

import Testing
import Foundation
@testable import Marquee

@Suite struct TMDBDecodingTests {
    private var region: String { NSLocale.current.region?.identifier ?? "US" }

    private func decodeMovie(_ json: String) throws -> TMDBWrapper.MovieRaw {
        try TMDBWrapper.decode(TMDBWrapper.MovieRaw.self, from: Data(json.utf8))
    }

    private func fullMovieJSON() -> String {
        """
        {
          "id": 603, "title": "The Matrix",
          "overview": "A hacker learns the truth.",
          "poster_path": "/poster.jpg", "backdrop_path": "/bg.jpg",
          "runtime": 136, "vote_average": 8.2, "popularity": 55.5,
          "imdb_id": "tt0133093", "release_date": "1999-03-31",
          "genres": [{"name":"Action"},{"name":"Science Fiction"},{"name":"Thriller"}],
          "keywords": {"keywords":[{"id":179431,"name":"duringcredits"},{"id":179430,"name":"aftercredits"}]},
          "belongs_to_collection": {"id":2344,"name":"The Matrix Collection","poster_path":"/c.jpg","backdrop_path":"/cb.jpg"},
          "videos": {"results":[
            {"id":"v1","name":"Trailer","key":"abc","type":"Trailer","site":"YouTube","official":true,"published_at":"1999-01-01"}
          ]},
          "credits": {
            "cast":[{"id":6384,"order":0,"name":"Keanu Reeves","character":"Neo","profile_path":"/k.jpg"}],
            "crew":[
              {"id":9339,"name":"Lana Wachowski","job":"Director","profile_path":"/l.jpg"},
              {"id":9340,"name":"Editor Person","job":"Editor","profile_path":null}
            ]
          },
          "release_dates": {"results":[
            {"iso_3166_1":"\(region)","release_dates":[
              {"type":3,"release_date":"1999-03-31T00:00:00.000Z","certification":"R"}
            ]}
          ]}
        }
        """
    }

    @Test func decodesRemappedKeys() throws {
        let raw = try decodeMovie(fullMovieJSON())
        #expect(raw.id == 603)
        #expect(raw.poster == "/poster.jpg")
        #expect(raw.background == "/bg.jpg")
        #expect(raw.rating == 8.2)
        #expect(raw.imdbID == "tt0133093")
    }

    @Test func genresCapAtTwo() throws {
        #expect(try decodeMovie(fullMovieJSON()).genres() == ["Action", "Science Fiction"])
    }

    @Test func bonusCreditsFromKeywords() throws {
        let bonus = try decodeMovie(fullMovieJSON()).bonusCredits()
        #expect(bonus.during)
        #expect(bonus.after)
    }

    @Test func teamKeepsDirectorsCastAndCrew() throws {
        let team = try decodeMovie(fullMovieJSON()).team()
        #expect(team.contains { $0.name == "Lana Wachowski" && $0.type == .Crew })
        #expect(team.contains { $0.name == "Keanu Reeves" && $0.type == .Cast })
        #expect(team.contains { $0.name == "Editor Person" && $0.type == .Crew })
        // Directors sort ahead of other crew.
        let crewNames = team.filter { $0.type == .Crew }.map(\.name)
        #expect(crewNames == ["Lana Wachowski", "Editor Person"])
    }

    @Test func trailersMapped() throws {
        let trailers = try #require(try decodeMovie(fullMovieJSON()).trailers())
        #expect(trailers.count == 1)
        #expect(trailers[0].key == "abc")
        #expect(trailers[0].type == .Trailer)
    }

    @Test func collectionMapped() throws {
        let collection = try #require(try decodeMovie(fullMovieJSON()).collection())
        #expect(collection.id == 2344)
        #expect(collection.name == "The Matrix Collection")
    }

    @Test func certificationFromRegionTheatrical() throws {
        let info = try decodeMovie(fullMovieJSON()).certification()
        #expect(info.certification == "R")
        #expect(info.releaseDate != nil)
    }

    @Test func certificationNilWhenNoRegionMatch() throws {
        let json = """
        {"id":1,"title":"X","release_dates":{"results":[
          {"iso_3166_1":"ZZ","release_dates":[{"type":3,"release_date":"2000-01-01T00:00:00.000Z","certification":"PG"}]}
        ]}}
        """
        let info = try decodeMovie(json).certification()
        #expect(info.certification == nil)
        #expect(info.releaseDate == nil)
    }

    @Test func certificationUnavailableWhenEmptyString() throws {
        let json = """
        {"id":1,"title":"X","release_dates":{"results":[
          {"iso_3166_1":"\(region)","release_dates":[{"type":3,"release_date":"2000-01-01T00:00:00.000Z","certification":""}]}
        ]}}
        """
        #expect(try decodeMovie(json).certification().certification == "Unavailable")
    }

    @Test func translateMovieMapsAllFields() throws {
        let movie = TMDBWrapper.translate(movie: try decodeMovie(fullMovieJSON()))
        #expect(movie.id == 603)
        #expect(movie.title == "The Matrix")
        #expect(movie.overview == "A hacker learns the truth.")
        #expect(movie.runtime == 136)
        #expect(movie.certification == "R")
        #expect(movie.genres == ["Action", "Science Fiction"])
        #expect(movie.bonusCredits.raw == (true, true))
        #expect(movie.collection?.id == 2344)
        #expect(movie.primaryTrailer?.key == "abc")
    }

    @Test func translateMovieDropsEmptyOverview() throws {
        let movie = TMDBWrapper.translate(movie: try decodeMovie(#"{"id":1,"title":"X","overview":""}"#))
        #expect(movie.overview == nil)
    }

    @Test func translateMovieFallsBackToReleaseDateString() throws {
        let movie = TMDBWrapper.translate(movie: try decodeMovie(#"{"id":1,"title":"X","release_date":"2010-06-15"}"#))
        #expect(movie.releaseDate == .utc(2010, 6, 15))
    }

    @Test func rootRawDecodesPagination() throws {
        let json = #"{"results":[{"id":1,"title":"A"}],"total_results":42,"total_pages":3}"#
        let root = try TMDBWrapper.decode(TMDBWrapper.RootRaw<TMDBWrapper.MovieRaw>.self, from: Data(json.utf8))
        #expect(root.totalResults == 42)
        #expect(root.totalPages == 3)
        #expect(root.results.count == 1)
    }

    @Test func personCreditsDedupeAndSortNewestFirst() throws {
        let json = """
        {"id":1,"name":"Actor","popularity":9.0,"movie_credits":{
          "cast":[
            {"id":10,"title":"Old","release_date":"1990-01-01","character":"A"},
            {"id":20,"title":"New","release_date":"2020-01-01","character":"B"}
          ],
          "crew":[
            {"id":20,"title":"New","release_date":"2020-01-01","job":"Producer"}
          ]}}
        """
        let raw = try TMDBWrapper.decode(TMDBWrapper.PersonRaw.self, from: Data(json.utf8))
        let credits = raw.credits()
        #expect(credits.count == 2)                       // id 20 deduped
        #expect(credits.map(\.id) == [20, 10])            // newest first
    }

    // Jason Segel on The Late Show: TMDB carries another guest's name on one of his credit ids.
    @Test func tvCreditsKeepEachCreditIDsOwnCharacter() throws {
        let json = """
        {"id":1,"name":"Actor","popularity":9.0,"tv_credits":{
          "cast":[
            {"id":63770,"name":"Show","character":"Self - Guest","credit_id":"a","episode_count":2,
             "genre_ids":[35,10767]},
            {"id":63770,"name":"Show","character":"Jeff Daniels","credit_id":"b","episode_count":1,
             "genre_ids":[35,10767]},
            {"id":63770,"name":"Show","character":"","credit_id":"c","episode_count":1,
             "genre_ids":[35,10767]}
          ],
          "crew":[]}}
        """
        let raw = try TMDBWrapper.decode(TMDBWrapper.PersonRaw.self, from: Data(json.utf8))
        let credit = try #require(raw.tvCredits().first)
        // The stray name can't claim a talk show, so the row reads as the guest spot and hides.
        #expect(credit.creditRole == "Guest")
        #expect(credit.creditKinds == [.appearance])
        #expect(CreditFilter().hides(MediaRef.show(credit).creditKinds))
        // The per-id lookup keeps TMDB's own text, which is what the episode list matches on.
        #expect(credit.creditRolesByID == ["a": "Self - Guest", "b": "Jeff Daniels"])
    }

    // Cameron Diaz on The Tonight Show: TMDB credits the guest with no character, not "Self".
    @Test func aGuestSpotOnATalkShowNeedsNoSelfToReadAsAnAppearance() throws {
        let json = """
        {"id":1,"name":"Actor","popularity":9.0,"tv_credits":{
          "cast":[
            {"id":2518,"name":"Talk Show","character":"","credit_id":"a","episode_count":2,
             "genre_ids":[10767,35]},
            {"id":99,"name":"Drama","character":"","credit_id":"b","episode_count":2,
             "genre_ids":[18]}
          ],
          "crew":[]}}
        """
        let raw = try TMDBWrapper.decode(TMDBWrapper.PersonRaw.self, from: Data(json.utf8))
        let credits = raw.tvCredits()
        let talk = try #require(credits.first { $0.id == 2518 })
        #expect(talk.creditKinds == [.appearance])
        #expect(CreditFilter().hides(MediaRef.show(talk).creditKinds))
        // A drama's blank character is missing data, not an appearance.
        let drama = try #require(credits.first { $0.id == 99 })
        #expect(drama.creditKinds == [.acting])
    }

    // Harrison Ford on Entertainment Tonight: a second cast row with no character at all.
    @Test func tvCreditsIgnoreAnEmptyCharacterWhenRankingTheKind() throws {
        let json = """
        {"id":1,"name":"Actor","popularity":9.0,"tv_credits":{
          "cast":[
            {"id":1387,"name":"Show","character":"Self","credit_id":"a","episode_count":1},
            {"id":1387,"name":"Show","character":"","credit_id":"b","episode_count":1}
          ],
          "crew":[]}}
        """
        let raw = try TMDBWrapper.decode(TMDBWrapper.PersonRaw.self, from: Data(json.utf8))
        let credit = try #require(raw.tvCredits().first)
        #expect(credit.creditRole == "Self")
        #expect(credit.creditKind == .appearance)
    }

    @Test func translatePersonMapsFields() throws {
        let json = #"{"id":5,"name":"Nm","popularity":3.0,"biography":"Bio","place_of_birth":"NYC","profile_path":"/p.jpg"}"#
        let person = TMDBWrapper.translate(person: try TMDBWrapper.decode(TMDBWrapper.PersonRaw.self, from: Data(json.utf8)))
        #expect(person.id == 5)
        #expect(person.bio == "Bio")
        #expect(person.placeOfBirth == "NYC")
        #expect(person.profilePicture == "/p.jpg")
    }

    @Test func imageURLNilForNilPath() {
        #expect(TMDBWrapper.imageURL(path: nil, size: "w500") == nil)
        #expect(TMDBWrapper.imageURL(path: "/x.jpg", size: "w500")?.absoluteString
                == "https://image.tmdb.org/t/p/w500//x.jpg")
    }

    @Test func decodeThrowsFetchErrorOnGarbage() {
        #expect(throws: FetchError.self) {
            try TMDBWrapper.decode(TMDBWrapper.MovieRaw.self, from: Data("not json".utf8))
        }
    }
}
