//
//  ShowDetailHeader.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Show adapter over the shared `CollapsingBackdropHeader`, with a poster that follows the chosen season.
struct ShowDetailHeader: View {
    let show: Show
    let tint: Color
    let lists: [MediaList]
    let navBarBottom: CGFloat
    let imageHeight: CGFloat
    let headerRest: CGFloat
    var overscroll: CGFloat = 0
    var seasonPosterPath: String? = nil
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
