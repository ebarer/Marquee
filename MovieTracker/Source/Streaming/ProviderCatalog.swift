//
//  ProviderCatalog.swift
//  MovieTracker
//

import Foundation

struct ProviderGroup: Identifiable {
    let representative: WatchProvider
    let name: String
    let memberIDs: Set<Int>

    var id: Int { representative.id }

    func logoURL(size: String = "w92") -> URL? { representative.logoURL(size: size) }
    var appURL: URL? { ProviderLinks.appURL(for: representative.id) }
}

enum ProviderCatalog {
    static func grouped(_ providers: [WatchProvider]) -> [ProviderGroup] {
        var order: [String] = []
        var members: [String: [WatchProvider]] = [:]
        for provider in providers where !purchaseOnly.contains(provider.id) {
            let key = canonicalKey(provider.name)
            if members[key] == nil { order.append(key) }
            members[key, default: []].append(provider)
        }
        return order.map { key in
            let group = members[key]!
            let rep = group.first { $0.id == preferred[key] } ?? group[0]
            return ProviderGroup(representative: rep,
                                 name: nameOverrides[rep.id] ?? displayName(rep.name),
                                 memberIDs: Set(group.map(\.id)))
        }
    }

    static func canonicalKey(_ name: String) -> String {
        var value = name.lowercased().replacingOccurrences(of: "+", with: " plus ")
        for qualifier in qualifiers {
            value = value.replacingOccurrences(of: qualifier, with: " ")
        }
        // Word-safe so "free" collapses ad-tiers without mangling "Freevee".
        let key = value.split(separator: " ")
            .map(String.init)
            .filter { !stopwords.contains($0) }
            .joined(separator: " ")
        return aliases[key] ?? key
    }

    private static let stopwords: Set<String> = ["free"]

    static func displayName(_ name: String) -> String {
        var value = name
        for tier in tierWords {
            value = value.replacingOccurrences(of: tier, with: "", options: .caseInsensitive)
        }
        return value.split(separator: " ").joined(separator: " ")
    }

    static let purchaseOnly: Set<Int> = [
        2,    // Apple TV (iTunes) store
        3,    // Google Play Movies
        7,    // Fandango At Home (Vudu)
        10,   // Amazon Video
        68,   // Microsoft Store
        130,  // Sky Store
        192,  // YouTube (rent/buy)
    ]

    private static let aliases = ["hbo max": "max"]

    private static let preferred = ["max": 1899]

    // Display names pinned regardless of TMDB's current wording.
    private static let nameOverrides = [350: "Apple TV+"]

    private static let qualifiers = tierWords + ["plus"]

    private static let tierWords = [
        "standard with ads", "basic with ads", "with ads",
        "amazon channel", "apple tv channel", "roku premium channel",
        "with showtime", "premium", "essential", "kids",
    ]
}
