//
//  DetailNavigation.swift
//  MovieTracker
//

import SwiftUI

private struct OpenDetailKey: EnvironmentKey {
    static let defaultValue: ((AnyHashable) -> Void)? = nil
}

extension EnvironmentValues {
    /// Set only in the iPad shell; when nil, taps push within the current stack.
    var openDetail: ((AnyHashable) -> Void)? {
        get { self[OpenDetailKey.self] }
        set { self[OpenDetailKey.self] = newValue }
    }
}

private struct CloseModalKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Injected on the modal's NavigationStack so every pushed screen inherits it.
    var closeModal: (() -> Void)? {
        get { self[CloseModalKey.self] }
        set { self[CloseModalKey.self] = newValue }
    }
}

private struct ModalRootKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True for the screen the modal opened on. Set by `DetailRootView`, and not inherited by
    /// pushed screens — they hang off the NavigationStack, not off the root's subtree.
    var isModalRoot: Bool {
        get { self[ModalRootKey.self] }
        set { self[ModalRootKey.self] = newValue }
    }
}

/// The modal's Close button. A screen with trailing items of its own renders this itself, after
/// them: `modalDismissable()` applies from outside, and an outer item always lands leading.
struct ModalCloseItem: ToolbarContent {
    let close: () -> Void
    /// The root has no back button, so Close takes the leading side rather than sitting
    /// opposite an empty corner. A pushed screen leaves that side to the back button.
    var isRoot = false

    var body: some ToolbarContent {
        ToolbarItem(placement: isRoot ? .topBarLeading : .topBarTrailing) {
            Button("Close", systemImage: "xmark", action: close)
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
