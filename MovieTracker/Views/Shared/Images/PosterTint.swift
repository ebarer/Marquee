//
//  PosterTint.swift
//  MovieTracker
//

import SwiftUI
import UIKit

/// A poster's dominant colour, memoized per path and served from the image caches first.
@MainActor
enum PosterTint {
    private static var byPath: [String: Color] = [:]

    // The sizes differ only in scale, so whichever the caller already loaded spares a download.
    private static let cachedSizes: [PosterSize] = [.w342, .w185, .w500, .w154, .w92]

    static func cached(forPath path: String?) -> Color? {
        guard let path else { return nil }
        if let known = byPath[path] { return known }
        guard let color = localColor(forPath: path) else { return nil }
        byPath[path] = color
        return color
    }

    static func resolve(forPath path: String?) async -> Color? {
        guard let path else { return nil }
        if let known = cached(forPath: path) { return known }
        // Decode here rather than leaning on `dominantColor(from: Data)`: its accent fallback
        // for undecodable bytes would look like a real tint and overwrite a cached one.
        guard let url = TMDBWrapper.imageURL(path: path, size: PosterSize.w342.rawValue),
              let data = try? await TMDBWrapper.imageData(from: url),
              let image = UIImage(data: data) else { return nil }
        let color = Color.dominantColor(from: image)
        byPath[path] = color
        return color
    }

    private static func localColor(forPath path: String) -> Color? {
        for size in cachedSizes {
            guard let url = TMDBWrapper.imageURL(path: path, size: size.rawValue) else { continue }
            if let image = RemoteImageCache.shared.image(for: url) {
                return Color.dominantColor(from: image)
            }
            if let data = URLCache.shared.cachedResponse(for: URLRequest(url: url))?.data {
                return Color.dominantColor(from: data)
            }
        }
        return nil
    }
}
