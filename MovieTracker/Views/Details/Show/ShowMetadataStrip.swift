//
//  ShowMetadataStrip.swift
//  MovieTracker
//

import SwiftUI

/// Horizontal strip of show metadata cells, mirroring `MovieMetadataStrip`'s layout.
/// Rating and watched dates are tracked per season, not at the show level.
struct ShowMetadataStrip: View {
    /// What the cells render, held separately because `Show`'s `==` is id-only (it doubles as a
    /// navigation value): handed the whole struct, SwiftUI never sees the payload replace a stub.
    struct Fields: Equatable {
        var nextAirDate: Date?
        var certification: String?
        var seasonCount: Int
        var totalEpisodes: Int
        var rating: Double?
        var genres: String

        init(_ show: Show) {
            nextAirDate = show.isOngoing ? show.nextAirDate : nil
            certification = show.certification
            seasonCount = show.seasonCount
            totalEpisodes = show.totalEpisodes
            rating = show.rating
            genres = show.genresString
        }
    }

    let fields: Fields
    var tint: Color = .appAccent
    /// The detail payload is still in flight, so cells it fills read as placeholders.
    var isLoading: Bool = false

    init(show: Show, tint: Color = .appAccent, isLoading: Bool = false) {
        self.fields = Fields(show)
        self.tint = tint
        self.isLoading = isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            MetadataHairline()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if let nextAirDate = fields.nextAirDate {
                        MetadataCell(header: "NEXT EPISODE", minWidth: 80) {
                            // Tinted while it's a named day, so an episode landing this week
                            // stands out from the plain dates further off.
                            Text(nextAirDate.toRelativeDayString())
                                .foregroundStyle(nextAirDate.isWithinTheComingWeek ? tint : .white)
                        }
                        MetadataDivider()
                    }
                    MetadataCell(header: "RATING", minWidth: 60) {
                        value(known: fields.certification != nil, width: 26) { certBadge }
                    }
                    MetadataDivider()
                    MetadataCell(header: "SEASONS") {
                        value(known: fields.seasonCount > 0, width: 12) {
                            Text("\(fields.seasonCount)")
                        }
                    }
                    MetadataDivider()
                    MetadataCell(header: "EPISODES") {
                        value(known: fields.totalEpisodes > 0, width: 18) {
                            Text("\(fields.totalEpisodes)")
                        }
                    }
                    MetadataDivider()
                    MetadataCell(header: "TMDB.org") {
                        value(known: fields.rating != nil, width: 28) { tmdbScoreText(fields.rating) }
                    }
                    MetadataDivider()
                    MetadataCell(header: "GENRE", minWidth: 90) {
                        value(known: !fields.genres.isEmpty, width: 36) {
                            metadataText(fields.genres)
                        }
                    }
                }
            }
            .scrollBounceBehavior(.always, axes: .horizontal)
            MetadataHairline()
        }
    }

    /// A value the caller's stub can't know yet stands in as a bar, not as an empty one.
    @ViewBuilder
    private func value<V: View>(known: Bool, width: CGFloat,
                                @ViewBuilder content: () -> V) -> some View {
        if isLoading, !known {
            MetadataPlaceholder(width: width)
        } else {
            content()
        }
    }

    @ViewBuilder
    private var certBadge: some View {
        if let cert = fields.certification, let image = UIImage(named: "Cert-\(cert)") {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 24)
                .foregroundStyle(.white)
                .accessibilityLabel(cert)
        } else if let cert = fields.certification, !cert.isEmpty {
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

// A stub straight off a list row, with the payload still pending: bars, not em dashes. Must
// match the filled strip's height — it sits under the header and can't grow as cells fill in.
#Preview("Height across states") {
    let bare = Show(id: 1, name: "Unknown")

    return VStack(spacing: 20) {
        ShowMetadataStrip(show: .preview)
        ShowMetadataStrip(show: bare)
        ShowMetadataStrip(show: bare, isLoading: true)
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
