//
//  MovieDetailModelTests.swift
//  MarqueeTests
//
//  The cache-first-then-refresh detail flow: show cached content immediately,
//  refresh data + poster tint in the background, and fall back to cache offline.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Marquee

@MainActor
@Suite(.serialized) struct MovieDetailModelTests {
    private let cache = MediaCacheStore.shared

    /// A solid-color PNG, so `Color.averageColor` yields a predictable tint.
    private func png(_ color: UIColor) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { ctx in
            color.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    /// Routes image-host requests to `image`, everything else (the API) to `json`.
    private func install(json: String, image: Data) {
        URLProtocolStub.install { req in
            if req.url?.host == "image.tmdb.org" { return (image, 200) }
            return (Data(json.utf8), 200)
        }
    }

    private func rgba(_ color: Color) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue)
    }

    @Test func refreshUpdatesDataAndPersistsToCache() async {
        await cache.clear()
        await cache.save(makeMovie(id: 42, title: "Old", poster: "/old.jpg"), tint: .red)
        install(json: #"{"id":42,"title":"New","poster_path":"/new.jpg","runtime":100}"#, image: png(.blue))
        defer { URLProtocolStub.remove() }

        let model = MovieDetailModel()
        await model.load(id: 42)

        #expect(model.movie?.title == "New")          // refreshed from the network
        #expect(model.movie?.poster == "/new.jpg")
        let cached = await cache.load(id: 42)
        #expect(cached?.movie.title == "New")          // background write-through
        #expect(cached?.movie.poster == "/new.jpg")
    }

    @Test func cachedContentStandsWhenRefreshFails() async {
        await cache.clear()
        await cache.save(makeMovie(id: 42, title: "Cached", poster: "/c.jpg"), tint: .red)
        // 500 with a non-decodable body -> getMovie throws -> cached values stand.
        URLProtocolStub.install { _ in (Data("nope".utf8), 500) }
        defer { URLProtocolStub.remove() }

        let model = MovieDetailModel()
        await model.load(id: 42)

        #expect(model.movie?.title == "Cached")
        #expect(model.movie?.poster == "/c.jpg")
    }

    @Test func posterChangeRederivesTint() async {
        await cache.clear()
        // Seed a red tint, then serve a blue poster on refresh.
        await cache.save(makeMovie(id: 42, title: "M", poster: "/old.jpg"), tint: .red)
        install(json: #"{"id":42,"title":"M","poster_path":"/new.jpg"}"#, image: png(.blue))
        defer { URLProtocolStub.remove() }

        let model = MovieDetailModel()
        await model.load(id: 42)

        let tint = rgba(model.tint)
        #expect(tint.blue > tint.red)   // tint followed the new (blue) poster
    }
}
