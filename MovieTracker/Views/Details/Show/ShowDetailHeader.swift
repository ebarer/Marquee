//
//  ShowDetailHeader.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Show adapter over the shared ``CollapsingBackdropHeader``; the only differences are the
/// show action bar and a poster that follows the season chosen in the episodes picker.
struct ShowDetailHeader: View {
    let show: Show
    let tint: Color
    let lists: [MediaList]
    let navBarBottom: CGFloat
    let imageHeight: CGFloat
    let headerRest: CGFloat
    var overscroll: CGFloat = 0
    /// Poster path for the selected season (falls back to the show poster when nil).
    var seasonPosterPath: String? = nil
    /// Loaded episodes per season, forwarded to the action bar so "mark whole show watched"
    /// can date each season to its finale.
    var episodesBySeason: [Int: [Episode]] = [:]
    @Binding var headerPinned: Bool
    @Binding var progress: ShowProgress
    var onChange: () -> Void = {}

    var body: some View {
        CollapsingBackdropHeader(
            backgroundURL: show.backgroundURL(),
            navBarBottom: navBarBottom, imageHeight: imageHeight,
            headerRest: headerRest, overscroll: overscroll,
            headerPinned: $headerPinned
        ) { progress, width in
            DetailHeaderBar(
                posterThumbURL: posterURL(.w342),
                posterFullURL: posterURL(.orig),
                tint: tint, zoomID: show.id,
                posterIdentity: seasonPosterPath,
                title: show.name, subtitle: subtitle,
                pendingDetail: pendingNetwork,
                progress: progress, width: width
            ) {
                ShowActionBar(show: show, lists: lists, tint: tint,
                              episodesBySeason: episodesBySeason, progress: $progress,
                              onChange: onChange)
            }
        }
    }

    /// The selected season's poster at `size`, falling back to the show poster.
    private func posterURL(_ size: PosterSize) -> URL? {
        if let seasonPosterPath {
            return TMDBWrapper.imageURL(path: seasonPosterPath, size: size.rawValue)
        }
        return show.posterURL(size)
    }

    private var subtitle: String {
        var parts: [String] = []
        if show.yearRange != "N/A" { parts.append(show.yearRange) }
        if let network = show.networks?.first { parts.append(network) }
        return parts.joined(separator: "  •  ")
    }

    /// The network rides in on the detail payload, so a list or search record doesn't have it yet.
    private var pendingNetwork: Bool { show.networks == nil && !show.isDetailPayload }
}

#Preview {
    GeometryReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                ShowDetailHeader(show: .preview, tint: .appAccent, lists: [],
                                 navBarBottom: 100, imageHeight: proxy.size.height * 0.41,
                                 headerRest: proxy.size.height * 0.5,
                                 headerPinned: .constant(false), progress: .constant(ShowProgress()))
                Color.appSeparator.frame(height: 1200)
            }
        }
        .coordinateSpace(name: "scroll")
        .ignoresSafeArea(edges: [.top, .horizontal])
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
