//
//  ShowDetailDisclosureTests.swift
//  MarqueeTests
//
//  The show page's half of `MovieDetailDisclosureTests`: a field is only reported empty once a
//  full payload says so — never because a list row's record arrived, or because a fetch stopped.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Marquee

@MainActor
@Suite(.serialized) struct ShowDetailDisclosureTests {
    private let cache = MediaCacheStore.shared

    /// The shape a list row or search result hands over: no seasons, status, network or cast.
    private func leanRecord(id: Int = 77) -> Show {
        var show = Show(id: id, name: "S")
        show.poster = "/p.jpg"
        show.firstAirDate = .utc(2021, 9, 12)
        show.rating = 8.4
        show.watchByRegion = [:]
        return show
    }

    private var detailJSON: String {
        #"""
        {"id":77,"name":"S","overview":"The full synopsis.","status":"Ended",
         "last_air_date":"2023-06-01",
         "genres":[{"id":1,"name":"Drama"}],
         "networks":[{"id":2,"name":"Apple TV+"}],
         "seasons":[{"id":9,"season_number":1,"episode_count":8,"name":"Season 1"}],
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

    @Test func leanSeedDisclosesNothing() async {
        await cache.clear()
        MediaMemoryCache.removeAll()

        let model = ShowDetailModel(seed: leanRecord())
        #expect(model.show?.isDetailPayload == false)
        // The seed's own shape says nothing either: an empty provider map and no seasons are
        // exactly what a list row carries.
        #expect(model.show?.seasons.isEmpty == true)
    }

    @Test func payloadDisclosesFields() async {
        await cache.clear()
        MediaMemoryCache.removeAll()
        stubDetail()
        defer { URLProtocolStub.remove() }

        let model = ShowDetailModel(seed: leanRecord())
        #expect(model.show?.isDetailPayload == false)

        await model.load(id: 77)

        #expect(model.show?.isDetailPayload == true)
        #expect(model.show?.networks == ["Apple TV+"])
        #expect(model.show?.seasonCount == 1)
    }

    @Test func failedFetchDisclosesNothingAndRetries() async {
        await cache.clear()
        MediaMemoryCache.removeAll()
        stubFailure()

        let model = ShowDetailModel(seed: leanRecord())
        await model.load(id: 77)
        #expect(model.show?.isDetailPayload == false)   // a failure is not an answer

        URLProtocolStub.remove()
        stubDetail()
        defer { URLProtocolStub.remove() }

        await model.load(id: 77)             // the retry the view's `.task` makes
        #expect(model.show?.isDetailPayload == true)
        #expect(model.show?.seasonCount == 1)
    }

    @Test func revisitingSkipsTheUndisclosedState() async {
        await cache.clear()
        MediaMemoryCache.removeAll()
        stubDetail()
        defer { URLProtocolStub.remove() }

        await ShowDetailModel(seed: leanRecord()).load(id: 77)

        // Pushed again in the same session: complete from the first frame, nothing faults in.
        let revisit = ShowDetailModel(seed: leanRecord())
        #expect(revisit.show?.isDetailPayload == true)
        #expect(revisit.show?.networks == ["Apple TV+"])
    }

    @Test func aSummaryFetchIsNotAPayload() async {
        stubDetail()
        defer { URLProtocolStub.remove() }

        // `/tv/{id}` without the appended credits, videos and providers: the same shape, so only
        // `getShow` may claim completeness.
        let summary = try? await TMDBWrapper.showSummary(id: 77)
        #expect(summary?.isDetailPayload == false)
    }
}
