//
//  ShowRow.swift
//  MovieTracker
//

import SwiftUI

/// A show list row mirroring `MovieRow`, with the air-year range and season count beneath the name.
struct ShowRow: View {
    let show: Show
    var role: String? = nil
    var jobs: String? = nil
    var showsSeasonCount: Bool = true
    var episodeSummary: String? = nil
    var posterOverride: URL? = nil
    var status: PosterStatus? = nil
    var derivesStatus: Bool = false
    var posterSize = CGSize(width: 51, height: 76)

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    // Search and list stubs carry only a premiere date, so the fuller show is resolved lazily.
    @State private var resolvedYearRange: String?

    private var yearRange: String { resolvedYearRange ?? show.yearRange }

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: posterOverride ?? show.posterURL(.w185))
                .frame(width: posterSize.width, height: posterSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .posterBorder(cornerRadius: 6)
                .overlay { badge }
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(.body)
                    .lineLimit(2)

                if let episodeSummary {
                    Text(episodeSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if yearRange != "N/A" {
                    Text(yearRange)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let role, !role.isEmpty {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let jobs, !jobs.isEmpty {
                    // Unbounded, as in ``MovieRow``: every job the person had is listed.
                    Text(jobs)
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
            // A stub with no seasons loaded lacks last-air and status, so upgrade the year range independently
            // of the season-count text, or "2021-Present" never shows.
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
