//
//  GridCard.swift
//  MovieTracker
//

import SwiftUI

extension View {
    /// A list row body in a rounded-rect card, for the iPad list grid.
    func gridCard() -> some View {
        padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
            MovieRow(movie: .preview, subtitle: "Watched Aug 2, 2026", rating: 4.0,
                     status: .watched)
                .gridCard()
            MovieRow(movie: Movie.previewList[1], duration: "2 hr 8 min", status: .watchList)
                .gridCard()
            ShowRow(show: .preview, showsSeasonCount: false)
                .gridCard()
        }
        .padding()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
