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
    }
}
