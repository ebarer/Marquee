//
//  PosterStatus.swift
//  MovieTracker
//

import SwiftUI

/// A title's tracking state as drawn over its poster art.
enum PosterStatus {
    case watched
    /// A series with some — but not all — episodes watched.
    case partial
    case watchList

    var symbol: String {
        switch self {
        case .watched: return "checkmark.circle.fill"
        case .partial: return "circle.tophalf.filled"
        case .watchList: return "bookmark.fill"
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .watched: return 18
        case .partial: return 17
        case .watchList: return 15
        }
    }

    var verticalNudge: CGFloat {
        switch self {
        case .watched: return -1
        case .partial, .watchList: return 0
        }
    }
}
