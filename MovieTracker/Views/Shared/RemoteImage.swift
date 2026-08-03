//
//  RemoteImage.swift
//  MovieTracker
//

import SwiftUI
import UIKit

/// Decoded-image cache keyed by URL. `URLCache` only holds encoded bytes, so
/// re-decoding on every appearance is what made images visibly "fault in".
final class RemoteImageCache: @unchecked Sendable {
    static let shared = RemoteImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func insert(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
    func removeAll() { cache.removeAllObjects() }
}

@MainActor
private enum RemoteImageRevalidation {
    static var done: Set<URL> = []
}

/// A remote image that fills its frame. Cached bytes render instantly (and offline);
/// when online it revalidates once per session and cross-fades in changed artwork.
/// Callers supply the placeholder (and any clip shape).
struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: Image?
    @State private var loadedURL: URL?

    /// Falls back to a synchronous memory hit so a return visit paints on the first frame.
    private var displayed: Image? {
        if let image { return image }
        if let url, let cached = RemoteImageCache.shared.image(for: url) {
            return Image(uiImage: cached)
        }
        return nil
    }

    var body: some View {
        ZStack {
            if let displayed {
                displayed
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            image = nil
            loadedURL = nil
            return
        }
        let cachedBefore = Self.cachedData(url)

        if loadedURL != url {
            if let ui = RemoteImageCache.shared.image(for: url) {
                apply(ui, for: url, animated: false)
            } else if let bytes = cachedBefore, let ui = await Self.decode(bytes) {
                apply(ui, for: url, animated: false)
            }
        }
        let shown = (loadedURL == url)

        // Revalidate once per session; a failure (offline) stays un-marked to retry later.
        if shown && RemoteImageRevalidation.done.contains(url) { return }
        guard let latest = await Self.fetchLatest(url) else { return }
        RemoteImageRevalidation.done.insert(url)

        if !shown || latest != cachedBefore, let ui = await Self.decode(latest) {
            apply(ui, for: url, animated: shown)
        }
    }

    private func apply(_ uiImage: UIImage, for url: URL, animated: Bool) {
        RemoteImageCache.shared.insert(uiImage, for: url)
        let newImage = Image(uiImage: uiImage)
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) { image = newImage }
        } else {
            image = newImage
        }
        loadedURL = url
    }

    private static func cachedData(_ url: URL) -> Data? {
        URLCache.shared.cachedResponse(for: URLRequest(url: url))?.data
    }

    private static func fetchLatest(_ url: URL) async -> Data? {
        let request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData)
        return try? await URLSession.shared.data(for: request).0
    }

    private static func decode(_ data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return await image.byPreparingForDisplay() ?? image
    }
}
