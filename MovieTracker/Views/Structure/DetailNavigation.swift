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

private struct ModalDismissable: ViewModifier {
    @Environment(\.closeModal) private var closeModal

    func body(content: Content) -> some View {
        if let closeModal {
            content.toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { closeModal() }
                }
            }
        } else {
            content
        }
    }
}

extension View {
    func modalDismissable() -> some View {
        modifier(ModalDismissable())
    }
}
