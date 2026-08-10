//
//  DetailHeaderBar.swift
//  MovieTracker
//

import SwiftUI

/// The bottom-anchored bar of a detail header: poster, title, subtitle, and an action bar.
/// `progress` (0 → 1, from ``CollapsingBackdropHeader``) compacts it as the header pins —
/// the poster/title shrink to 75%, the subtitle fades to nothing, and the actions tuck up.
/// The `actions` slot is media-specific (movie vs. show action bar).
struct DetailHeaderBar<Actions: View>: View {
    let posterThumbURL: URL?
    let posterFullURL: URL?
    let tint: Color
    let zoomID: Int
    /// Poster identity for the show's per-season crossfade; nil for movies.
    var posterIdentity: String? = nil
    let title: String
    let subtitle: String
    let progress: CGFloat
    let width: CGFloat
    @ViewBuilder let actions: () -> Actions

    @ScaledMetric private var subtitleHeight: CGFloat = 20

    private static var posterWidth: CGFloat { 100 }
    private static var posterHeight: CGFloat { 150 }
    private static var padding: CGFloat { 16 }

    var body: some View {
        let p = progress
        // The text column keeps a FIXED width (based on the full-size poster) so the title
        // never re-fits/re-wraps as the poster shrinks — that reflow caused visible vibration.
        let columnWidth = width - Self.padding * 2 - Self.posterWidth - 12

        HStack(alignment: .bottom, spacing: 12) {
            HeaderPoster(thumbnailURL: posterThumbURL, fullURL: posterFullURL, tint: tint,
                         zoomID: zoomID, identity: posterIdentity,
                         width: Self.posterWidth - 25 * p,
                         height: Self.posterHeight - 37.5 * p)

            VStack(alignment: .leading, spacing: 0) {
                HeaderTitle(title: title)
                    // Fixed font + scaleEffect so the text never re-wraps as it shrinks.
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .scaleEffect(1 - 0.25 * p, anchor: .bottomLeading)

                if !subtitle.isEmpty {
                    // Scales with the rest of the header and fades out; its slot collapses to
                    // 0 so the gap closes. Never clipped — opacity hits 0 before the shrinking
                    // slot could reveal overflow.
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(tint)
                        .fixedSize()
                        .scaleEffect(1 - 0.25 * p, anchor: .topLeading)
                        .frame(height: subtitleHeight * (1 - p), alignment: .topLeading)
                        .opacity(Double(max(0, 1 - p * 3)))
                        .padding(.top, 8 * (1 - p))
                }

                actions()
                    // Top anchor keeps the buttons' top edge where layout puts it (8pt below
                    // the title), so the compact title→buttons gap matches the title→label gap.
                    .scaleEffect(1 - 0.2 * p, anchor: .topLeading)
                    .padding(.top, 8)
            }
            .frame(width: columnWidth, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(Self.padding)
    }
}

#Preview {
    GeometryReader { proxy in
        DetailHeaderBar(
            posterThumbURL: Movie.preview.posterURL(.w342),
            posterFullURL: Movie.preview.posterURL(.orig),
            tint: .appAccent, zoomID: Movie.preview.id,
            title: Movie.preview.title, subtitle: "2026  •  2 hr 25 min",
            progress: 0, width: proxy.size.width
        ) {
            Color.appAccent.frame(height: 44).clipShape(Capsule())
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
