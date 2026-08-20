//
//  MarqueeSchema.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// The one list of CloudKit-backed models; everything that builds a container reads it.
enum MarqueeSchema {
    static let models: [any PersistentModel.Type] = [
        MediaItem.self, MediaList.self, ListEntry.self,
        WatchedEpisode.self, WatchedSeason.self, TrackedSeason.self,
    ]

    static var schema: Schema { Schema(models) }
}
