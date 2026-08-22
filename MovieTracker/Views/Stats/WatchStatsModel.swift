//
//  WatchStatsModel.swift
//  MovieTracker
//

import SwiftUI

@MainActor
@Observable
final class WatchStatsModel {
    private(set) var stats = WatchStats()
    private(set) var isLoading = true

    var scope: WatchStats.Scope = .allTime

    func load(store: PersistenceCoordinator?) async {
        guard let store else {
            isLoading = false
            return
        }
        let loaded = await store.stats(scope: scope)
        guard !Task.isCancelled else { return }
        stats = loaded
        isLoading = false
    }

    static func preview(_ stats: WatchStats) -> WatchStatsModel {
        let model = WatchStatsModel()
        model.stats = stats
        model.isLoading = false
        model.scope = stats.scope
        return model
    }
}
