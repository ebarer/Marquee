//
//  MovieDetailDisclosureTests.swift
//  MarqueeTests
//
//  What the detail page is allowed to say about a field, and when. A field is only ever
//  reported empty once a full payload says so — never because a lean record arrived, or
//  because a fetch stopped.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Marquee

@MainActor
@Suite(.serialized) struct MovieDetailDisclosureTests {
    private let cache = MediaCacheStore.shared

    /// The shape a Discover or search row hands over: no certification, genres or cast, and an
    /// empty — but not nil — provider map, which is what once passed for a complete payload.
    private func leanRecord(id: Int = 42) -> Movie {
        var movie = makeMovie(id: id, title: "M", poster: "/p.jpg")
        movie.overview = "Straight off the list row."
        movie.rating = 8.6
        movie.watchByRegion = [:]
        return movie
    }

    private var detailJSON: String {
        #"""
        {"id":42,"title":"M","runtime":115,"overview":"The full synopsis.",
         "genres":[{"id":1,"name":"Action"},{"id":2,"name":"Science Fiction"}],
         "watch/providers":{"results":{"US":{"link":"https://x","flatrate":[]}}}}
        """#
    }

    private func stubDetail() {
        URLProtocolStub.install { req in
            if req.url?.host == "image.tmdb.org" {
                let png = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { ctx in
                    UIColor.blue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
                }
                return (png, 200)
            }
            return (Data(detailJSON.utf8), 200)
        }
    }

    private func stubFailure() {
        URLProtocolStub.install { _ in (Data("nope".utf8), 500) }
    }

    @Test func emptyProviderMapIsNotAPayload() {
        // The trap this suite exists for: every endpoint fills `watchByRegion`, so its presence
        // says nothing about whether the rest of the record is there.
        #expect(leanRecord().watchByRegion?.isEmpty == true)
        #expect(leanRecord().isDetailPayload == false)
    }

    @Test func leanSeedDisclosesNothing() async {
        await cache.clear()
        MediaMemoryCache.removeAll()

        #expect(MovieDetailModel(seed: leanRecord()).movie?.isDetailPayload == false)
    }

    @Test func payloadDisclosesFields() async {
        await cache.clear()
        MediaMemoryCache.removeAll()
        stubDetail()
        defer { URLProtocolStub.remove() }

        let model = MovieDetailModel(seed: leanRecord())
        #expect(model.movie?.isDetailPayload == false)

        await model.load(id: 42)

        #expect(model.movie?.isDetailPayload == true)
        #expect(model.movie?.runtime == 115)
        #expect(model.movie?.genres == ["Action", "Science Fiction"])
    }

    @Test func cachedLeanRecordStillDisclosesNothing() async {
        await cache.clear()
        MediaMemoryCache.removeAll()
        // An entry saved before the payload marker existed, so it decodes as unknown.
        await cache.save(leanRecord(), tint: .red)
        stubFailure()
        defer { URLProtocolStub.remove() }

        let model = MovieDetailModel(seed: leanRecord())
        await model.load(id: 42)

        #expect(model.movie?.overview == "Straight off the list row.")   // cached content shows
        #expect(model.movie?.isDetailPayload == false)                   // nothing claimed empty
    }

    @Test func failedFetchDisclosesNothingAndRetries() async {
        await cache.clear()
        MediaMemoryCache.removeAll()
        stubFailure()

        let model = MovieDetailModel(seed: leanRecord())
        await model.load(id: 42)
        #expect(model.movie?.isDetailPayload == false)   // a failure is not an answer

        URLProtocolStub.remove()
        stubDetail()
        defer { URLProtocolStub.remove() }

        await model.load(id: 42)             // the retry the view's `.task` makes
        #expect(model.movie?.isDetailPayload == true)
        #expect(model.movie?.runtime == 115)
    }

    @Test func revisitingSkipsTheUndisclosedState() async {
        await cache.clear()
        MediaMemoryCache.removeAll()
        stubDetail()
        defer { URLProtocolStub.remove() }

        await MovieDetailModel(seed: leanRecord()).load(id: 42)

        // Pushed again in the same session: complete from the first frame, nothing faults in.
        let revisit = MovieDetailModel(seed: leanRecord())
        #expect(revisit.movie?.isDetailPayload == true)
        #expect(revisit.movie?.runtime == 115)
    }

    @Test func detailIsRequestedBeforeRecommendations() async {
        await cache.clear()
        MediaMemoryCache.removeAll()
        stubDetail()
        defer { URLProtocolStub.remove() }

        await MovieDetailModel(seed: leanRecord()).load(id: 42)

        let paths = URLProtocolStub.requestedURLs.map(\.path)
        let detail = paths.firstIndex(of: "/3/movie/42")
        let recommendations = paths.firstIndex(of: "/3/movie/42/recommendations")
        #expect(detail != nil)
        #expect(recommendations != nil)
        if let detail, let recommendations {
            // Cast rides in on the detail payload, and it belongs above recommendations.
            #expect(detail < recommendations)
        }
    }
}
