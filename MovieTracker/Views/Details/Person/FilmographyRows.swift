//
//  FilmographyRows.swift
//  MovieTracker
//

import SwiftUI

/// The credit rows for one filmography group, with separators between them.
struct FilmographyRows: View {
    let entries: [FilmographyEntry]
    let lists: [MediaList]

    var body: some View {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            FilmographyRow(entry: entry, lists: lists)
            if index < entries.count - 1 {
                FilmographyRowSeparator()
            }
        }
    }
}

/// One credit, movie or show.
struct FilmographyRow: View {
    let entry: FilmographyEntry
    let lists: [MediaList]

    var body: some View {
        switch entry.ref {
        case .movie(let movie): movieRow(movie)
        case .show(let show):
            ShowCreditRow(show: show, credit: entry.credit, season: entry.season)
        }
    }

    private func movieRow(_ movie: Movie) -> some View {
        NavigationLink(value: movie) {
            HStack(spacing: 8) {
                MovieRow(movie: movie, role: movie.creditRole,
                         jobs: CreditJob.line(movie.creditJobs), derivesStatus: true)
                chevron
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.rowPress)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            WatchedSwipeButton(movie: movie)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            WatchListSwipeButton(movie: movie)
        }
        .movieContextMenu(for: movie, lists: lists)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

/// The hairline between credits.
struct FilmographyRowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
            .padding(.leading, 79)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                FilmographyRows(entries: FilmographyEntry.entries(for: Person.preview.allCredits,
                                                                  episodeCredits: [:]),
                                lists: [])
            }
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
