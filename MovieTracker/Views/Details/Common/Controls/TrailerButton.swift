//
//  TrailerButton.swift
//  MovieTracker
//

import SwiftUI

/// The trailer control shared by the detail action bars. Always holds its slot so it can't pop in with the payload.
struct TrailerButton: View {
    let trailers: [MediaTrailer]
    let tint: Color

    @State private var selected: MediaTrailer?

    private static let menuLimit = 5

    private var primary: MediaTrailer? { trailers.first }
    private var choices: [MediaTrailer] { Array(trailers.prefix(Self.menuLimit)) }

    var body: some View {
        control
            .fullScreenCover(item: $selected) { trailer in
                NavigationStack {
                    TrailerPlayerView(trailer: trailer) { selected = nil }
                        .background(Color.black.ignoresSafeArea())
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(role: .close) { selected = nil }
                            }
                        }
                }
            }
    }

    @ViewBuilder
    private var control: some View {
        if trailers.count > 1 {
            GlassActionMenu(systemName: "play.fill", isOn: false, shape: Circle(), tint: tint,
                            primaryAction: { selected = primary }) {
                ForEach(choices) { trailer in
                    Button {
                        selected = trailer
                    } label: {
                        Text(trailer.title)
                        Text(trailer.subtitle)
                    }
                }
            }
        } else {
            GlassActionButton(systemName: "play.fill", isOn: false, shape: Circle(), tint: tint) {
                selected = primary
            }
            .disabled(primary == nil)
        }
    }
}

#Preview {
    HStack(spacing: ActionBarMetrics.spacing) {
        TrailerButton(trailers: Movie.preview.rankedTrailers, tint: .appAccent)
        TrailerButton(trailers: MediaTrailer.previewSingle, tint: .appAccent)
        TrailerButton(trailers: [], tint: .appAccent)
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
