//
//  MovieDetailModel.swift
//  MovieTracker
//

import SwiftUI

@MainActor
@Observable
final class MovieDetailModel {
    private(set) var movie: Movie?
    private(set) var tint: Color = .appAccent
    private(set) var recommendations: [Movie] = []
    private(set) var collection: [Movie] = []

    private var loaded = false

    func load(id: Int) async {
        guard !loaded else { return }
        loaded = true

        if let cached = await MediaCacheStore.shared.load(id: id) {
            movie = cached.movie
            if let color = cached.color { tint = color }
        }

        do {
            let full = try await TMDBWrapper.getMovie(id: id)
            movie = full
            var freshTint = tint
            if let url = full.posterURL(.w342),
               let data = try? await TMDBWrapper.imageData(from: url) {
                freshTint = Color.averageColor(from: data)
            }
            withAnimation(.easeInOut) { tint = freshTint }
            await MediaCacheStore.shared.save(full, tint: freshTint)
        } catch {
            print("Movie detail load error: \(error)")
        }

        if let franchise = movie?.collection {
            do {
                collection = try await TMDBWrapper.getCollection(id: franchise.id)
                    .filter { $0.id != id }
            } catch {
                print("Movie collection load error: \(error)")
            }
        }

        do {
            let page = try await TMDBWrapper.movieRecommendations(id: id)
            recommendations = page.items.filter { $0.id != id }
        } catch {
            print("Movie recommendations load error: \(error)")
        }
    }
}
