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
    @State private var titleHeight: CGFloat = 0
    @State private var actionsHeight: CGFloat = 0

    private static var posterWidth: CGFloat { 100 }
    private static var posterHeight: CGFloat { 150 }
    private static var padding: CGFloat { 16 }

    var body: some View {
        let p = progress
        // The text column keeps a FIXED width (based on the full-size poster) so the title
        // never re-fits/re-wraps as the poster shrinks — that reflow caused visible vibration.
        let columnWidth = width - Self.padding * 2 - Self.posterWidth - 12
        let titleScale = 1 - 0.25 * p
        let actionsScale = 1 - 0.2 * p
        let posterHeight = Self.posterHeight - 37.5 * p
        // Each scaled slot gets a frame matching what it DRAWS (scaleEffect alone leaves the
        // layout at full size), so the column's box is its visible bounds — which is what
        // makes the collapsed centering below land exactly.
        let columnHeight = titleHeight * titleScale
            + (subtitle.isEmpty ? 0 : (subtitleHeight + 8) * (1 - p))
            + 8 + actionsHeight * actionsScale
        // Bottom-aligned at rest; as the header pins, the poster and the title/actions column
        // slide onto a shared center line.
        let columnLift = max(0, posterHeight - columnHeight) / 2 * p
        let posterLift = max(0, columnHeight - posterHeight) / 2 * p

        HStack(alignment: .bottom, spacing: 12) {
            HeaderPoster(thumbnailURL: posterThumbURL, fullURL: posterFullURL, tint: tint,
                         zoomID: zoomID, identity: posterIdentity,
                         width: Self.posterWidth - 25 * p,
                         height: posterHeight)
                .offset(y: -posterLift)

            VStack(alignment: .leading, spacing: 0) {
                HeaderTitle(title: title)
                    // Fixed font + scaleEffect so the text never re-wraps as it shrinks.
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    // fixedSize keeps the measured height content-driven, so the frame below
                    // can't feed back into it.
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
                    .scaleEffect(titleScale, anchor: .bottomLeading)
                    .frame(height: titleHeight * titleScale, alignment: .bottom)

                if !subtitle.isEmpty {
                    // Scales with the rest of the header and fades out; its slot collapses to
                    // 0 so the gap closes. Never clipped — opacity hits 0 before the shrinking
                    // slot could reveal overflow.
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(tint)
                        .fixedSize()
                        .scaleEffect(titleScale, anchor: .topLeading)
                        .frame(height: subtitleHeight * (1 - p), alignment: .topLeading)
                        .opacity(Double(max(0, 1 - p * 3)))
                        .padding(.top, 8 * (1 - p))
                }

                actions()
                    // Top anchor keeps the buttons' top edge where layout puts it (8pt below
                    // the title), so the compact title→buttons gap matches the title→label gap.
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { actionsHeight = $0 }
                    .scaleEffect(actionsScale, anchor: .topLeading)
                    .frame(height: actionsHeight * actionsScale, alignment: .top)
                    .padding(.top, 8)
            }
            .frame(width: columnWidth, alignment: .leading)
            .offset(y: -columnLift)

            Spacer(minLength: 0)
        }
        .padding(Self.padding)
    }
}

#Preview("Expanded / Collapsed") {
    GeometryReader { proxy in
        VStack(spacing: 24) {
            ForEach([CGFloat(0), 1], id: \.self) { p in
                ForEach(["The Odyssey", "Anchorman: The Legend of Ron Burgundy"], id: \.self) { title in
                    DetailHeaderBar(
                        posterThumbURL: Movie.preview.posterURL(.w342),
                        posterFullURL: Movie.preview.posterURL(.orig),
                        tint: .appAccent, zoomID: Movie.preview.id,
                        title: title, subtitle: "2026  •  2 hr 25 min",
                        progress: p, width: proxy.size.width
                    ) {
                        Color.appAccent.frame(height: 44).clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
