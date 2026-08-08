//
//  ShowMetadataStrip.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Horizontal strip of show metadata cells, mirroring `MovieMetadataStrip`'s layout;
/// watched shows lead with the user's rating and watched date.
struct ShowMetadataStrip: View {
    let show: Show
    var tint: Color = .appAccent
    var isWatched: Bool = false

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            hairline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if let store, isWatched {
                        HStack(alignment: .top, spacing: 0) {
                            cell(header: "MY RATING") {
                                StarRating(key: show.mediaKey, rating: store.rating(for: show) ?? 0, tint: tint)
                            }
                            divider
                            cell(header: "WATCHED", minWidth: 80) {
                                WatchedDateButton(key: show.mediaKey, watchedDate: store.dateWatched(for: show), tint: tint)
                            }
                            divider
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    cell(header: "RATING", minWidth: 60) { certBadge }
                    divider
                    cell(header: "SEASONS") { valueText("\(show.seasonCount)") }
                    divider
                    cell(header: "EPISODES") { valueText("\(show.totalEpisodes)") }
                    divider
                    cell(header: "TMDB.org") { tmdbScore.multilineTextAlignment(.center) }
                    divider
                    cell(header: "GENRE", minWidth: 90) { valueText(show.genresString) }
                }
                .animation(.snappy, value: isWatched)
            }
            .scrollBounceBehavior(.always, axes: .horizontal)
            hairline
        }
    }

    @ViewBuilder
    private var certBadge: some View {
        if let cert = show.certification, let image = UIImage(named: "Cert-\(cert)") {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 24)
                .foregroundStyle(.white)
        } else if let cert = show.certification, !cert.isEmpty {
            valueText(cert)   // text fallback until the TV imageset lands
        } else {
            valueText("N/A")
        }
    }

    private var tmdbScore: Text {
        guard let rating = show.rating, rating > 0 else {
            return Text("N/A")
        }
        let score = (rating / 2 * 10).rounded() / 10
        let formatted = score == score.rounded()
            ? String(format: "%.0f", score)
            : String(format: "%.1f", score)
        return Text("\(formatted)\(Text(" / 5").foregroundColor(.secondary))")
    }

    private func cell<Content: View>(header: String, minWidth: CGFloat = 44,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            Text(header)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .fixedSize()
        .frame(minWidth: minWidth, alignment: .top)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func valueText(_ text: String) -> some View {
        Text(text).multilineTextAlignment(.center)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(width: 0.5)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 14)
    }
}

#Preview {
    ShowMetadataStrip(show: .preview)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
