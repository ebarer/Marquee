//
//  RemoteImage.swift
//  MovieTracker
//

import SwiftUI
import UIKit

/// Decoded-image cache keyed by URL. `URLCache` only holds encoded bytes, so
/// without this, re-decoding on every appearance makes images visibly "fault in".
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

/// A remote image that fills its frame, revalidating once per session and
/// cross-fading in changed artwork. Callers supply the placeholder.
struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: Image?
    @State private var loadedURL: URL?

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
        // In previews, resolve bundled sample artwork by name and never hit the network,
        // so canvas previews render real posters/backdrops offline and deterministically.
        if Self.isPreview {
            image = UIImage(named: url.deletingPathExtension().lastPathComponent).map(Image.init(uiImage:))
            loadedURL = url
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

    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
