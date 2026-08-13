//
//  ShowRow.swift
//  MovieTracker
//

import SwiftUI

/// A show list row mirroring `MovieRow`, but with the air-year range and season
/// count (both gray) beneath the name so it reads clearly as a series.
struct ShowRow: View {
    let show: Show
    /// A credit role (character/job) shown under the name, e.g. in a person's credits.
    var role: String? = nil
    /// Credits pass `false` to skip the lazy per-row season-count fetch.
    var showsSeasonCount: Bool = true
    /// When set (a person's TV credits), shows "N Episodes" in place of the year range.
    var episodeCount: Int? = nil
    /// An explicit poster badge; leave nil and set `derivesStatus` to read it from the store.
    var status: PosterStatus? = nil
    /// Derive the badge from watched progress / Watch List membership (lists, search).
    var derivesStatus: Bool = false

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    /// Search/list stubs carry only a premiere date, so the year range shows a single year.
    /// Resolve the fuller show lazily to upgrade it to a real range (e.g. "2022–2025").
    @State private var resolvedYearRange: String?

    private var yearRange: String { resolvedYearRange ?? show.yearRange }

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: show.posterURL(.w185))
                .frame(width: 51, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay { badge }
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(.body)
                    .lineLimit(2)

                if let role, !role.isEmpty {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let episodeCount, episodeCount > 0 {
                    Text("^[\(episodeCount) Episode](inflect: true)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if yearRange != "N/A" {
                    Text(yearRange)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if showsSeasonCount {
                    // Season count isn't in list/search results, so it resolves lazily.
                    ShowSeasonCountText(show: show)
                }
            }

            Spacer()
        }
        .task(id: show.id) {
            // A stub (no seasons loaded) lacks last-air/status, so upgrade the year range
            // independently of the season-count text — otherwise "2021–Present" never shows.
            guard episodeCount == nil, show.seasonCount == 0,
                  let full = await ShowSeasonCountStore.shared.show(for: show.id) else { return }
            resolvedYearRange = full.yearRange
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let effectiveStatus {
            PosterStatusBadge(status: effectiveStatus, cornerRadius: 6, scale: 0.72)
                .transition(.opacity)
        }
    }

    /// TV progress is episode-based, so a series reads as watched / partially watched /
    /// to-watch rather than the movie `watchedAt` flag.
    private var effectiveStatus: PosterStatus? {
        if let status { return status }
        guard derivesStatus, let store else { return nil }
        _ = store.revision   // observe persisted changes so the badge refreshes live
        if store.isShowWatchedCached(showID: show.id) { return .watched }
        if store.hasWatchedEpisodes(showID: show.id) { return .partial }
        if store.isInWatchList(showID: show.id) { return .watchList }
        return nil
    }
}

#Preview {
    List {
        ShowRow(show: .preview)
        ShowRow(show: Show.previewList[1])
    }
    .listStyle(.plain)
    .preferredColorScheme(.dark)
}

#Preview("Status badges") {
    List {
        ShowRow(show: .preview, showsSeasonCount: false, status: .watched)
        ShowRow(show: .preview, showsSeasonCount: false, status: .partial)
        ShowRow(show: .preview, showsSeasonCount: false, status: .watchList)
    }
    .listStyle(.plain)
    .preferredColorScheme(.dark)
}
