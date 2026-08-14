//
//  Error+Cancellation.swift
//  MovieTracker
//

import Foundation

extension Error {
    /// A dropped request rather than a real failure: the caller should expect a retry, not
    /// treat what it has as the final answer. `URLSession` reports its own, not `CancellationError`.
    var isCancellation: Bool {
        self is CancellationError || (self as? URLError)?.code == .cancelled
    }
}
