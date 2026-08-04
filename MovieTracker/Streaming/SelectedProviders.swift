//
//  SelectedProviders.swift
//  MovieTracker
//

import Foundation

/// The user's chosen services, persisted via `@AppStorage`. Empty means "not
/// configured" — the detail screen then shows every service.
struct SelectedProviders: RawRepresentable, Equatable {
    var ids: Set<Int>

    static let storageKey = "streamingServices"

    init(_ ids: Set<Int> = []) { self.ids = ids }

    init?(rawValue: String) {
        ids = Set(rawValue.split(separator: ",").compactMap { Int($0) })
    }

    var rawValue: String {
        ids.sorted().map(String.init).joined(separator: ",")
    }

    var isEmpty: Bool { ids.isEmpty }
    func contains(_ id: Int) -> Bool { ids.contains(id) }

    func isSelected(_ group: ProviderGroup) -> Bool {
        !ids.isDisjoint(with: group.memberIDs)
    }

    mutating func toggle(_ group: ProviderGroup) {
        if isSelected(group) {
            ids.subtract(group.memberIDs)
        } else {
            ids.formUnion(group.memberIDs)
        }
    }
}
