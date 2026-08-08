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

    @Test func loadFetchesFirstPage() async {
        installPagedStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.load(.popular)
        #expect(model.movies.map(\.id) == [1, 2])
        #expect(model.isLoading == false)
    }

    @Test func loadIsNoOpForSameCollectionAlreadyLoaded() async {
        installPagedStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.load(.popular)
        let count = URLProtocolStub.requestedURLs.count
        await model.load(.popular)  // ignored: same collection already loaded
        #expect(URLProtocolStub.requestedURLs.count == count)
    }

    @Test func paginationAppendsAndDedupes() async {
        installPagedStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.load(.popular)
        await model.loadMoreIfNeeded(currentItem: model.movies.last!)
        #expect(model.movies.map(\.id) == [1, 2, 3])  // id 2 not duplicated
    }

    @Test func loadingDifferentCollectionResetsAndReloads() async {
        installPagedStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.load(.popular)
        await model.loadMoreIfNeeded(currentItem: model.movies.last!)
        await model.load(.comingSoon)
        #expect(model.movies.map(\.id) == [1, 2])  // back to a fresh first page
    }

    @Test func stopsPagingPastLastPage() async {
        URLProtocolStub.install { _ in
            (Data(#"{"results":[{"id":1,"title":"A"}],"total_results":1,"total_pages":1}"#.utf8), 200)
        }
        defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.load(.popular)
        let count = URLProtocolStub.requestedURLs.count
        await model.loadMoreIfNeeded(currentItem: model.movies.last!)
        #expect(URLProtocolStub.requestedURLs.count == count)  // no further fetch
    }

    // MARK: - TV shelves

    /// Same paging shape as the movie stub, but with `name` so `ShowRaw` decodes.
    private func installShowStub() {
        URLProtocolStub.install { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "page" }?.value ?? "1"
            let ids = page == "2" ? [2, 3] : [1, 2]
            let items = ids.map { #"{"id":\#($0),"name":"S\#($0)"}"# }.joined(separator: ",")
            return (Data(#"{"results":[\#(items)],"total_results":3,"total_pages":2}"#.utf8), 200)
        }
    }

    @Test func showShelfLoadsShows() async {
        installShowStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.load(.showsPopular)
        #expect(model.shows.map(\.id) == [1, 2])
        #expect(model.movies.isEmpty)
    }

    @Test func showShelfPaginationAppendsAndDedupes() async {
        installShowStub(); defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.load(.showsAiringToday)
        await model.loadMoreIfNeeded(currentShow: model.shows.last!)
        #expect(model.shows.map(\.id) == [1, 2, 3])  // id 2 not duplicated
    }

    @Test func switchingFromMovieToShowCollectionResets() async {
        URLProtocolStub.install { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "page" }?.value ?? "1"
            let ids = page == "2" ? [2, 3] : [1, 2]
            let items = ids.map { #"{"id":\#($0),"title":"M\#($0)","name":"S\#($0)"}"# }.joined(separator: ",")
            return (Data(#"{"results":[\#(items)],"total_results":3,"total_pages":2}"#.utf8), 200)
        }
        defer { URLProtocolStub.remove() }
        let model = FeaturedModel()
        await model.load(.popular)
        #expect(model.movies.map(\.id) == [1, 2])
        await model.load(.showsPopular)
        #expect(model.shows.map(\.id) == [1, 2])
        #expect(model.movies.isEmpty)   // movie shelf cleared on switch
    }
}
