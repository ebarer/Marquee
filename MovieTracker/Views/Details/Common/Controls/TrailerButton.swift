//
//  TrailerButton.swift
//  MovieTracker
//

import SwiftUI

/// The trailer play control shared by the detail action bars, presenting the player full screen.
/// Always holds its slot — disabled with nothing to play — so it can't pop in with the payload.
struct TrailerButton: View {
    let trailer: MediaTrailer?
    let tint: Color

    @State private var selected: MediaTrailer?

    var body: some View {
        GlassActionButton(systemName: "play.fill", isOn: false, shape: Circle(), tint: tint) {
            selected = trailer
        }
        .disabled(trailer == nil)
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
}

// With a trailer, and without one (disabled, still holding its slot).
#Preview {
    HStack(spacing: ActionBarMetrics.spacing) {
        TrailerButton(trailer: Movie.preview.primaryTrailer, tint: .appAccent)
        TrailerButton(trailer: nil, tint: .appAccent)
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
