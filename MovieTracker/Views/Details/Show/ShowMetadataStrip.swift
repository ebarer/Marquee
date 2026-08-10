//
//  ShowMetadataStrip.swift
//  MovieTracker
//

import SwiftUI

/// Horizontal strip of show metadata cells, mirroring `MovieMetadataStrip`'s layout.
/// Rating and watched dates are tracked per season, not at the show level.
struct ShowMetadataStrip: View {
    let show: Show

    var body: some View {
        VStack(spacing: 0) {
            MetadataHairline()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    MetadataCell(header: "RATING", minWidth: 60) { certBadge }
                    MetadataDivider()
                    MetadataCell(header: "SEASONS") { Text("\(show.seasonCount)") }
                    MetadataDivider()
                    MetadataCell(header: "EPISODES") { Text("\(show.totalEpisodes)") }
                    MetadataDivider()
                    MetadataCell(header: "TMDB.org") { tmdbScoreText(show.rating) }
                    MetadataDivider()
                    MetadataCell(header: "GENRE", minWidth: 90) { Text(show.genresString) }
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
        } else if let cert = show.certification, !cert.isEmpty {
            Text(cert)   // text fallback until the TV imageset lands
        } else {
            Text("N/A")
        }
    }
}

#Preview {
    ShowMetadataStrip(show: .preview)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
