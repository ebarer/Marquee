//
//  WatchListView.swift
//  MovieTracker
//
//  Coming Soon movies grouped into sections by release month/year.
//  Replaces MovieListTableViewController.
//

import SwiftUI

@MainActor
@Observable
final class WatchListModel {
    struct MonthSection: Identifiable {
        let id: DateComponents
        let title: String
        let movies: [Movie]
    }

    private(set) var sections: [MonthSection] = []
    private(set) var isLoading = false

    func load() async {
        guard sections.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await TMDBWrapper.moviesComingSoon(page: 1)
            sections = Self.group(result.items)
        } catch {
            print("Watch List load error: \(error)")
        }
    }

    /// Groups movies by release month/year, sorted chronologically.
    static func group(_ movies: [Movie]) -> [MonthSection] {
        let grouped = Dictionary(grouping: movies) { movie -> DateComponents in
            let date = movie.releaseDate ?? Date()
            return Calendar.current.dateComponents([.year, .month], from: date)
        }

        let sortedKeys = grouped.keys.sorted { a, b in
            (a.year ?? 0, a.month ?? 0) < (b.year ?? 0, b.month ?? 0)
        }

        return sortedKeys.map { key in
            let movies = (grouped[key] ?? []).sorted {
                ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture)
            }
            let title = Calendar.current.date(from: key)
                .map { DateFormatter.sectionHeader.string(from: $0) } ?? ""
            return MonthSection(id: key, title: title, movies: movies)
        }
    }
}

struct WatchListView: View {
    @State private var model = WatchListModel()

    var body: some View {
        List {
            ForEach(model.sections) { section in
                Section(section.title) {
                    ForEach(section.movies, id: \.id) { movie in
                        NavigationLink(value: movie) {
                            MovieRow(movie: movie)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Watch List")
        .overlay {
            if model.isLoading && model.sections.isEmpty {
                ProgressView()
            }
        }
        .task {
            await model.load()
        }
    }
}
