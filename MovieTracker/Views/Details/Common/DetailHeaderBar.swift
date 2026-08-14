//
//  DetailHeaderBar.swift
//  MovieTracker
//

import SwiftUI

/// The bottom-anchored bar of a detail header: poster, title, subtitle, actions. `progress`
/// (0 → 1, from ``CollapsingBackdropHeader``) compacts it as the header pins.
struct DetailHeaderBar<Actions: View>: View {
    let posterThumbURL: URL?
    let posterFullURL: URL?
    let tint: Color
    let zoomID: Int
    /// Poster identity for the show's per-season crossfade; nil for movies.
    var posterIdentity: String? = nil
    let title: String
    let subtitle: String
    /// The runtime is still unknown, so it stands in as a bar rather than flashing in beside
    /// the date a moment later.
    var pendingDuration: Bool = false
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
        // The text column keeps a FIXED width (based on the full-size poster) so the title
        // never re-fits/re-wraps as the poster shrinks — that reflow caused visible vibration.
        let columnWidth = width - Self.padding * 2 - Self.posterWidth - 12
        let titleScale = 1 - 0.25 * progress
        let actionsScale = 1 - 0.2 * progress
        let posterHeight = Self.posterHeight - 37.5 * progress
        // Each scaled slot gets a frame matching what it DRAWS (scaleEffect alone leaves the
        // layout full-size), so the column's box is its visible bounds and centering lands.
        let columnHeight = titleHeight * titleScale
            + (showsSubtitle ? (subtitleHeight + 8) * (1 - progress) : 0)
            + 8 + actionsHeight * actionsScale
        // Bottom-aligned at rest; as the header pins, the poster and the title/actions column
        // slide onto a shared center line.
        let columnLift = max(0, posterHeight - columnHeight) / 2 * progress
        let posterLift = max(0, columnHeight - posterHeight) / 2 * progress

        HStack(alignment: .bottom, spacing: 12) {
            HeaderPoster(thumbnailURL: posterThumbURL, fullURL: posterFullURL, tint: tint,
                         zoomID: zoomID, identity: posterIdentity,
                         width: Self.posterWidth - 25 * progress,
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

                if showsSubtitle {
                    // Scales with the header and fades out, its slot collapsing to 0. Never
                    // clipped — opacity hits 0 before the shrinking slot reveals overflow.
                    subtitleLine
                        .font(.subheadline)
                        .foregroundStyle(tint)
                        .fixedSize()
                        .scaleEffect(titleScale, anchor: .topLeading)
                        .frame(height: subtitleHeight * (1 - progress), alignment: .topLeading)
                        .opacity(Double(max(0, 1 - progress * 3)))
                        .padding(.top, 8 * (1 - progress))
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

    private var showsSubtitle: Bool { !subtitle.isEmpty || pendingDuration }

    @ViewBuilder
    private var subtitleLine: some View {
        if pendingDuration {
            HStack(spacing: 8) {
                if !subtitle.isEmpty {
                    Text(subtitle)
                    Text("•")
                }
                MetadataPlaceholder(width: 62)   // about what "2 hr 11 min" occupies
            }
        } else {
            Text(subtitle)
        }
    }
}

// Runtime still unknown: a bar holds its place beside the date instead of flashing in.
#Preview("Pending duration") {
    GeometryReader { proxy in
        DetailHeaderBar(
            posterThumbURL: Movie.preview.posterURL(.w342),
            posterFullURL: Movie.preview.posterURL(.orig),
            tint: .appAccent, zoomID: Movie.preview.id,
            title: "The Odyssey", subtitle: "Jul 17, 2026",
            pendingDuration: true,
            progress: 0, width: proxy.size.width
        ) {
            Color.appAccent.frame(height: 44).clipShape(Capsule())
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

#Preview("Expanded / Collapsed") {
    GeometryReader { proxy in
        VStack(spacing: 24) {
            ForEach([CGFloat(0), 1], id: \.self) { progress in
                ForEach(["The Odyssey", "Anchorman: The Legend of Ron Burgundy"], id: \.self) { title in
                    DetailHeaderBar(
                        posterThumbURL: Movie.preview.posterURL(.w342),
                        posterFullURL: Movie.preview.posterURL(.orig),
                        tint: .appAccent, zoomID: Movie.preview.id,
                        title: title, subtitle: "2026  •  2 hr 25 min",
                        progress: progress, width: proxy.size.width
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
