//
//  AwardsDigestTests.swift
//  MarqueeTests
//
//  Grouping and the win/nomination collapse, offline.
//

import Testing
import Foundation
@testable import Marquee

@Suite struct AwardsDigestTests {
    private func award(_ category: String, series: String? = "Academy Awards",
                       year: Int? = 2011, isWin: Bool) -> Award {
        Award(category: category, series: series, year: year, isWin: isWin)
    }

    // Wikidata files a win under both "award received" and "nominated for". Counting both
    // would report every win twice, once as a loss.
    @Test func winAndNominationForSameCategoryCollapseToTheWin() {
        let digest = AwardsDigest(awards: [
            award("Academy Award for Best Sound", isWin: false),
            award("Academy Award for Best Sound", isWin: true),
        ])
        #expect(digest.wins == 1)
        #expect(digest.nominations == 0)
        #expect(digest.series.first?.awards.count == 1)
    }

    @Test func collapseIsOrderIndependent() {
        let digest = AwardsDigest(awards: [
            award("Academy Award for Best Sound", isWin: true),
            award("Academy Award for Best Sound", isWin: false),
        ])
        #expect(digest.wins == 1)
        #expect(digest.nominations == 0)
    }

    @Test func sameCategoryInDifferentYearsStaysSeparate() {
        let digest = AwardsDigest(awards: [
            award("Academy Award for Best Sound", year: 2011, isWin: true),
            award("Academy Award for Best Sound", year: 2012, isWin: false),
        ])
        #expect(digest.wins == 1)
        #expect(digest.nominations == 1)
    }

    @Test func seriesAreOrderedByHowManyAwardsTheyCarry() {
        let digest = AwardsDigest(awards: [
            award("Hugo Award for Best Dramatic Presentation", series: "Hugo Award", isWin: true),
            award("Academy Award for Best Sound", isWin: true),
            award("Academy Award for Best Picture", isWin: false),
        ])
        #expect(digest.series.map(\.name) == ["Academy Awards", "Hugo Award"])
    }

    @Test func winsSortAheadOfNominationsWithinAYear() {
        let digest = AwardsDigest(awards: [
            award("Academy Award for Best Picture", isWin: false),
            award("Academy Award for Best Sound", isWin: true),
        ])
        #expect(digest.series.first?.awards.map(\.isWin) == [true, false])
    }

    @Test func awardsWithNoSeriesLandInTheOtherBucket() {
        let digest = AwardsDigest(awards: [
            award("National Board of Review: Top Ten Films", series: nil, year: nil, isWin: true),
        ])
        #expect(digest.series.map(\.name) == [AwardsDigest.ungrouped])
    }

    @Test func categoryDropsTheSeriesPrefixTheHeaderAlreadyCarries() {
        #expect(award("Academy Award for Best Sound", isWin: true).shortCategory == "Best Sound")
        #expect(award("TCA Award for Program of the Year", isWin: true)
            .shortCategory == "Program of the Year")
    }

    /// A label with no " for " has nothing to strip and must survive whole.
    @Test func categoryWithoutAForClauseIsLeftAlone() {
        let category = "National Board of Review: Top Ten Films"
        #expect(award(category, series: nil, isWin: true).shortCategory == category)
    }

    @Test func summaryIsNilWhenThereIsNothingToShow() {
        #expect(AwardsDigest().summary == nil)
        #expect(AwardsDigest(awards: []).summary == nil)
    }

    @Test func summaryCountsBothOutcomesAndSingularises() {
        let both = AwardsDigest(awards: [
            award("Academy Award for Best Sound", isWin: true),
            award("Academy Award for Best Picture", isWin: false),
        ])
        #expect(both.summary == "1 Win &\n1 Nom")

        let winsOnly = AwardsDigest(awards: [
            award("Academy Award for Best Sound", isWin: true),
            award("Academy Award for Best Picture", isWin: true),
        ])
        #expect(winsOnly.summary == "2 Wins")
    }
}

@Suite struct ExternalLinkTests {
    @Test func imdbNeedsAnID() {
        #expect(ExternalLink.imdb(id: nil) == nil)
        #expect(ExternalLink.imdb(id: "") == nil)
        #expect(ExternalLink.imdb(id: "tt1375666")?.url.absoluteString
                == "https://www.imdb.com/title/tt1375666/")
    }

    @Test func rottenTomatoesUsesTheSlugWhenThereIsOne() {
        let link = ExternalLink.rottenTomatoes(slug: "m/inception", title: "Inception")
        #expect(link?.url.absoluteString == "https://www.rottentomatoes.com/m/inception")
        #expect(link?.isExact == true)
    }

    // Without a slug the link searches instead, rather than guessing a slug that 404s.
    @Test func rottenTomatoesFallsBackToSearch() {
        let link = ExternalLink.rottenTomatoes(slug: nil, title: "Some Obscure Film")
        #expect(link?.isExact == false)
        #expect(link?.url.absoluteString
                == "https://www.rottentomatoes.com/search?search=Some%20Obscure%20Film")
    }

    /// The menu shows these verbatim, so the brand casing lives here.
    @Test func siteNamesAreTheMenuLabels() {
        #expect(ExternalLink.Site.rottenTomatoes.rawValue == "Rotten Tomatoes")
        #expect(ExternalLink.Site.imdb.rawValue == "IMDb")
    }

    @Test func linksAreOrderedRottenTomatoesThenIMDb() {
        #expect(TitleExtras.preview.links.map(\.site) == [.rottenTomatoes, .imdb])
    }
}
