//
//  EpisodeCreditTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct EpisodeCreditTests {
    private func season(_ number: Int, episodes: Int, name: String? = nil) -> Season {
        Season(id: 100 + number, seasonNumber: number,
               name: name ?? "Season \(number)", episodeCount: episodes)
    }

    /// A season TMDB named only through its episodes, so its count is unknown.
    private func unsized(_ number: Int) -> Season {
        Season(id: -(number + 1), seasonNumber: number, name: "Season \(number)")
    }

    // MARK: - Summary

    @Test func singleEpisodeNamesIt() {
        let credit = EpisodeCredit(seasons: [
            .init(season: season(7, episodes: 8), episodeNumbers: [5]),
        ])
        #expect(credit.summary == .episode(season: 7, number: 5))
        #expect(credit.summary?.label == "S7 · E5")
        #expect(!credit.needsEpisodeList)
    }

    @Test func wholeSeasonNamesTheSeason() {
        let credit = EpisodeCredit(seasons: [.init(season: season(1, episodes: 13))])
        #expect(credit.summary == .season(season(1, episodes: 13)))
        #expect(credit.summary?.label == "Season 1 • 13 Episodes")
        #expect(credit.total == 13)
        #expect(!credit.needsEpisodeList)
    }

    /// Every episode listed individually still reads as the season.
    @Test func everyEpisodeListedNamesTheSeason() {
        let credit = EpisodeCredit(seasons: [
            .init(season: season(2, episodes: 3), episodeNumbers: [1, 2, 3]),
        ])
        #expect(credit.summary == .season(season(2, episodes: 3)))
    }

    @Test func severalEpisodesInOneSeasonSpread() {
        let credit = EpisodeCredit(seasons: [
            .init(season: season(2, episodes: 24), episodeNumbers: [1, 5, 9]),
        ])
        #expect(credit.summary == .spread(3))
        #expect(credit.summary?.label == "3 Episodes")
        #expect(credit.needsEpisodeList)
    }

    @Test func episodesAcrossSeasonsSpread() {
        let credit = EpisodeCredit(seasons: [
            .init(season: season(3, episodes: 20), episodeNumbers: [13]),
            .init(season: season(13, episodes: 150), episodeNumbers: [110]),
        ])
        #expect(credit.summary == .spread(2))
        #expect(credit.needsEpisodeList)
    }

    /// A season stood up from its episodes has no count, so one episode must not read
    /// as the whole run.
    @Test func unsizedSeasonWithOneEpisodeNamesTheEpisode() {
        let credit = EpisodeCredit(seasons: [.init(season: unsized(1), episodeNumbers: [4])])
        #expect(credit.summary == .episode(season: 1, number: 4))
    }

    @Test func specialsAreDroppedBesideRegularSeasons() {
        let credit = EpisodeCredit(seasons: [
            .init(season: season(0, episodes: 1, name: "Specials")),
            .init(season: season(1, episodes: 13)),
        ])
        #expect(credit.summary == .season(season(1, episodes: 13)))
        #expect(credit.total == 13)
    }

    @Test func specialsStandAloneWhenThatIsTheWholeCredit() {
        let credit = EpisodeCredit(seasons: [
            .init(season: season(0, episodes: 4, name: "Specials"), episodeNumbers: [2]),
        ])
        #expect(credit.summary == .episode(season: 0, number: 2))
    }

    @Test func emptyCreditHasNoSummary() {
        #expect(EpisodeCredit(seasons: []).summary == nil)
    }

    // MARK: - Merging

    @Test func mergingUnionsEpisodesPerSeason() {
        let merged = EpisodeCredit.merging([
            EpisodeCredit(seasons: [.init(season: season(1, episodes: 10), episodeNumbers: [1, 2])]),
            EpisodeCredit(seasons: [.init(season: season(1, episodes: 10), episodeNumbers: [2, 7])]),
        ])
        #expect(merged?.seasons.first?.episodeNumbers == [1, 2, 7])
        #expect(merged?.summary == .spread(3))
    }

    /// Cast for the whole run and crew on one episode still means the whole run.
    @Test func mergingLetsWholeSeasonWin() {
        let merged = EpisodeCredit.merging([
            EpisodeCredit(seasons: [.init(season: season(1, episodes: 10), episodeNumbers: [4])]),
            EpisodeCredit(seasons: [.init(season: season(1, episodes: 10))]),
        ])
        #expect(merged?.summary == .season(season(1, episodes: 10)))
    }

    @Test func mergingOrdersSeasonsAndKeepsNothingFromNothing() {
        let merged = EpisodeCredit.merging([
            EpisodeCredit(seasons: [.init(season: season(3, episodes: 8))]),
            EpisodeCredit(seasons: [.init(season: season(1, episodes: 8))]),
        ])
        #expect(merged?.seasons.map(\.season.seasonNumber) == [1, 3])
        #expect(EpisodeCredit.merging([]) == nil)
    }

    // MARK: - Decoding

    @Test func decodesListedEpisodesWithoutSeasonObjects() throws {
        let json = """
        {"media": {"episodes": [
            {"id": 1, "name": "Ep", "season_number": 1, "episode_number": 4}
        ]}}
        """
        let raw = try JSONDecoder().decode(TMDBWrapper.CreditRaw.self, from: Data(json.utf8))
        #expect(raw.credit().summary == .episode(season: 1, number: 4))
    }

    /// No episodes named means the whole run of every season listed.
    @Test func decodesSeasonsWithNoEpisodesAsWholeRun() throws {
        let json = """
        {"media": {"episodes": [], "seasons": [
            {"id": 61056, "name": "Season 1", "season_number": 1, "episode_count": 13},
            {"id": 61057, "name": "Specials", "season_number": 0, "episode_count": 1}
        ]}}
        """
        let raw = try JSONDecoder().decode(TMDBWrapper.CreditRaw.self, from: Data(json.utf8))
        let credit = raw.credit()
        #expect(credit.seasons.count == 2)
        #expect(credit.summary?.label == "Season 1 • 13 Episodes")   // specials dropped
    }

    /// A guest spot: TMDB names the episode and the season holding it, and the episode wins.
    @Test func decodingKeepsAGuestSpotToItsEpisode() throws {
        let json = """
        {"media": {
            "episodes": [{"id": 1, "name": "Ep", "season_number": 7, "episode_number": 5}],
            "seasons": [{"id": 10, "name": "Season 7", "season_number": 7, "episode_count": 8}]
        }}
        """
        let raw = try JSONDecoder().decode(TMDBWrapper.CreditRaw.self, from: Data(json.utf8))
        let credit = raw.credit()
        #expect(credit.seasons.map(\.season.seasonNumber) == [7])
        #expect(credit.summary == .episode(season: 7, number: 5))
    }

    /// A regular who also has specials named comes back as both shapes at once (Zendaya on
    /// Euphoria): the named episodes are that season's credit, the rest are whole runs.
    @Test func decodingReadsNamedEpisodesBesideWholeSeasons() throws {
        let json = """
        {"media": {
            "episodes": [
                {"id": 1, "name": "A", "season_number": 0, "episode_number": 1},
                {"id": 2, "name": "B", "season_number": 0, "episode_number": 2}
            ],
            "seasons": [
                {"id": 10, "name": "Specials", "season_number": 0, "episode_count": 2},
                {"id": 11, "name": "Season 1", "season_number": 1, "episode_count": 8},
                {"id": 12, "name": "Season 2", "season_number": 2, "episode_count": 8}
            ]
        }}
        """
        let raw = try JSONDecoder().decode(TMDBWrapper.CreditRaw.self, from: Data(json.utf8))
        let credit = raw.credit()
        #expect(credit.seasons.map(\.season.seasonNumber) == [0, 1, 2])
        #expect(credit.seasons[0].episodeNumbers == [1, 2])
        #expect(credit.seasons[1].isWhole)
        // Specials drop out beside regular seasons, leaving the run TMDB itself counts.
        #expect(credit.total == 16)
    }

    @Test func decodesEmptyMediaAsNoCredit() throws {
        let raw = try JSONDecoder().decode(TMDBWrapper.CreditRaw.self, from: Data("{}".utf8))
        #expect(raw.credit().summary == nil)
    }

    // MARK: - Fallback text

    @Test func declaredCountLabelPluralizes() {
        #expect(EpisodeCredit.episodeCountLabel(1) == "1 Episode")
        #expect(EpisodeCredit.episodeCountLabel(12) == "12 Episodes")
    }
}
