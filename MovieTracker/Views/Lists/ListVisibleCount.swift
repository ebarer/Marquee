//
//  ListVisibleCount.swift
//  MovieTracker
//

import SwiftUI

/// How many titles a list screen is showing, published up so a shell that owns the title can put it there.
struct ListVisibleCountKey: PreferenceKey {
    static let defaultValue: Int? = nil

    // A nil never erases a count: a sibling that publishes nothing can't blank the title.
    static func reduce(value: inout Int?, nextValue: () -> Int?) {
        value = nextValue() ?? value
    }
}

extension View {
    func listVisibleCount(_ count: Int) -> some View {
        preference(key: ListVisibleCountKey.self, value: count)
    }

    func onListVisibleCountChange(_ action: @MainActor @escaping (Int?) -> Void) -> some View {
        onPreferenceChange(ListVisibleCountKey.self, perform: action)
    }
}
