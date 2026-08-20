//
//  MovieRuntimeStore.swift
//  MovieTracker
//

import Foundation

/// Session memo for a movie's runtime, which /search/* and a person's credits both omit.
@MainActor
final class MovieRuntimeStore {
    static let shared = MovieRuntimeStore()

    private var resolved: [Int: Int] = [:]
    private var tasks: [Int: Task<Int?, Never>] = [:]

    func runtime(for id: Int) async -> Int? {
        if let memoed = resolved[id] { return memoed > 0 ? memoed : nil }
        if let inFlight = tasks[id] { return await inFlight.value }

        let task = Task<Int?, Never> {
            if let cached = await MediaCacheStore.shared.load(id: id)?.movie.runtime {
                return cached
            }
            return try? await TMDBWrapper.movieRuntime(id: id)
        }
        tasks[id] = task
        let result = await task.value
        tasks[id] = nil
        if let result { resolved[id] = result }
        return result
    }
}
