//
//  SearchModel.swift
//  MovieTracker
//
//  Debounced, cancellable search over movies and people with a scope selector.
//  Also tracks recent search terms, persisted across launches.
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
    var query = ""
    private(set) var movies: [Movie] = []
    private(set) var people: [Person] = []

    /// Recent search terms, most-recent first, persisted across launches.
    private(set) var recentSearches: [String] = []

    private var searchTask: Task<Void, Never>?

    private let recentsKey = "recentSearches"
    private let maxRecents = 15

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
    }

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

    // MARK: - Recent searches

    /// Records the current query as a recent search, moving it to the top and
    /// removing any duplicate. Call when the user commits a search (submits) or
    /// opens a result.
    func commit() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > maxRecents {
            recentSearches = Array(recentSearches.prefix(maxRecents))
        }
        persistRecents()
    }

    /// Re-runs a saved search term by populating the field, exactly as if the
    /// user had retyped it, and elevates it to the top of the recents list.
    func selectRecent(_ term: String) {
        query = term
        search(term)
        commit()
    }

    func removeRecent(_ term: String) {
        recentSearches.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        persistRecents()
    }

    func clearRecents() {
        recentSearches = []
        persistRecents()
    }

    private func persistRecents() {
        UserDefaults.standard.set(recentSearches, forKey: recentsKey)
    }
}
