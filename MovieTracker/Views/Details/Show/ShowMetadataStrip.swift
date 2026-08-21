//
//  ShowMetadataStrip.swift
//  MovieTracker
//

import SwiftUI

/// Horizontal strip of show metadata cells. Rating and watched dates are tracked per season, not per show.
struct ShowMetadataStrip: View {
    /// Held apart because `Show`'s `==` is id-only, so SwiftUI would never see the payload replace a stub.
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
    let name: String
    var tint: Color = .appAccent
    var isLoading: Bool = false
    var awards: AwardsDigest = AwardsDigest()
    var awardsResolved: Bool = true

    init(show: Show, tint: Color = .appAccent, isLoading: Bool = false,
         awards: AwardsDigest = AwardsDigest(), awardsResolved: Bool = true) {
        self.fields = Fields(show)
        self.name = show.name
        self.tint = tint
        self.isLoading = isLoading
        self.awards = awards
        self.awardsResolved = awardsResolved
    }

    @State private var showingAwards = false

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
                                .foregroundStyle(nextAirDate.hasRelativeDayName ? tint : .white)
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
                    AwardsMetadataCell(awards: awards, isResolved: awardsResolved,
                                       tint: tint) { showingAwards = true }
                }
                .animation(.snappy, value: awards)
            }
            .scrollBounceBehavior(.always, axes: .horizontal)
            MetadataHairline()
        }
        .sheet(isPresented: $showingAwards) {
            AwardsListView(title: name, digest: awards, tint: tint)
        }
    }

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
    ShowMetadataStrip(show: .preview, awards: .preview)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}

// The awards cell lands a beat after TMDB's fields: pending, then a count or "None".
#Preview("Awards cell") {
    // A strip's dividers are vertically greedy, so these need a ScrollView to size naturally.
    ScrollView {
        VStack(spacing: 20) {
            ShowMetadataStrip(show: .preview, awardsResolved: false)
            ShowMetadataStrip(show: .preview)
            ShowMetadataStrip(show: .preview, awards: .preview)
        }
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

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

// A stub straight off a list row, with the payload still pending: bars, not em dashes. Must match
// the filled strip's height, since it sits under the header and can't grow as cells fill in.
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
