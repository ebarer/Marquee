//
//  PageTint.swift
//  MovieTracker
//

import SwiftUI

/// The on-screen page's tint, published up so the shell can share it.
struct PageTintKey: PreferenceKey {
    static let defaultValue: Color? = nil

    // A nil never erases a colour, so a pushed screen's tint survives siblings that publish nothing.
    static func reduce(value: inout Color?, nextValue: () -> Color?) {
        value = nextValue() ?? value
    }
}

extension View {
    func pageTint(_ color: Color) -> some View {
        preference(key: PageTintKey.self, value: color)
    }

    func onPageTintChange(_ action: @MainActor @escaping (Color?) -> Void) -> some View {
        onPreferenceChange(PageTintKey.self, perform: action)
    }
}

#Preview("Tab bar follows the frontmost page") {
    @Previewable @State var tint: Color?

    TabView {
        Tab("Lists", systemImage: "checklist") {
            NavigationStack(path: .constant(NavigationPath(["detail"]))) {
                Color.appBackground
                    .pageTint(.green)
                    .navigationDestination(for: String.self) { _ in
                        Color.appBackground
                            .overlay {
                                VStack(spacing: 16) {
                                    Text("Detail publishes red").foregroundStyle(.white)
                                    Circle().fill(.tint).frame(width: 60, height: 60)
                                }
                            }
                            .pageTint(.red)
                    }
            }
            .onPageTintChange { tint = $0 }
        }
        Tab("Discover", systemImage: "film") {
            Color.appBackground
        }
    }
    .tint(tint ?? .appAccent)
    .preferredColorScheme(.dark)
}
