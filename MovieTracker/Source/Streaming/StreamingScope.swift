//
//  StreamingScope.swift
//  MovieTracker
//

import Foundation

/// Whether streaming availability is judged against the services the user turned on, or all of them.
enum StreamingScope: String, CaseIterable, Sendable {
    case mine
    case all

    var title: String {
        switch self {
        case .mine: return "My Services"
        case .all: return "All Services"
        }
    }

    // Carries the current scope on the Where to Watch control, so it reads at a glyph's size.
    var symbol: String {
        switch self {
        case .mine: return "person.fill"
        case .all: return "globe"
        }
    }
}

enum StreamingVerdict: Sendable {
    case available
    case offMyServices
    case unavailable

    var title: String {
        switch self {
        case .available: return "Available to Stream"
        case .offMyServices: return "Available on Other Services"
        case .unavailable: return "Unavailable to Stream"
        }
    }
}

struct StreamingResolution: Sendable {
    var groups: [ProviderGroup]
    var verdict: StreamingVerdict
}

enum StreamingAvailability {
    static func resolve(_ availability: WatchAvailability?, scope: StreamingScope,
                        selected: SelectedProviders) -> StreamingResolution {
        let groups = ProviderCatalog.grouped(availability?.providers ?? [])
        guard !groups.isEmpty else { return StreamingResolution(groups: [], verdict: .unavailable) }
        // An empty selection means "not configured", so every service counts as one of mine.
        guard !selected.isEmpty else {
            return StreamingResolution(groups: groups, verdict: .available)
        }
        let mine = groups.filter { selected.isSelected($0) }
        // The wording says where the title streams whatever is on screen; scope picks the tiles.
        return StreamingResolution(groups: scope == .mine ? mine : groups,
                                   verdict: mine.isEmpty ? .offMyServices : .available)
    }
}
