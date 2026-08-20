//
//  DetailNavigation.swift
//  MovieTracker
//

import SwiftUI

private struct OpenDetailKey: EnvironmentKey {
    static let defaultValue: ((AnyHashable) -> Void)? = nil
}

extension EnvironmentValues {
    var openDetail: ((AnyHashable) -> Void)? {
        get { self[OpenDetailKey.self] }
        set { self[OpenDetailKey.self] = newValue }
    }
}

private struct SearchPushKey: EnvironmentKey {
    static let defaultValue: ((AnyHashable) -> Void)? = nil
}

extension EnvironmentValues {
    // A push made straight out of the focused search field skips its animation, so it is deferred a pass.
    var searchPush: ((AnyHashable) -> Void)? {
        get { self[SearchPushKey.self] }
        set { self[SearchPushKey.self] = newValue }
    }
}

private struct CloseModalKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var closeModal: (() -> Void)? {
        get { self[CloseModalKey.self] }
        set { self[CloseModalKey.self] = newValue }
    }
}

private struct ScrollTopKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var scrollTopToken: Int {
        get { self[ScrollTopKey.self] }
        set { self[ScrollTopKey.self] = newValue }
    }
}

private struct ModalRootKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    // Not inherited by pushed screens: they hang off the NavigationStack, not off the root's subtree.
    var isModalRoot: Bool {
        get { self[ModalRootKey.self] }
        set { self[ModalRootKey.self] = newValue }
    }
}

/// A screen with trailing items renders Close itself: `modalDismissable()` applies from outside, and an outer item lands leading.
struct ModalCloseItem: ToolbarContent {
    let close: () -> Void
    var isRoot = false

    var body: some ToolbarContent {
        ToolbarItem(placement: isRoot ? .topBarLeading : .topBarTrailing) {
            // White, not the page's tint: a detail page tints itself from its artwork, and the
            // bar's controls read as chrome rather than as part of the page.
            Button("Close", systemImage: "xmark", action: close)
                .tint(.white)
        }
    }
}

private struct ModalDismissable: ViewModifier {
    @Environment(\.closeModal) private var closeModal
    @Environment(\.isModalRoot) private var isModalRoot
    @Environment(\.detailSearch) private var detailSearch

    // One branch always: swapping `content` for `content.toolbar` re-creates the page and
    // loses its scroll position.
    func body(content: Content) -> some View {
        content.toolbar {
            // Search puts its own cancel here.
            if let closeModal, detailSearch?.isPresented != true {
                ModalCloseItem(close: closeModal, isRoot: isModalRoot)
            }
        }
    }
}

extension View {
    func modalDismissable() -> some View {
        modifier(ModalDismissable())
    }
}
