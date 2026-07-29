//
//  SearchView.swift
//  MovieTracker
//
//  Unified search over movies and people with a scope selector.
//  Replaces both SearchTableViewController and GlobalSearchResultsController.
//

import SwiftUI

@MainActor
@Observable
final class SearchModel {
    enum Scope: String, CaseIterable, Identifiable {
        case movies = "Movies"
        case people = "People"

        var id: String { rawValue }

        var placeholder: String {
            switch self {
            case .movies: return "Enter movie title"
            case .people: return "Enter name of cast/crew"
            }
        }
    }

    var scope: Scope = .movies
    private(set) var movies: [Movie] = []
    private(set) var people: [Person] = []

    private var searchTask: Task<Void, Never>?

    func search(_ rawQuery: String) {
        searchTask?.cancel()

        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            movies = []
            people = []
            return
        }

        searchTask = Task {
            do {
                switch scope {
                case .movies:
                    let result = try await TMDBWrapper.searchForMovies(query: query)
                    guard !Task.isCancelled else { return }
                    movies = result.items
                case .people:
                    let result = try await TMDBWrapper.searchForPeople(query: query)
                    guard !Task.isCancelled else { return }
                    people = result.items
                }
            } catch {
                if !Task.isCancelled {
                    print("Search error: \(error)")
                }
            }
        }
    }
}

struct SearchView: View {
    @State private var model = SearchModel()
    @State private var query = ""

    var body: some View {
        List {
            switch model.scope {
            case .movies:
                ForEach(model.movies, id: \.id) { movie in
                    NavigationLink(value: movie) {
                        MovieRow(movie: movie)
                    }
                }
            case .people:
                ForEach(model.people, id: \.id) { person in
                    NavigationLink(value: person) {
                        PersonRow(person: person)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Search")
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: model.scope.placeholder
        )
        .searchScopes($model.scope) {
            ForEach(SearchModel.Scope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .onChange(of: query) { _, newValue in
            model.search(newValue)
        }
        .onChange(of: model.scope) { _, _ in
            model.search(query)
        }
    }
}
