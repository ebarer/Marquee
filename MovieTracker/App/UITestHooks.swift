//
//  UITestHooks.swift
//  MovieTracker
//

import Foundation

/// Launch-argument hooks that make loading states observable to the UI tests.
enum UITestHooks {
    static var resetsCaches: Bool { flag("-uiTestResetCaches") }

    static var detailDelay: Duration? {
        guard flag("-uiTestSlowDetail") else { return nil }
        return .seconds(3)
    }

    private static func flag(_ name: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(name)
    }
}
