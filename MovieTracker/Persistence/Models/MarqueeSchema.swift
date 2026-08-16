//
//  MarqueeSchema.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// The one list of CloudKit-backed models. Everything that builds a container reads it, so a new
/// `@Model` can't reach the store without tripping `SchemaPrimerCoverageTests`.
enum MarqueeSchema {
    static let models: [any PersistentModel.Type] = [
        MediaItem.self, MediaList.self, ListEntry.self,
        WatchedEpisode.self, WatchedSeason.self, TrackedSeason.self,
    ]

    static var schema: Schema { Schema(models) }
}
