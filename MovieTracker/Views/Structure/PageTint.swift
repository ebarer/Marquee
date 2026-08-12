//
//  PageTint.swift
//  MovieTracker
//

import SwiftUI

/// The tint of the page currently on screen, published up out of the navigation stack so
/// the shell around it (the tab bar) can share it. Detail screens publish their
/// poster-derived colour, list screens their list colour; anything that publishes nothing
/// leaves the app accent in place.
struct PageTintKey: PreferenceKey {
    static let defaultValue: Color? = nil

    /// Last writer wins, but a nil never erases a colour — a pushed screen's tint survives
    /// the siblings around it that publish nothing.
    static func reduce(value: inout Color?, nextValue: () -> Color?) {
        value = nextValue() ?? value
    }
}

extension View {
    /// Publish this page's tint to the surrounding shell.
    func pageTint(_ color: Color) -> some View {
        preference(key: PageTintKey.self, value: color)
    }

    /// Report the tint published by the page inside `self`. The caller decides where to
    /// apply it, so a container can pick between several pages' tints.
    func onPageTintChange(_ action: @MainActor @escaping (Color?) -> Void) -> some View {
        onPreferenceChange(PageTintKey.self, perform: action)
    }
}

// The shell in miniature: the stack's root publishes green (a list) and the screen pushed
// on top of it publishes red (a detail). The tab bar should read red — the frontmost page
// wins, and its tint crosses both the NavigationStack and the Tab boundary.
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
