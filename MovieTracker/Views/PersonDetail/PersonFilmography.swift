//
//  PersonFilmography.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The person's credits grouped into per-year sections, with upcoming work in a collapsible section.
struct PersonFilmography: View {
    let credits: [Movie]
    let lists: [MediaList]
    @Binding var hideExtraneous: Bool
    var navBarBottom: CGFloat = 0
    var onFilterHiddenChange: (Bool) -> Void = { _ in }

    @State private var upcomingExpanded = false

    var body: some View {
        if !visibleCredits.isEmpty {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                header
                if !upcomingCredits.isEmpty {
                    upcomingSection
                }
                ForEach(releasedByYear, id: \.year) { group in
                    Section {
                        rows(group.movies)
                    } header: {
                        SectionHeader(title: String(group.year), color: .appAccent)
                            .background(Color.appBackground)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rows(_ movies: [Movie]) -> some View {
        ForEach(Array(movies.enumerated()), id: \.element.id) { index, movie in
            row(movie)
            if index < movies.count - 1 {
                Rectangle()
                    .fill(Color.appSeparator)
                    .frame(height: 0.5)
                    .padding(.leading, 79)
            }
        }
    }

    private func row(_ movie: Movie) -> some View {
        NavigationLink(value: movie) {
            HStack(spacing: 8) {
                MovieRow(movie: movie, role: movie.creditRole, derivesStatus: true)
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
            WatchedSwipeButton(movie: movie)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            WatchListSwipeButton(movie: movie)
        }
        .movieContextMenu(for: movie, lists: lists)
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
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .global).maxY <= navBarBottom
        } action: { onFilterHiddenChange($0) }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        Button {
            withAnimation(.easeInOut) { upcomingExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text("Upcoming")
                    .font(.headline)
                    .foregroundStyle(Color.appAccent)
                Text("(\(upcomingCredits.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(upcomingExpanded ? 90 : 0))
                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upcoming, \(upcomingCredits.count) movies")
        .accessibilityHint(upcomingExpanded ? "Collapses the section" : "Expands the section")

        if upcomingExpanded {
            rows(upcomingCredits)
        }
    }

    private var hasExtraneousCredits: Bool {
        credits.contains { $0.isExtraneousCredit }
    }

    private var visibleCredits: [Movie] {
        hideExtraneous ? credits.filter { !$0.isExtraneousCredit } : credits
    }

    /// Credits with a release date still in the future. Undated credits are omitted
    /// from the filmography entirely.
    private var upcomingCredits: [Movie] {
        let now = Date()
        return visibleCredits.filter { movie in
            guard let date = movie.releaseDate else { return false }
            return date > now
        }
    }

    /// Released credits grouped into descending per-year sections. Credits arrive
    /// sorted newest-first, so grouping in order preserves that ordering.
    private var releasedByYear: [(year: Int, movies: [Movie])] {
        let now = Date()
        var groups: [(year: Int, movies: [Movie])] = []
        for movie in visibleCredits {
            guard let date = movie.releaseDate, date <= now else { continue }
            let year = Calendar.current.component(.year, from: date)
            if let index = groups.indices.last, groups[index].year == year {
                groups[index].movies.append(movie)
            } else {
                groups.append((year: year, movies: [movie]))
            }
        }
        return groups
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                PersonFilmography(credits: Person.preview.credits ?? [], lists: [],
                                  hideExtraneous: .constant(true))
            }
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
