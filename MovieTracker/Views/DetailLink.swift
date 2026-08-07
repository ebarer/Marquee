//
//  DetailLink.swift
//  MovieTracker
//

import SwiftUI

/// A detail target opened as a modal on iPad (movie / person / people list).
enum DetailRoot: Hashable, Identifiable {
    case movie(Movie)
    case person(Person)
    case people(PeopleList)

    var id: String {
        switch self {
        case .movie(let movie): return "movie-\(movie.id)"
        case .person(let person): return "person-\(person.id)"
        case .people(let list): return "people-\(list.title)"
        }
    }
}

private struct OpenDetailKey: EnvironmentKey {
    static let defaultValue: ((AnyHashable) -> Void)? = nil
}

extension EnvironmentValues {
    /// Present only in the iPad shell. When set, a top-level result tap opens the
    /// detail modal instead of pushing within the current stack.
    var openDetail: ((AnyHashable) -> Void)? {
        get { self[OpenDetailKey.self] }
        set { self[OpenDetailKey.self] = newValue }
    }
}

private struct CloseModalKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Present inside the iPad detail modal (injected on its NavigationStack, so it
    /// reaches every pushed screen). Dismisses the whole modal.
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
    /// Adds a trailing Close button when presented inside the iPad detail modal
    /// (i.e. when a `closeModal` action is in the environment). A no-op everywhere
    /// else, so the same detail screens push normally on iPhone.
    func modalDismissable() -> some View {
        modifier(ModalDismissable())
    }
}

/// A link that pushes within a `NavigationStack` (iPhone, and the detail column's
/// own deep navigation), but fills the detail column when an `openDetail` action is
/// in the environment (iPad three-column layout). The concrete `Value` is preserved
/// in the `NavigationLink` branch so it keeps matching the existing
/// `navigationDestination(for:)` registrations.
struct DetailLink<Value: Hashable, Label: View>: View {
    let value: Value
    @ViewBuilder var label: () -> Label

    @Environment(\.openDetail) private var openDetail

    var body: some View {
        if let openDetail {
            Button {
                openDetail(AnyHashable(value))
            } label: {
                label()
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: value) {
                label()
            }
        }
    }
}
