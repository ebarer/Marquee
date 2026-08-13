//
//  FilmographyRows.swift
//  MovieTracker
//

import SwiftUI

/// The credit rows (movie or show) for one filmography group, with separators between them.
/// Movies carry watch/watched swipe actions and a context menu.
struct FilmographyRows: View {
    let credits: [MediaRef]
    let lists: [MediaList]

    var body: some View {
        ForEach(Array(credits.enumerated()), id: \.element.id) { index, ref in
            row(ref)
            if index < credits.count - 1 {
                Rectangle()
                    .fill(Color.appSeparator)
                    .frame(height: 0.5)
                    .padding(.leading, 79)
            }
        }
    }

    @ViewBuilder
    private func row(_ ref: MediaRef) -> some View {
        switch ref {
        case .movie(let movie): movieRow(movie)
        case .show(let show): showRow(show)
        }
    }

    private func movieRow(_ movie: Movie) -> some View {
        NavigationLink(value: movie) {
            HStack(spacing: 8) {
                MovieRow(movie: movie, role: movie.creditRole, derivesStatus: true)
                chevron
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            WatchedSwipeButton(movie: movie)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            WatchListSwipeButton(movie: movie)
        }
        .movieContextMenu(for: movie, lists: lists)
    }

    private func showRow(_ show: Show) -> some View {
        NavigationLink(value: show) {
            HStack(spacing: 8) {
                ShowRow(show: show, role: show.creditRole, showsSeasonCount: false,
                        episodeCount: show.episodeCount)
                chevron
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                FilmographyRows(credits: Person.preview.allCredits, lists: [])
            }
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
