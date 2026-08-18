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
    /// When set (a person's TV credits), replaces the year range — "S7 · E5", "Season 1",
    /// or "12 Episodes", resolved by the caller from ``EpisodeCredit``.
    var episodeSummary: String? = nil
    /// Art to use in place of the show's own — the season's, in a person's credits, so a run
    /// split across years doesn't repeat one poster down the list.
    var posterOverride: URL? = nil
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
            PosterImage(url: posterOverride ?? show.posterURL(.w185))
                .frame(width: 51, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .posterBorder(cornerRadius: 6)
                .overlay { badge }
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(.body)
                    .lineLimit(2)

                if let role, !role.isEmpty {
                    // Unbounded, as in ``MovieRow``: every role the person had is listed.
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let episodeSummary {
                    Text(episodeSummary)
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
            guard episodeSummary == nil, show.seasonCount == 0,
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

    private var effectiveStatus: PosterStatus? {
        if let status { return status }
        guard derivesStatus, let store else { return nil }
        return .derive(showID: show.id, from: store.badges)
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
