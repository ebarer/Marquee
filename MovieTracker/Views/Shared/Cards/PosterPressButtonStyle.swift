//
//  PosterPressButtonStyle.swift
//  MovieTracker
//

import SwiftUI

/// Press feedback for a poster card: the card dips and dims, since a grid cell has no row
/// highlight to fall back on.
struct PosterPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: configuration.isPressed ? 0.12 : 0.25),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PosterPressButtonStyle {
    static var posterPress: PosterPressButtonStyle { PosterPressButtonStyle() }
}

#Preview {
    HStack(spacing: 16) {
        Button {} label: {
            MoviePosterCard(movie: .preview, posterWidth: 110)
        }
        .buttonStyle(.posterPress)

        Button {} label: {
            ShowPosterCard(show: .preview, posterWidth: 110)
        }
        .buttonStyle(.posterPress)
    }
    .padding()
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
