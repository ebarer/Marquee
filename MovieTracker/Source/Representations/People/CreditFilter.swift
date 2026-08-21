//
//  CreditFilter.swift
//  MovieTracker
//

import Foundation
import Observation

/// Which kinds of credit a filmography hides, and whether it is hiding them at all.
struct CreditFilter: Equatable, Sendable {
    var hidden: Set<CreditKind>
    var isOn: Bool

    static let defaultHidden: Set<CreditKind> = [.appearance]

    init(hidden: Set<CreditKind> = defaultHidden, isOn: Bool = true) {
        self.hidden = hidden
        self.isOn = isOn
    }

    var active: Set<CreditKind> { isOn ? hidden : [] }

    func hides(_ kind: CreditKind) -> Bool { active.contains(kind) }

    /// A title survives while any one of its kinds is still shown: hiding acting doesn't take a
    /// film the person also directed.
    func hides(_ kinds: Set<CreditKind>) -> Bool {
        !kinds.isEmpty && kinds.allSatisfy(active.contains)
    }

    mutating func setHidden(_ hide: Bool, for kind: CreditKind) {
        if hide { hidden.insert(kind) } else { hidden.remove(kind) }
    }

    /// Stands down where it would hide every kind present, which would take the section and the
    /// control that undoes it off screen.
    func resolved(for kinds: [CreditKind]) -> CreditFilter {
        guard !kinds.isEmpty, kinds.allSatisfy(hides) else { return self }
        var filter = self
        filter.isOn = false
        return filter
    }

    /// True when `kind` is the only one left showing, so hiding it would leave nothing.
    func isLastShown(_ kind: CreditKind, in kinds: [CreditKind]) -> Bool {
        kinds.filter { !hidden.contains($0) } == [kind]
    }
}

// MARK: - Sharing

/// One person page's filter. A reference, since the search overlay is hosted above the page and has
/// to edit the same value; nothing is persisted, so every page opens at the default.
@Observable final class CreditFilterStore: Hashable {
    var filter: CreditFilter

    init(_ filter: CreditFilter = CreditFilter()) {
        self.filter = filter
    }

    static func == (lhs: CreditFilterStore, rhs: CreditFilterStore) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
