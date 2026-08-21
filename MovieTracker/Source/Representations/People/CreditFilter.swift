//
//  CreditFilter.swift
//  MovieTracker
//

import Foundation

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

// MARK: - Storage

/// Stored as "on|kind,kind" so `@AppStorage` can carry the whole filter under one key.
extension CreditFilter: RawRepresentable {
    var rawValue: String {
        (isOn ? "on" : "off") + "|" + hidden.map(\.rawValue).sorted().joined(separator: ",")
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        // An empty selection is legal: the filter can be on with nothing chosen.
        let kinds = parts[1].split(separator: ",").compactMap { CreditKind(rawValue: String($0)) }
        self.init(hidden: Set(kinds), isOn: parts[0] == "on")
    }
}
