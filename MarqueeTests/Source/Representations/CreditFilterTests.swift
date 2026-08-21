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
        let merged = CreditKind.merge([(.producing, "Producer", false, 0),
                                       (.writing, "Screenplay", false, 0),
                                       (.directing, "Director", false, 0)])
        #expect(merged.kind == .directing)
        #expect(merged.character == nil)
        #expect(merged.jobs == ["Director", "Screenplay", "Producer"])
    }

    @Test func tiesKeepTheOrderTheyArrivedIn() {
        let merged = CreditKind.merge([(.writing, "Story", false, 0),
                                       (.writing, "Screenplay", false, 0),
                                       (.writing, "Writer", false, 0)])
        #expect(merged.jobs == ["Story", "Screenplay", "Writer"])
    }

    @Test func aSingleRoleIsUnchanged() {
        let merged = CreditKind.merge([(.acting, "Cobb", true, 0)])
        #expect(merged.kind == .acting)
        #expect(merged.character == "Cobb")
        #expect(merged.jobs.isEmpty)
    }

    @Test func repeatedRolesAreListedOnce() {
        let merged = CreditKind.merge([(.producing, "Producer", false, 0),
                                       (.producing, "Producer", false, 0)])
        #expect(merged.jobs == ["Producer"])
    }

    @Test func rolelessCreditsCollapseToNothing() {
        #expect(CreditKind.merge([]).character == nil)
        let empty = CreditKind.merge([(.crew, nil, false, 0), (.crew, "", false, 0)])
        #expect(empty.character == nil)
        #expect(empty.jobs.isEmpty)
    }

    @Test func actingAndCrewWorkSplitIntoTwoLines() {
        let merged = CreditKind.merge([(.directing, "Director", false, 0), (.acting, "Hal", true, 0)])
        #expect(merged.kind == .acting)
        #expect(merged.character == "Hal")
        #expect(merged.jobs == ["Director"])
        // Both kinds are kept, so hiding acting leaves the directing credit standing.
        #expect(merged.kinds == [.acting, .directing])
    }

    // The blank cast row TMDB repeats a "Self" credit with must not turn an appearance into acting.
    @Test func aBlankCharacterAddsNoKind() {
        let merged = CreditKind.merge([(.acting, "", true, 0), (.appearance, "Self", true, 0)])
        #expect(merged.kind == .appearance)
        #expect(merged.kinds == [.appearance])
    }

    @Test func rolelessCreditsStillCarryTheirKind() {
        #expect(CreditKind.merge([(.crew, nil, false, 0)]).kinds == [.crew])
        #expect(CreditKind.merge([]).kinds.isEmpty)
    }

    @Test func severalCharactersJoinOneLine() {
        let merged = CreditKind.merge([(.acting, "Sam", true, 0), (.acting, "Dean", true, 0)])
        #expect(merged.character == "Sam, Dean")
    }

    // Cameron Diaz on SNL: she hosted four times, and the one uncredited sketch part is not what
    // the title was for her.
    @Test func hostingSpeaksForTheTitleOverASketchPart() {
        let merged = CreditKind.merge([(.acting, "Kiki D'Amore (uncredited)", true, 1),
                                       (.appearance, "Self - Cameo (uncredited)", true, 1),
                                       (.hosting, "Self - Host", true, 4),
                                       (.appearance, "Self (uncredited)", true, 3)],
                                      unscripted: true)
        #expect(merged.character == "Host")
        #expect(merged.kind == .hosting)
        // Only the credit that speaks for the title carries a kind, so turning Hosting off takes it
        // rather than the sketch part holding it on screen.
        #expect(!CreditFilter().hides(merged.kinds))
        #expect(CreditFilter(hidden: [.hosting]).hides(merged.kinds))
    }

    // Kate McKinnon on SNL: 211 episodes in the repertory, and one night back as host.
    @Test func aRunInTheRepertoryOutranksOneNightHosting() {
        let merged = CreditKind.merge([(.acting, "Self - Various Characters", true, 211),
                                       (.hosting, "Self - Host", true, 1),
                                       (.appearance, "Self - Cameo (uncredited)", true, 1)],
                                      unscripted: true)
        #expect(merged.character == "Cast")
        #expect(merged.kinds == [.acting])
    }

    // Bill Hader wrote for the show as well as performing on it, and that is separate work.
    @Test func crewWorkSurvivesAlongsideTheLeadingCastCredit() {
        let merged = CreditKind.merge([(.acting, "Self - Various Characters", true, 160),
                                       (.hosting, "Self - Host", true, 2),
                                       (.writing, "Writer", false, 0)],
                                      unscripted: true)
        #expect(merged.character == "Cast")
        #expect(merged.kinds == [.acting, .writing])
        #expect(merged.jobs == ["Writer"])
    }

    @Test func uncreditedRolesStandInWhenTheyAreAllThereIs() {
        let merged = CreditKind.merge([(.acting, "Waitress (uncredited)", true, 0),
                                       (.acting, "Diner (uncredited)", true, 0)])
        #expect(merged.character == "Waitress (uncredited), Diner (uncredited)")
    }

    // Jason Segel on The Late Show: with no part played anywhere on the title, the "Self" row is
    // the one about him and the stray guest name is dropped rather than led with.
    @Test func aStrayNameCannotSpeakForATitleWithNoPartOnIt() {
        let merged = CreditKind.merge([(.appearance, "Jeff Daniels", true, 0),
                                       (.appearance, "Self - Guest", true, 0)])
        #expect(merged.character == "Guest")
        #expect(merged.kinds == [.appearance])
    }

    // Nothing says "Self", so there is nothing to prefer and the roles stand as written.
    @Test func appearancesWithoutASelfRowKeepTheirRoles() {
        let merged = CreditKind.merge([(.appearance, "Special Thanks", false, 0)])
        #expect(merged.jobs == ["Special Thanks"])
    }

    @Test func aSelfCreditReadsAsWhatTheyDidThere() {
        #expect(CreditKind.merge([(.appearance, "Self - Musical Guest", true, 0)]).character
            == "Musical Guest")
        // Nothing follows the dash to promote, so the role stands as TMDB wrote it.
        #expect(CreditKind.merge([(.appearance, "Self", true, 0)]).character == "Self")
        // A bare "Self" beside a named function is dropped, not joined to it.
        #expect(CreditKind.merge([(.appearance, "Self", true, 0),
                                  (.appearance, "Self - Guest", true, 0)]).character == "Guest")
        #expect(CreditKind.merge([(.acting, "Selfish Man", true, 0)]).character == "Selfish Man")
    }
}

/// The function TMDB writes after "Self" is the job, not the word "Self".
@Suite struct SelfFunctionCreditTests {

    // TMDB writes an appearance as "Self" on one title and "Himself" on the next.
    @Test func everyWayOfSayingSelfCountsAsSelf() {
        for role in ["Self", "Himself", "Herself", "Themselves", "himself", "Selft"] {
            #expect(CreditKind.isExtraneous(role), "\(role) should read as an appearance")
            #expect(CreditKind.resolve(isCast: true, role: role, department: nil) == .appearance)
        }
        // Whole word only: these are parts someone played.
        for role in ["Selfish Man", "Idealist", "Shelf Stacker"] {
            #expect(!CreditKind.isExtraneous(role))
            #expect(CreditKind.resolve(isCast: true, role: role, department: nil) == .acting)
        }
    }

    // The function still carries, whichever pronoun TMDB used before the dash.
    @Test func aFunctionAfterAnyPronounStillReads() {
        #expect(CreditKind.resolve(isCast: true, role: "Himself - Host", department: nil) == .hosting)
        #expect(CreditKind.resolve(isCast: true, role: "Herself - Various Characters",
                                   department: nil) == .acting)
        #expect(CreditKind.merge([(.hosting, "Himself - Host", true, 3)]).character == "Host")
        #expect(CreditKind.merge([(.appearance, "Himself", true, 1)],
                                 unscripted: true).character == "Guest")
    }

    @Test func runningTheShowIsHosting() {
        #expect(CreditKind.resolve(isCast: true, role: "Self - Host", department: nil,
                                   format: .unscripted) == .hosting)
        #expect(CreditKind.resolve(isCast: true, role: "Self - Guest Host", department: nil,
                                   format: .talk) == .hosting)
        // An awards night files the job without the "Self".
        #expect(CreditKind.resolve(isCast: true, role: "Host", department: nil) == .hosting)
    }

    // Kenan Thompson's 464 episodes of Saturday Night Live, which TMDB writes with a "Self" prefix.
    @Test func playingTheSketchesIsActing() {
        for role in ["Self - Various Characters", "Various Characters", "Various", "Cast"] {
            #expect(CreditKind.resolve(isCast: true, role: role, department: nil,
                                       format: .unscripted) == .acting)
        }
    }

    // A cast member's body of work must survive the filter that hides appearances.
    @Test func aCastCreditIsNotHiddenByDefault() {
        let merged = CreditKind.merge([(.acting, "Self - Various Characters", true, 0)],
                                      unscripted: true)
        #expect(merged.character == "Cast")
        #expect(!CreditFilter().hides(merged.kinds))
    }

    // Visiting is not running or performing, whatever the function is called.
    @Test func everyOtherFunctionIsStillAnAppearance() {
        for role in ["Self - Guest", "Self - Musical Guest", "Self - Top Ten Presenter",
                     "Self - Panelist", "Self - Narrator", "Self"] {
            #expect(CreditKind.resolve(isCast: true, role: role, department: nil,
                                       format: .talk) == .appearance)
        }
    }

    // TMDB writes a guest spot as a bare "Self" on some shows and "Self - Guest" on others, so the
    // same visit read two ways across a filmography.
    @Test func aGuestSpotReadsTheSameWhicheverWayTMDBWroteIt() {
        #expect(CreditKind.merge([(.appearance, "Self", true, 0)], unscripted: true).character
            == "Guest")
        #expect(CreditKind.merge([(.appearance, "Self - Guest", true, 0)], unscripted: true).character
            == "Guest")
        // No character at all still describes a visit.
        #expect(CreditKind.merge([(.appearance, "", true, 0)], unscripted: true).character == "Guest")
        // A scripted title has no guests, so a bare "Self" stands as written.
        #expect(CreditKind.merge([(.appearance, "Self", true, 0)]).character == "Self")
    }
}

/// Whether a cast credit can name a part at all, which the show's genre decides.
@Suite struct UnscriptedCreditTests {

    @Test func talkIsSeparatedFromNewsAndReality() {
        #expect(CreditFormat(genreIDs: [10767, 35]) == .talk)
        #expect(CreditFormat(genreIDs: [10763]) == .unscripted)
        #expect(CreditFormat(genreIDs: [10764]) == .unscripted)
        // Saturday Night Live, which TMDB files under news beside comedy.
        #expect(CreditFormat(genreIDs: [35, 10763]) == .unscripted)
        #expect(CreditFormat(genreIDs: [35, 18]) == .scripted)
        #expect(CreditFormat(genreIDs: []) == .scripted)
        #expect(CreditFormat(genreIDs: nil) == .scripted)
    }

    // The Tonight Show credits its guests with an empty character rather than "Self".
    @Test func aCharacterlessCastCreditOnAnUnscriptedShowIsAnAppearance() {
        for format in [CreditFormat.talk, .unscripted] {
            #expect(CreditKind.resolve(isCast: true, role: "", department: nil,
                                       format: format) == .appearance)
            #expect(CreditKind.resolve(isCast: true, role: nil, department: nil,
                                       format: format) == .appearance)
        }
    }

    // Jason Segel on The Late Show: TMDB filed another guest's name as his character. A talk show
    // has no parts, so the name can't make it acting.
    @Test func aNamedCastCreditOnATalkShowIsStillAnAppearance() {
        #expect(CreditKind.resolve(isCast: true, role: "Jeff Daniels", department: nil,
                                   format: .talk) == .appearance)
    }

    // A sketch on Saturday Night Live is a part someone played.
    @Test func aNamedPartOnANewsOrRealityShowIsActing() {
        #expect(CreditKind.resolve(isCast: true, role: "Kiki D'Amore", department: nil,
                                   format: .unscripted) == .acting)
    }

    @Test func aCharacterlessCastCreditOnADramaIsStillActing() {
        #expect(CreditKind.resolve(isCast: true, role: "", department: nil) == .acting)
    }

    // Crew work is crew wherever it lands; the rule speaks only to cast credits.
    @Test func crewOnAnUnscriptedShowKeepsItsDepartment() {
        #expect(CreditKind.resolve(isCast: false, role: nil, department: "Directing",
                                   format: .talk) == .directing)
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
