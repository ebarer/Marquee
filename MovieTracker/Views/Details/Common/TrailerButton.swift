//
//  TrailerButton.swift
//  MovieTracker
//

import SwiftUI

/// The trailer play control shared by the detail action bars. Renders nothing when
/// there's no trailer; presents the player full screen over a black backdrop.
struct TrailerButton: View {
    let trailer: MediaTrailer?
    let tint: Color

    @State private var selected: MediaTrailer?

    var body: some View {
        if let trailer {
            GlassActionButton(systemName: "play.fill", isOn: false, shape: Circle(), tint: tint) {
                selected = trailer
            }
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
}

#Preview {
    TrailerButton(trailer: Movie.preview.primaryTrailer, tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
