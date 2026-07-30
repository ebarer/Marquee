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
    @FocusState private var searchFocused: Bool

    var body: some View {
        List {
            switch model.scope {
            case .movies:
                ForEach(Array(model.movies.enumerated()), id: \.element.id) { index, movie in
                    NavigationLink(value: movie) {
                        MovieRow(movie: movie)
                    }
                    .listRowSeparator(index == 0 ? .hidden : .automatic, edges: .top)
                    .listRowSeparator(index == model.movies.count - 1 ? .hidden : .automatic, edges: .bottom)
                }
            case .people:
                ForEach(Array(model.people.enumerated()), id: \.element.id) { index, person in
                    NavigationLink(value: person) {
                        PersonRow(person: person)
                    }
                    .listRowSeparator(index == 0 ? .hidden : .automatic, edges: .top)
                    .listRowSeparator(index == model.people.count - 1 ? .hidden : .automatic, edges: .bottom)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: model.scope.placeholder
        )
        .searchFocused($searchFocused)
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
        .onAppear {
            // Activate the search field as soon as the tab appears.
            searchFocused = true
        }
    }
}
