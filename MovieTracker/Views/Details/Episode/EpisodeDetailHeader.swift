//
//  EpisodeDetailHeader.swift
//  MovieTracker
//

import SwiftUI

/// The still-backed episode header: the image extends up under the nav bar and fades into the
/// background, with ``EpisodeHeaderOverlay`` bottom-left. Grows on pull-down.
struct EpisodeDetailHeader: View {
    let episode: Episode
    let tint: Color
    let width: CGFloat
    let navBarBottom: CGFloat
    @Binding var showNavTitle: Bool

    var body: some View {
        // The still keeps a 16:9 area below the bar, plus the safe-area strip it draws under.
        let baseHeight = navBarBottom + width * 9.0 / 16.0

        GeometryReader { proxy in
            let minY = proxy.frame(in: .named("scroll")).minY
            let stretch = max(0, minY)                 // grow on pull-down
            let height = baseHeight + stretch

            ZStack(alignment: .bottomLeading) {
                Color.appBackground

                PosterImage(url: episode.stillURL(.w780))
                    .frame(width: width, height: height)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .appBackground],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: min(200, height))
                            .allowsHitTesting(false)
                    }

                EpisodeHeaderOverlay(episode: episode, tint: tint,
                                     navBarBottom: navBarBottom, showNavTitle: $showNavTitle)
                    .padding(16)
            }
            .frame(width: width, height: height)
            .clipped()
            .offset(y: minY > 0 ? -minY : 0)           // pin the top edge under the bar
        }
        .frame(height: baseHeight)
    }
}

#Preview {
    @Previewable @State var showNavTitle = false
    ScrollView {
        EpisodeDetailHeader(episode: Episode.previewEpisodes[0], tint: .appAccent,
                            width: 393, navBarBottom: 100, showNavTitle: $showNavTitle)
    }
    .coordinateSpace(name: "scroll")
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
