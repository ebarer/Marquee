//
//  UITestHooks.swift
//  MovieTracker
//

import Foundation

/// Launch-argument hooks that make loading states observable to the UI tests. Without them a
/// cached title lands complete on the first frame and there's no loading state left to assert on.
enum UITestHooks {
    /// Wipe the caches at launch, so a detail push starts from the lean record a list row carries.
    static var resetsCaches: Bool { flag("-uiTestResetCaches") }

    /// Hold the detail request back, widening the window where fields are legitimately unknown.
    static var detailDelay: Duration? {
        guard flag("-uiTestSlowDetail") else { return nil }
        return .seconds(3)
    }

    private static func flag(_ name: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(name)
    }
}
