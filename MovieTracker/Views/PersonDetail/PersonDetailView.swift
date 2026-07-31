//
//  PersonDetailView.swift
//  MovieTracker
//
//  SwiftUI person detail screen: a biography header (profile, name + age,
//  expandable bio) and a filmography grouped into per-year sections. The
//  nav-bar title stays hidden until the on-page name scrolls up behind the
//  bar. Replaces the storyboard PersonDetailViewController.
//

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    let person: Person

    @State private var model = PersonDetailModel()
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var lists: [MovieList]

    /// Reveal the nav-bar title only once the on-page name is hidden behind it.
    @State private var showNavTitle = false
    /// Global Y of the nav bar's bottom edge (the List's top), fed to the header.
    @State private var navBarBottom: CGFloat = 0

    private var current: Person { model.person ?? person }
    private var watchList: MovieList? { lists.first { $0.kind == .toWatch } }
    private var watchedList: MovieList? { lists.first { $0.kind == .watched } }

    var body: some View {
        List {
            Section {
                PersonBioHeader(person: current, navBarBottom: navBarBottom) { hidden in
                    withAnimation(.easeInOut(duration: 0.2)) { showNavTitle = hidden }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                .listRowSeparator(.hidden)
            }

            ForEach(creditsByYear, id: \.year) { group in
                Section(yearTitle(group.year)) {
                    ForEach(group.movies, id: \.id) { movie in
                        MovieListRow(
                            movie: movie,
                            role: movie.creditRole,
                            lists: lists,
                            context: context,
                            leadingActions: {
                                WatchedSwipeButton(movie: movie, watchedList: watchedList, context: context)
                            },
                            trailingActions: {
                                WatchListSwipeButton(movie: movie, watchList: watchList, context: context)
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(current.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(current.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(showNavTitle ? 1 : 0)
            }
        }
        .background {
            // The List sits below the nav bar, so its global top edge is the
            // nav bar's bottom edge — the threshold the header compares against.
            GeometryReader { proxy in
                Color.clear
                    .onAppear { navBarBottom = proxy.frame(in: .global).minY }
                    .onChange(of: proxy.frame(in: .global).minY) { _, newValue in
                        navBarBottom = newValue
                    }
            }
        }
        .task {
            await model.load(id: person.id)
        }
    }

    // MARK: - Filmography grouping

    /// The person's credits grouped into consecutive per-year buckets. Credits
    /// arrive already sorted newest-first, so grouping in order yields sections
    /// in descending year order with undated (upcoming) credits last.
    private var creditsByYear: [(year: Int?, movies: [Movie])] {
        let credits = current.credits ?? []
        var groups: [(year: Int?, movies: [Movie])] = []
        for movie in credits {
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
        guard let year else { return "Upcoming" }
        return String(year)
    }
}

#Preview {
    NavigationStack {
        PersonDetailView(person: .preview)
            .movieTrackerDestinations()
    }
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}
