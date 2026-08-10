//
//  ShowSeasonCountText.swift
//  MovieTracker
//

import SwiftUI

/// Session memo for lazily-resolved show details. TMDB omits season counts, last-air
/// dates and status from list/search results, so cards resolve a fuller `Show` on demand —
/// reusing a cached detail when present, else a single base `/tv/{id}` summary — and dedupe
/// concurrent/repeat lookups by id.
@MainActor
final class ShowSeasonCountStore {
    static let shared = ShowSeasonCountStore()

    private var resolved: [Int: Show] = [:]
    private var tasks: [Int: Task<Show?, Never>] = [:]

    /// The fuller show for `id` (season list + air range), or nil if it can't be fetched.
    func show(for id: Int) async -> Show? {
        if let cached = resolved[id] { return cached }
        if let inFlight = tasks[id] { return await inFlight.value }

        let task = Task<Show?, Never> {
            if let cached = await MediaCacheStore.shared.loadShow(id: id), cached.show.seasonCount > 0 {
                return cached.show
            }
            return try? await TMDBWrapper.showSummary(id: id)
        }
        tasks[id] = task
        let result = await task.value
        tasks[id] = nil
        if let result { resolved[id] = result }
        return result
    }
}

/// Displays "N Seasons" for a show, resolving the count lazily and showing an
/// optional placeholder (typically the air year) until it arrives.
struct ShowSeasonCountText: View {
    let show: Show
    var placeholder: String? = nil
    var font: Font = .subheadline

    @State private var resolved: Int?

    private var count: Int? {
        show.seasonCount > 0 ? show.seasonCount : resolved
    }

    var body: some View {
        Group {
            if let count {
                Text(count == 1 ? "1 Season" : "\(count) Seasons")
            } else if let placeholder {
                Text(placeholder)
            }
        }
        .font(font)
        .foregroundStyle(.secondary)
        .task(id: show.id) {
            guard show.seasonCount == 0 else { return }
            resolved = await ShowSeasonCountStore.shared.show(for: show.id)?.seasonCount
        }
    }
}
