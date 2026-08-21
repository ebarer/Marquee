//
//  CreditFilterTests.swift
//  MarqueeTests
//
//  The filmography filter: what a tap toggles, what the checklist edits, and which titles a
//  hidden kind takes with it.
//

import Testing
import Foundation
@testable import Marquee

@Suite struct CreditFilterTests {

    // MARK: - Defaults

    @Test func defaultsToHidingSelfAndThanks() {
        let filter = CreditFilter()
        #expect(filter.isOn)
        #expect(filter.active == [.appearance])
        #expect(filter.hides(.appearance))
        #expect(!filter.hides(.producing))
    }

    @Test func offHidesNothingButRemembersTheSelection() {
        var filter = CreditFilter(hidden: [.producing, .crew])
        filter.isOn = false
        #expect(filter.active.isEmpty)
        #expect(!filter.hides(.producing))
        // A tap brings the same selection back rather than starting over.
        filter.isOn = true
        #expect(filter.active == [.producing, .crew])
    }

    // MARK: - Editing the checklist
    //
    // The switch and the selection are independent: editing the checklist never flips the
    // switch, so the menu can show the stored preference whatever the filter is doing.

    @Test func hidingAKindAddsItToTheSelection() {
        var filter = CreditFilter()
        filter.setHidden(true, for: .crew)
        #expect(filter.hidden == [.appearance, .crew])
        #expect(filter.active == [.appearance, .crew])
    }

    @Test func showingAKindDropsItButLeavesTheRest() {
        var filter = CreditFilter(hidden: [.appearance, .crew])
        filter.setHidden(false, for: .crew)
        #expect(filter.hidden == [.appearance])
    }

    @Test func editingWhileOffRecordsThePreferenceWithoutApplyingIt() {
        var filter = CreditFilter(hidden: [.appearance], isOn: false)
        filter.setHidden(true, for: .producing)
        #expect(!filter.isOn, "editing the checklist must not switch the filter on")
        #expect(filter.hidden == [.appearance, .producing])
        #expect(filter.active.isEmpty)
        // Enabling then applies exactly what the checklist showed.
        filter.isOn = true
        #expect(filter.active == [.appearance, .producing])
    }

    @Test func anEmptySelectionIsAllowed() {
        var filter = CreditFilter()
        filter.setHidden(false, for: .appearance)
        #expect(filter.hidden.isEmpty)
        #expect(filter.isOn)
        #expect(filter.active.isEmpty)
    }

    @Test func showingAKindThatIsAlreadyShownChangesNothing() {
        var filter = CreditFilter()
        filter.setHidden(false, for: .producing)
        #expect(filter.hidden == [.appearance])
        #expect(filter.isOn)
    }

    // MARK: - Never hiding everything
    //
    // A filter that hides every kind a person has would take the section, and the control that
    // undoes it, off screen.

    @Test func hidingEveryKindPresentStandsTheFilterDown() {
        let filter = CreditFilter(hidden: [.acting, .appearance])
        let resolved = filter.resolved(for: [.acting, .appearance])
        #expect(!resolved.isOn)
        #expect(!resolved.hides(.acting))
        // The stored selection is untouched, so the menu still shows what was chosen.
        #expect(resolved.hidden == [.acting, .appearance])
    }

    @Test func aKindLeftShowingKeepsTheFilterOn() {
        let filter = CreditFilter(hidden: [.appearance])
        let resolved = filter.resolved(for: [.acting, .appearance])
        #expect(resolved.isOn)
        #expect(resolved.hides(.appearance))
    }

    // The default filter hides `.appearance`, so a person with nothing else would vanish.
    @Test func aPersonWithOnlySelfCreditsStillShows() {
        #expect(!CreditFilter().resolved(for: [.appearance]).hides(.appearance))
    }

    @Test func theLastKindShowingIsPinned() {
        let filter = CreditFilter(hidden: [.appearance, .crew])
        let kinds: [CreditKind] = [.acting, .crew, .appearance]
        #expect(filter.isLastShown(.acting, in: kinds))
        #expect(!filter.isLastShown(.crew, in: kinds))
        // Nothing is pinned while two or more are showing.
        #expect(!CreditFilter(hidden: []).isLastShown(.acting, in: kinds))
    }

    // MARK: - A title held under several kinds
    //
    // Hiding one kind must not take a title the person also worked on in another.

    @Test func aTitleShowsWhileAnyOfItsKindsIsShown() {
        let filter = CreditFilter(hidden: [.acting])
        #expect(filter.hides([.acting]))
        #expect(!filter.hides([.acting, .directing]))
    }

    @Test func aTitleIsHiddenOnlyWhenEveryKindOnItIsHidden() {
        let filter = CreditFilter(hidden: [.acting, .producing])
        #expect(filter.hides([.acting, .producing]))
        #expect(!filter.hides([.acting, .producing, .writing]))
    }

    @Test func aTitleWithNoKindsAtAllStaysVisible() {
        #expect(!CreditFilter(hidden: Set(CreditKind.allCases)).hides([]))
    }
}

/// The set of kinds a filmography row carries, which is what the filter is applied to.
@Suite struct CreditKindsTests {

    @Test func aDirectorWhoAlsoActedCarriesBothKinds() {
        var movie = Movie(id: 1, title: "Charlie's Angels")
        movie.creditKind = .acting
        movie.creditKinds = [.acting, .directing, .writing, .producing]
        #expect(MediaRef.movie(movie).creditKinds.contains(.directing))
        #expect(!CreditFilter(hidden: [.acting]).hides(MediaRef.movie(movie).creditKinds))
    }

    // Credits decoded before the set existed carry only the single kind.
    @Test func aCreditWithoutTheSetFallsBackToItsOneKind() {
        var show = Show(id: 2, name: "Press Your Luck")
        show.creditKind = .appearance
        #expect(MediaRef.show(show).creditKinds == [.appearance])
        #expect(CreditFilter().hides(MediaRef.show(show).creditKinds))
    }

    @Test func aCreditWithNoKindAtAllReadsAsCrew() {
        #expect(MediaRef.movie(Movie(id: 3, title: "Untitled")).creditKinds == [.crew])
    }

    @Test func everyKindOnAnyTitleIsOffered() {
        var acted = Movie(id: 4, title: "Acted")
        acted.creditKind = .acting
        acted.creditKinds = [.acting]
        var both = Movie(id: 5, title: "Both")
        both.creditKind = .acting
        both.creditKinds = [.acting, .directing]
        #expect(CreditKind.present(in: [.movie(acted), .movie(both)]) == [.acting, .directing])
    }
}

/// Collapsing the several jobs TMDB lists a person under on one title into a single credit.
@Suite struct CreditMergeTests {

    @Test func everyJobIsListedMostProminentFirst() {
        let merged = CreditKind.merge([(.producing, "Producer", false),
                                       (.writing, "Screenplay", false),
                                       (.directing, "Director", false)])
        #expect(merged.kind == .directing)
        #expect(merged.character == nil)
        #expect(merged.jobs == ["Director", "Screenplay", "Producer"])
    }

    @Test func tiesKeepTheOrderTheyArrivedIn() {
        let merged = CreditKind.merge([(.writing, "Story", false),
                                       (.writing, "Screenplay", false),
                                       (.writing, "Writer", false)])
        #expect(merged.jobs == ["Story", "Screenplay", "Writer"])
    }

    @Test func aSingleRoleIsUnchanged() {
        let merged = CreditKind.merge([(.acting, "Cobb", true)])
        #expect(merged.kind == .acting)
        #expect(merged.character == "Cobb")
        #expect(merged.jobs.isEmpty)
    }

    @Test func repeatedRolesAreListedOnce() {
        let merged = CreditKind.merge([(.producing, "Producer", false),
                                       (.producing, "Producer", false)])
        #expect(merged.jobs == ["Producer"])
    }

    @Test func rolelessCreditsCollapseToNothing() {
        #expect(CreditKind.merge([]).character == nil)
        let empty = CreditKind.merge([(.crew, nil, false), (.crew, "", false)])
        #expect(empty.character == nil)
        #expect(empty.jobs.isEmpty)
    }

    @Test func actingAndCrewWorkSplitIntoTwoLines() {
        let merged = CreditKind.merge([(.directing, "Director", false), (.acting, "Hal", true)])
        #expect(merged.kind == .acting)
        #expect(merged.character == "Hal")
        #expect(merged.jobs == ["Director"])
        // Both kinds are kept, so hiding acting leaves the directing credit standing.
        #expect(merged.kinds == [.acting, .directing])
    }

    // The blank cast row TMDB repeats a "Self" credit with must not turn an appearance into acting.
    @Test func aBlankCharacterAddsNoKind() {
        let merged = CreditKind.merge([(.acting, "", true), (.appearance, "Self", true)])
        #expect(merged.kind == .appearance)
        #expect(merged.kinds == [.appearance])
    }

    @Test func rolelessCreditsStillCarryTheirKind() {
        #expect(CreditKind.merge([(.crew, nil, false)]).kinds == [.crew])
        #expect(CreditKind.merge([]).kinds.isEmpty)
    }

    @Test func severalCharactersJoinOneLine() {
        let merged = CreditKind.merge([(.acting, "Sam", true), (.acting, "Dean", true)])
        #expect(merged.character == "Sam, Dean")
    }
}

/// Shortening the long job titles TMDB uses.
@Suite struct CreditJobTests {

    @Test func longTitlesAreAbbreviated() {
        #expect(CreditJob.short("Executive Producer") == "EP")
        #expect(CreditJob.short("Director of Photography") == "DP")
        #expect(CreditJob.short("Original Music Composer") == "Composer")
    }

    @Test func compoundTitlesKeepTheirPrefix() {
        #expect(CreditJob.short("Co-Executive Producer") == "Co-EP")
    }

    @Test func otherTitlesAreLeftAlone() {
        #expect(CreditJob.short("Director") == "Director")
        #expect(CreditJob.short("Screenplay") == "Screenplay")
    }

    @Test func theLineJoinsEveryJob() {
        #expect(CreditJob.line(["Writer", "Executive Producer"]) == "Writer, EP")
        #expect(CreditJob.line([]) == nil)
    }
}
