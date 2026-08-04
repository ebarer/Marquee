//
//  FeaturedModelTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@MainActor
@Suite(.serialized) struct FeaturedModelTests {
    /// Serves page 1 as [1,2] and page 2 as [2,3] (overlap tests dedup), total 2 pages.
    private func installPagedStub() {
        URLProtocolStub.install { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "page" }?.value ?? "1"
            let ids = page == "2" ? [2, 3] : [1, 2]
            let items = ids.map { #"{"id":\#($0),"title":"M\#($0)"}"# }.joined(separator: ",")
            return (Data(#"{"results":[\#(items)],"total_results":3,"total_pages":2}"#.utf8), 200)
        }
    }

    @Test func startLoadsFirstPage() async {
        installPagedStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.start(.popular)
        #expect(model.movies.map(\.id) == [1, 2])
        #expect(model.isLoading == false)
    }

    @Test func startIsNoOpWhenAlreadyLoaded() async {
        installPagedStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.start(.popular)
        let count = URLProtocolStub.requestedURLs.count
        await model.start(.nowPlaying)  // ignored: movies already loaded
        #expect(URLProtocolStub.requestedURLs.count == count)
    }

    @Test func paginationAppendsAndDedupes() async {
        installPagedStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.start(.popular)
        await model.loadMoreIfNeeded(currentItem: model.movies.last!)
        #expect(model.movies.map(\.id) == [1, 2, 3])  // id 2 not duplicated
    }

    @Test func changeResetsAndReloads() async {
        installPagedStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.start(.popular)
        await model.loadMoreIfNeeded(currentItem: model.movies.last!)
        await model.change(to: .comingSoon)
        #expect(model.movies.map(\.id) == [1, 2])  // back to a fresh first page
    }

    @Test func stopsPagingPastLastPage() async {
        URLProtocolStub.install { _ in
            (Data(#"{"results":[{"id":1,"title":"A"}],"total_results":1,"total_pages":1}"#.utf8), 200)
        }
        defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.start(.popular)
        let count = URLProtocolStub.requestedURLs.count
        await model.loadMoreIfNeeded(currentItem: model.movies.last!)
        #expect(URLProtocolStub.requestedURLs.count == count)  // no further fetch
    }
}
