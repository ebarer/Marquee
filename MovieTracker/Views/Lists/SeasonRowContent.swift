//
//  SeasonRowContent.swift
//  MovieTracker
//

import SwiftUI

/// The poster + "Season N • x of y Episodes" body shared by the Watched-list season rows
/// and the membership (Watch List / custom) tracked-season rows. Partial seasons get the
/// half-filled corner badge over the app's standard poster gradient.
struct SeasonRowContent: View {
    let entry: MediaSnapshot
    var tint: Color = .appAccent

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBWrapper.imageURL(path: entry.posterPath,
                                                  size: PosterSize.w185.rawValue))
                .frame(width: 51, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let rating = entry.userRating, rating > 0 {
                    StarRating(display: rating, tint: tint)
                        .padding(.top, 1)
                }
            }
            Spacer()
        }
    }

    private var subtitle: String {
        guard let season = entry.seasonNumber else { return "" }
        guard let watched = entry.seasonWatched, let total = entry.seasonTotal, total > 0 else {
            return "Season \(season)"
        }
        let remaining = total - watched
        guard remaining > 0 else { return "Season \(season)" }
        return "Season \(season)  •  Ep. \(watched + 1) of \(total)"
    }

    private var isPartial: Bool {
        guard let watched = entry.seasonWatched, let total = entry.seasonTotal, total > 0 else { return false }
        return watched < total
    }
}

#Preview("Season rows") {
    let context = previewModelContainer.mainContext
    // Real MediaItem ids so the snapshots are valid; contents are throwaway.
    func snap(_ id: Int, _ title: String, season: Int, watched: Int, total: Int,
              rating: Double? = nil) -> MediaSnapshot {
        let item = MediaItem(tmdbID: id, mediaType: .tv, title: title)
        context.insert(item)
        return MediaSnapshot(persistentID: item.persistentModelID, tmdbID: id, mediaType: .tv,
                             title: title, posterPath: nil, releaseDate: nil, sortDate: nil,
                             seasonNumber: season, seasonWatched: watched, seasonTotal: total,
                             runtime: nil, dateWatched: nil, userRating: rating)
    }
    return List {
        SeasonRowContent(entry: snap(1, "In Progress", season: 2, watched: 3, total: 10))
        SeasonRowContent(entry: snap(2, "Completed", season: 1, watched: 8, total: 8, rating: 4.5))
    }
    .listStyle(.plain)
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}
