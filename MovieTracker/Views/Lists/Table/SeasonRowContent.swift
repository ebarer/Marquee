//
//  SeasonRowContent.swift
//  MovieTracker
//

import SwiftUI

/// The poster and "Season N - x of y Episodes" body shared by the Watched and tracked-season rows.
struct SeasonRowContent: View {
    let entry: MediaSnapshot
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
                    Text(nextEpisodeDate.toRelativeDayString())
                        .font(.subheadline)
                        .foregroundStyle(nextEpisodeDate.hasRelativeDayName ? tint : .secondary)
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

// Air dates parse as UTC midnight, so the previews have to seed them that way to read as the same day.
private func previewAirDate(inDays days: Int) -> Date {
    DateFormatter.utcCalendar.date(byAdding: .day, value: days,
                                   to: MediaItem.floatingDay(from: .now)) ?? .now
}

#Preview("Season rows") {
    List {
        SeasonRowContent(entry: .preview(id: 1, title: "In Progress", mediaType: .tv, season: 2,
                                         seasonWatched: 3, seasonTotal: 10,
                                         nextEpisodeDate: previewAirDate(inDays: -40)))
        SeasonRowContent(entry: .preview(id: 2, title: "Completed", mediaType: .tv, season: 1,
                                         seasonWatched: 8, seasonTotal: 8, userRating: 4.5),
                         detail: "Finished \(Date().toString())")
        SeasonRowContent(entry: .preview(id: 3, title: "Caught Up", mediaType: .tv, season: 3,
                                         seasonWatched: 5, seasonTotal: 8,
                                         nextEpisodeDate: previewAirDate(inDays: 5)))
        SeasonRowContent(entry: .preview(id: 4, title: "Airing Today", mediaType: .tv, season: 1,
                                         seasonWatched: 2, seasonTotal: 6,
                                         nextEpisodeDate: previewAirDate(inDays: 0)))
        SeasonRowContent(entry: .preview(id: 5, title: "Aired Yesterday", mediaType: .tv, season: 2,
                                         seasonWatched: 4, seasonTotal: 9,
                                         nextEpisodeDate: previewAirDate(inDays: -1)))
    }
    .listStyle(.plain)
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}
