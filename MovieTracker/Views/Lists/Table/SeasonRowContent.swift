//
//  SeasonRowContent.swift
//  MovieTracker
//

import SwiftUI

/// The poster + "Season N • x of y Episodes" body shared by the Watched-list season rows and
/// the tracked-season rows. Partial seasons get the half-filled corner badge.
struct SeasonRowContent: View {
    let entry: MediaSnapshot
    /// Appended to the season line — the watched date on the Watched list.
    var detail: String? = nil
    var tint: Color = .appAccent

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBWrapper.imageURL(path: entry.posterPath,
                                                  size: PosterSize.w185.rawValue))
                .frame(width: 51, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .posterBorder(cornerRadius: 6)
                .overlay {
                    if isPartial {
                        PosterSymbolBadge(symbol: "circle.tophalf.filled",
                                          cornerRadius: 6, pointSize: 15, padding: 5)
                    }
                }
                .padding(.vertical, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body)
                    .lineLimit(2)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let nextEpisodeDate = entry.nextEpisodeDate {
                    Text(nextEpisodeDate.toString())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let rating = entry.userRating, rating > 0 {
                    StarRating(display: rating, tint: tint)
                        .padding(.top, 1)
                }
            }
            Spacer()
        }
    }

    static let separator = "  •  "

    /// The season, its episode progress while there's more to watch, and `detail` — one line.
    var subtitle: String {
        [season, detail].compactMap { $0 }.joined(separator: Self.separator)
    }

    private var season: String? {
        guard let season = entry.seasonNumber else { return nil }
        guard isPartial, let watched = entry.seasonWatched, let total = entry.seasonTotal else {
            return "Season \(season)"
        }
        return "Season \(season)\(Self.separator)Ep. \(watched + 1) of \(total)"
    }

    private var isPartial: Bool {
        guard let watched = entry.seasonWatched, let total = entry.seasonTotal, total > 0 else { return false }
        return watched < total
    }
}

#Preview("Season rows") {
    List {
        // A backlog episode that already aired, and one still to come.
        SeasonRowContent(entry: .preview(id: 1, title: "In Progress", mediaType: .tv, season: 2,
                                         seasonWatched: 3, seasonTotal: 10,
                                         nextEpisodeDate: .now.addingTimeInterval(-40 * 24 * 3600)))
        SeasonRowContent(entry: .preview(id: 2, title: "Completed", mediaType: .tv, season: 1,
                                         seasonWatched: 8, seasonTotal: 8, userRating: 4.5),
                         detail: "Finished \(Date().toString())")
        SeasonRowContent(entry: .preview(id: 3, title: "Caught Up", mediaType: .tv, season: 3,
                                         seasonWatched: 5, seasonTotal: 8,
                                         nextEpisodeDate: .now.addingTimeInterval(5 * 24 * 3600)))
    }
    .listStyle(.plain)
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}
