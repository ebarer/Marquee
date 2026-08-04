//
//  Region.swift
//  MovieTracker
//

import Foundation

enum Region {
    static var device: String { Locale.current.region?.identifier ?? "US" }

    /// Flag emoji for a two-letter ISO region code.
    static func flag(_ code: String) -> String {
        let base: UInt32 = 0x1F1E6
        var flag = ""
        for scalar in code.uppercased().unicodeScalars where (65...90).contains(scalar.value) {
            flag.unicodeScalars.append(UnicodeScalar(base + scalar.value - 65)!)
        }
        return flag.isEmpty ? "🏳️" : flag
    }

    static func name(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    /// Two-letter ISO regions, sorted by localized name.
    static var all: [String] {
        Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 }
            .sorted { name($0).localizedCaseInsensitiveCompare(name($1)) == .orderedAscending }
    }
}
