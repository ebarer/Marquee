//
//  MovieDetailDisclosureUITests.swift
//  MarqueeUITests
//
//  The detail page must never report a field empty and then fill it in. Placeholders are hidden
//  from accessibility, so a value element existing means the page has committed to an answer —
//  and that answer has to be the final one.
//

import XCTest

final class MovieDetailDisclosureUITests: XCTestCase {
    private static let ratingCell = "metadata-value-RATING"
    private static let genreCell = "metadata-value-GENRE"
    private static let creditClipsCell = "metadata-value-CREDIT CLIPS"
    private static let verdict = "whereToWatch-verdict"
    private static let noDescription = "No movie description available."

    override func setUp() { continueAfterFailure = false }

    // Empty caches and the detail request held back, or a cached title lands complete with no loading state.
    @MainActor
    private func pushFirstMovie() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetCaches", "-uiTestSlowDetail"]
        app.launch()
        XCTAssertTrue(app.buttons["Discover"].waitForExistence(timeout: 30))

        let card = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No Discover card to open")
        card.tap()
        return app
    }

    @MainActor
    private func record(forSeconds seconds: TimeInterval,
                        _ sample: @MainActor () -> [String: String]) -> [String: [String]] {
        var seen: [String: [String]] = [:]
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            for (key, value) in sample() where !value.isEmpty && seen[key]?.last != value {
                seen[key, default: []].append(value)
            }
        }
        return seen
    }

    private func assertNoFillInAfterEmpty(_ identifier: String, _ seen: [String]) {
        XCTAssertFalse(seen.isEmpty,
                       "\(identifier) never disclosed a value — the test would pass vacuously")

        if let dash = seen.firstIndex(of: "—") {
            let after = Array(seen[(dash + 1)...])
            XCTAssertTrue(after.isEmpty,
                          "\(identifier) reported empty, then disclosed \(after). Sequence: \(seen)")
        }
    }

    @MainActor
    func testNoFieldFillsInAfterReportingEmpty() {
        let app = pushFirstMovie()
        continueAfterFailure = true

        let cells = [Self.ratingCell, Self.genreCell, Self.creditClipsCell, Self.verdict]
        let seen = record(forSeconds: 10) {
            var sample: [String: String] = [:]
            for identifier in cells {
                let element = app.descendants(matching: .any)
                    .matching(identifier: identifier).firstMatch
                if element.exists { sample[identifier] = element.label }
            }
            if app.staticTexts[Self.noDescription].exists {
                sample[Self.noDescription] = Self.noDescription
            }
            return sample
        }

        for cell in [Self.ratingCell, Self.genreCell, Self.creditClipsCell] {
            assertNoFillInAfterEmpty(cell, seen[cell] ?? [])
        }

        let verdicts = seen[Self.verdict] ?? []
        XCTAssertFalse(verdicts.isEmpty, "The streaming verdict never appeared")
        XCTAssertFalse(verdicts.contains("Unavailable to Stream")
                       && verdicts.contains("Available to Stream"),
                       "Streaming verdict flipped mid-load: \(verdicts)")

        if seen[Self.noDescription] != nil {
            XCTAssertTrue(app.staticTexts[Self.noDescription].exists,
                          "Claimed no description, then showed one")
        }
    }
}
