//
//  PersonFilmography.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The person's credits grouped into per-year sections, with a toggle that hides
/// "Self" and "Thanks" credits (on by default so real roles lead).
struct PersonFilmography: View {
    let credits: [Movie]
    let lists: [MovieList]
    let context: ModelContext

    @State private var hideExtraneous = true

    private var watchList: MovieList? { lists.first { $0.kind == .toWatch } }
    private var watchedList: MovieList? { lists.first { $0.kind == .watched } }

    var body: some View {
        if !creditsByYear.isEmpty {
            header
            ForEach(creditsByYear, id: \.year) { group in
                SectionHeader(title: yearTitle(group.year), color: .appAccent)
                ForEach(Array(group.movies.enumerated()), id: \.element.id) { index, movie in
                    row(movie)
                    if index < group.movies.count - 1 {
                        // Inset to start under the title, past the poster.
                        Rectangle()
                            .fill(Color.appSeparator)
                            .frame(height: 0.5)
                            .padding(.leading, 79)
                    }
                }
            }
        }
    }

    private func row(_ movie: Movie) -> some View {
        NavigationLink(value: movie) {
            HStack(spacing: 8) {
                MovieRow(movie: movie, role: movie.creditRole)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            WatchedSwipeButton(movie: movie, watchedList: watchedList, context: context)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            WatchListSwipeButton(movie: movie, watchList: watchList, context: context)
        }
        .movieContextMenu(for: movie, lists: lists, context: context)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Filmography")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            if hasExtraneousCredits {
                Button {
                    withAnimation(.easeInOut) { hideExtraneous.toggle() }
                } label: {
                    Image(systemName: hideExtraneous
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .font(.title3)
                }
                .tint(.appAccent)
                .accessibilityLabel(hideExtraneous ? "Show all credits" : "Hide Self and Thanks credits")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var hasExtraneousCredits: Bool {
        credits.contains { $0.isExtraneousCredit }
    }

    private var visibleCredits: [Movie] {
        hideExtraneous ? credits.filter { !$0.isExtraneousCredit } : credits
    }

    /// Credits arrive sorted newest-first, so grouping in order yields descending
    /// year sections with undated (upcoming) credits last.
    private var creditsByYear: [(year: Int?, movies: [Movie])] {
        var groups: [(year: Int?, movies: [Movie])] = []
        for movie in visibleCredits {
            let year = movie.releaseDate.map { Calendar.current.component(.year, from: $0) }
            if let index = groups.indices.last, groups[index].year == year {
                groups[index].movies.append(movie)
            } else {
                groups.append((year: year, movies: [movie]))
            }
        }
        return groups
    }

    private func yearTitle(_ year: Int?) -> String {
        year.map(String.init) ?? "Upcoming"
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                PersonFilmography(credits: Person.preview.credits ?? [], lists: [],
                                  context: previewModelContainer.mainContext)
            }
        }
        .movieTrackerDestinations()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
