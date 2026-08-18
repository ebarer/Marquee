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
    /// Fade artwork that has to be fetched, for backdrops where the arrival is large and abrupt.
    /// Artwork already on hand is never faded, whatever this says.
    var fadesIn: Bool = false
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: Image?
    @State private var loadedURL: URL?
    /// Whether the artwork was on hand when this view appeared, decided once. Fading something
    /// we could have drawn for the push reads as a flash.
    @State private var readyOnAppear: Bool?

    private var displayed: Image? {
        if let image { return image }
        if let url, let cached = RemoteImageCache.shared.image(for: url) {
            return Image(uiImage: cached)
        }
        return nil
    }

    /// Showable now, or decodable from the URL cache without a fetch.
    private var artworkOnHand: Bool {
        guard let url else { return false }
        if RemoteImageCache.shared.image(for: url) != nil { return true }
        return URLCache.shared.cachedResponse(for: URLRequest(url: url)) != nil
    }

    private var fadesArrival: Bool { fadesIn && readyOnAppear == false }

    var body: some View {
        ZStack {
            // Hidden once artwork covers it: at fractional sizes it tints the image's edge
            // pixels, ringing the poster in grey. Kept under a fading arrival, which needs it.
            placeholder()
                .opacity(displayed == nil || fadesArrival ? 1 : 0)
            if let displayed {
                displayed
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        // The animation belongs on the container: it's the arrival of the layer that fades, and
        // an opacity set in the same update a view is inserted has nothing to animate from.
        .animation(fadesArrival ? .easeInOut(duration: 0.3) : nil, value: displayed == nil)
        // Only asked when it can matter: deciding it reads URLCache, a synchronous disk hit.
        .onAppear { if fadesIn, readyOnAppear == nil { readyOnAppear = artworkOnHand } }
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
        if loadedURL != url, let ui = RemoteImageCache.shared.image(for: url) {
            apply(ui, for: url, animated: false)
        }
        // Before reading URLCache, which is a synchronous disk hit: a row whose artwork is decoded
        // and already revalidated has nothing left to do, and dozens of rows appear at once.
        if loadedURL == url, RemoteImageRevalidation.done.contains(url) { return }

        let cachedBefore = await Self.cachedData(url)

        if loadedURL != url, let bytes = cachedBefore, let ui = await Self.decode(bytes) {
            apply(ui, for: url, animated: false)
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
        // `animated` is a swap of artwork already on screen; a first arrival is faded in by the
        // layer's own transition instead.
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) { image = newImage }
        } else {
            image = newImage
        }
        loadedURL = url
    }

    private static func cachedData(_ url: URL) async -> Data? {
        // Off the main actor: reading the cache goes to disk, and a screenful of rows asking at
        // once stalls whatever is animating.
        await Task.detached(priority: .userInitiated) {
            URLCache.shared.cachedResponse(for: URLRequest(url: url))?.data
        }.value
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
