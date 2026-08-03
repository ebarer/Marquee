//
//  MovieDetailModel.swift
//  MovieTracker
//
//  Loads the full movie for the detail screen and derives a poster-average
//  tint used to theme the screen.
//

import SwiftUI

@MainActor
@Observable
final class MovieDetailModel {
    private(set) var movie: Movie?
    private(set) var tint: Color = .appAccent
    /// TMDB "recommendations" for the current movie, shown as a horizontal
    /// strip. Excludes the movie itself defensively.
    private(set) var recommendations: [Movie] = []
    /// The other films in this movie's franchise (chronological), shown as a
    /// horizontal strip. Empty when the movie isn't part of a collection.
    private(set) var collection: [Movie] = []

    private var loaded = false

    func load(id: Int) async {
        guard !loaded else { return }
        loaded = true
        do {
            let full = try await TMDBWrapper.getMovie(id: id)
            movie = full
            if let url = full.posterURL(.w342),
               let data = try? await TMDBWrapper.imageData(from: url) {
                tint = Color.averageColor(from: data)
            }
        } catch {
            print("Movie detail load error: \(error)")
        }

        // Load the franchise members if this movie belongs to a collection.
        if let franchise = movie?.collection {
            do {
                collection = try await TMDBWrapper.getCollection(id: franchise.id)
                    .filter { $0.id != id }
            } catch {
                print("Movie collection load error: \(error)")
            }
        }

        // Load recommendations separately so a failure here doesn't block the
        // main detail content.
        do {
            let page = try await TMDBWrapper.movieRecommendations(id: id)
            recommendations = page.items.filter { $0.id != id }
        } catch {
            print("Movie recommendations load error: \(error)")
        }
    }
}
