//
//  ShowMetadataStrip.swift
//  MovieTracker
//

import SwiftUI

/// Horizontal strip of show metadata cells, mirroring `MovieMetadataStrip`'s layout.
/// Rating and watched dates are tracked per season, not at the show level.
struct ShowMetadataStrip: View {
    let show: Show
    var tint: Color = .appAccent

    var body: some View {
        VStack(spacing: 0) {
            MetadataHairline()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if show.isOngoing, let nextAirDate = show.nextAirDate {
                        MetadataCell(header: "NEXT EPISODE", minWidth: 80) {
                            // Tinted while it's a named day, so an episode landing this week
                            // stands out from the plain dates further off.
                            Text(nextAirDate.toRelativeDayString())
                                .foregroundStyle(nextAirDate.isWithinTheComingWeek ? tint : .white)
                        }
                        MetadataDivider()
                    }
                    MetadataCell(header: "RATING", minWidth: 60) { certBadge }
                    MetadataDivider()
                    MetadataCell(header: "SEASONS") { Text("\(show.seasonCount)") }
                    MetadataDivider()
                    MetadataCell(header: "EPISODES") { Text("\(show.totalEpisodes)") }
                    MetadataDivider()
                    MetadataCell(header: "TMDB.org") { tmdbScoreText(show.rating) }
                    MetadataDivider()
                    MetadataCell(header: "GENRE", minWidth: 90) { metadataText(show.genresString) }
                }
            }
            .scrollBounceBehavior(.always, axes: .horizontal)
            MetadataHairline()
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
                .accessibilityLabel(cert)
        } else if let cert = show.certification, !cert.isEmpty {
            Text(cert)   // text fallback until the TV imageset lands
        } else {
            metadataUnavailable
        }
    }
}

#Preview {
    ShowMetadataStrip(show: .preview)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}

// Every step of the next-episode cell: named and tinted inside the week, plain past it.
#Preview("Next episode timing") {
    func show(inDays days: Int) -> Show {
        // Built the way TMDB's air dates arrive: UTC midnight on a calendar day.
        let today = MediaItem.floatingDay(from: Date())
        var show = Show.preview
        show.nextAirDate = DateFormatter.utcCalendar.date(byAdding: .day, value: days, to: today)
        return show
    }
    return VStack(spacing: 24) {
        ForEach([0, 1, 3, 30], id: \.self) { days in
            ShowMetadataStrip(show: show(inDays: days))
        }
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

#Preview("Ended") {
    ShowMetadataStrip(show: Show.previewList[1])
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
