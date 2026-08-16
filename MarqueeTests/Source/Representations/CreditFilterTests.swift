//
//  CreditFilterTests.swift
//  MarqueeTests
//
//  The filmography filter: what a tap toggles, what the checklist edits, and how the whole
//  thing survives a round trip through `@AppStorage`.
//

import Testing
import Foundation
@testable import Marquee

@Suite struct CreditFilterTests {

    // MARK: - Defaults

    /// An untouched filter behaves as the old Self/Thanks toggle did.
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

    /// The filter can be on with nothing selected — that's a filter hiding nothing, not an
    /// invalid state, and it survives storage.
    @Test func anEmptySelectionIsAllowed() {
        var filter = CreditFilter()
        filter.setHidden(false, for: .appearance)
        #expect(filter.hidden.isEmpty)
        #expect(filter.isOn)
        #expect(filter.active.isEmpty)
        #expect(CreditFilter(rawValue: filter.rawValue) == filter)
    }

    @Test func showingAKindThatIsAlreadyShownChangesNothing() {
        var filter = CreditFilter()
        filter.setHidden(false, for: .producing)
        #expect(filter.hidden == [.appearance])
        #expect(filter.isOn)
    }

    // MARK: - Storage

    @Test func rawValueRoundTrips() {
        for filter in [CreditFilter(),
                       CreditFilter(hidden: [.directing, .writing]),
                       CreditFilter(hidden: [.crew], isOn: false)] {
            #expect(CreditFilter(rawValue: filter.rawValue) == filter)
        }
    }

    /// Sorted, so the same selection always stores the same string.
    @Test func rawValueIsStableRegardlessOfInsertionOrder() {
        #expect(CreditFilter(hidden: [.writing, .directing]).rawValue
                == CreditFilter(hidden: [.directing, .writing]).rawValue)
    }

    /// Storage that isn't in the "flag|kinds" shape at all is rejected, so `@AppStorage` falls
    /// back to the default rather than seeding something nonsensical.
    @Test func malformedStorageIsRejected() {
        for raw in ["", "on", "directing"] {
            #expect(CreditFilter(rawValue: raw) == nil, "\(raw) should not decode")
        }
    }

    /// Anything but "on" in the flag reads as off — the only writer is `rawValue`.
    @Test func anUnrecognizedFlagReadsAsOff() {
        #expect(CreditFilter(rawValue: "|directing")?.isOn == false)
    }

    /// A kind dropped from a future build shouldn't take the rest of the selection with it.
    @Test func unknownKindsAreSkipped() {
        let filter = CreditFilter(rawValue: "on|directing,dancing")
        #expect(filter?.active == [.directing])
    }
}

/// Collapsing the several jobs TMDB lists a person under on one title into a single credit.
@Suite struct CreditMergeTests {

    @Test func everyRoleIsListedMostProminentFirst() {
        let merged = CreditKind.merge([(.producing, "Producer"),
                                       (.writing, "Screenplay"),
                                       (.directing, "Director")])
        #expect(merged.kind == .directing)
        #expect(merged.role == "Director, Screenplay, Producer")
    }

    /// Equal-ranking jobs keep TMDB's own order rather than being re-sorted.
    @Test func tiesKeepTheOrderTheyArrivedIn() {
        let merged = CreditKind.merge([(.writing, "Story"),
                                       (.writing, "Screenplay"),
                                       (.writing, "Writer")])
        #expect(merged.role == "Story, Screenplay, Writer")
    }

    @Test func aSingleRoleIsUnchanged() {
        let merged = CreditKind.merge([(.acting, "Cobb")])
        #expect(merged.kind == .acting)
        #expect(merged.role == "Cobb")
    }

    @Test func repeatedRolesAreListedOnce() {
        let merged = CreditKind.merge([(.producing, "Producer"), (.producing, "Producer")])
        #expect(merged.role == "Producer")
    }

    @Test func rolelessCreditsCollapseToNothing() {
        #expect(CreditKind.merge([]).role == nil)
        #expect(CreditKind.merge([(.crew, nil), (.crew, "")]).role == nil)
    }

    /// An acting credit alongside crew work still files under the higher-ranking kind, so the
    /// filmography's ordering and filtering are unchanged by listing the extra roles.
    @Test func theTopRankingKindStillDecidesFiling() {
        let merged = CreditKind.merge([(.acting, "Bartender"), (.directing, "Director")])
        #expect(merged.kind == .directing)
        #expect(merged.role == "Director, Bartender")
    }
}
