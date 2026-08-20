//
//  Error+Cancellation.swift
//  MovieTracker
//

import Foundation

extension Error {
    // URLSession reports its own cancellation error rather than `CancellationError`.
    var isCancellation: Bool {
        self is CancellationError || (self as? URLError)?.code == .cancelled
    }
}
