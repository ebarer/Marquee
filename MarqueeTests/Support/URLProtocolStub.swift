//
//  URLProtocolStub.swift
//  MarqueeTests
//
//  Intercepts URLSession.shared so the TMDB client can be exercised offline.
//

import Foundation

final class URLProtocolStub: URLProtocol {
    /// Maps a request to a canned (data, status). Set before the call under test.
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Data, Int))?
    /// Every request URL seen, for asserting query construction.
    nonisolated(unsafe) static var requestedURLs: [URL] = []

    static func install(_ handler: @escaping (URLRequest) -> (Data, Int)) {
        requestedURLs = []
        self.handler = handler
        URLProtocol.registerClass(URLProtocolStub.self)
    }

    static func remove() {
        URLProtocol.unregisterClass(URLProtocolStub.self)
        handler = nil
        requestedURLs = []
    }

    override class func canInit(with request: URLRequest) -> Bool { handler != nil }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        if let url = request.url { Self.requestedURLs.append(url) }
        guard let handler = Self.handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let (data, status) = handler(request)
        let response = HTTPURLResponse(url: request.url ?? URL(string: "https://x")!,
                                       statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
