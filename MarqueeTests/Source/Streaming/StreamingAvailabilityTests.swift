//
//  StreamingAvailabilityTests.swift
//  MarqueeTests
//

import Testing
@testable import Marquee

@Suite struct StreamingAvailabilityTests {
    private func availability(_ ids: [Int]) -> WatchAvailability {
        WatchAvailability(providers: ids.map { WatchProvider(id: $0, name: "Service \($0)",
                                                            logoPath: nil) },
                          justWatchLink: nil)
    }

    private func resolve(_ availability: WatchAvailability?, scope: StreamingScope,
                         selected: Set<Int> = []) -> StreamingResolution {
        StreamingAvailability.resolve(availability, scope: scope,
                                      selected: SelectedProviders(selected))
    }

    @Test func nothingCachedReadsUnavailable() {
        let resolved = resolve(nil, scope: .mine)
        #expect(resolved.verdict == .unavailable)
        #expect(resolved.groups.isEmpty)
    }

    @Test func purchaseOnlyProvidersDoNotCountAsStreaming() {
        let resolved = resolve(availability([2, 10]), scope: .all)
        #expect(resolved.verdict == .unavailable)
    }

    @Test func anEmptySelectionKeepsEveryService() {
        for scope in StreamingScope.allCases {
            let resolved = resolve(availability([8, 337]), scope: scope)
            #expect(resolved.verdict == .available)
            #expect(resolved.groups.count == 2)
        }
    }

    @Test func myServicesSeparatesOffMyServicesFromUnavailable() {
        let resolved = resolve(availability([8, 337]), scope: .mine, selected: [350])
        #expect(resolved.verdict == .offMyServices)
        #expect(resolved.groups.isEmpty)
    }

    // Widening the scope shows every service without rewording where the title actually streams.
    @Test func allServicesKeepsTheWordingAndShowsEveryService() {
        let resolved = resolve(availability([8, 337]), scope: .all, selected: [350])
        #expect(resolved.verdict == .offMyServices)
        #expect(resolved.groups.count == 2)
    }

    @Test func allServicesStillReadsAvailableWhenOneIsMine() {
        let resolved = resolve(availability([8, 337]), scope: .all, selected: [8])
        #expect(resolved.verdict == .available)
        #expect(resolved.groups.count == 2)
    }

    @Test func myServicesKeepsOnlyTheSelectedGroups() {
        let resolved = resolve(availability([8, 337]), scope: .mine, selected: [8])
        #expect(resolved.verdict == .available)
        #expect(resolved.groups.map(\.id) == [8])
    }

    @Test func everyVerdictNamesItself() {
        #expect(StreamingVerdict.available.title == "Available to Stream")
        #expect(StreamingVerdict.offMyServices.title == "Available on Other Services")
        #expect(StreamingVerdict.unavailable.title == "Unavailable to Stream")
    }
}
