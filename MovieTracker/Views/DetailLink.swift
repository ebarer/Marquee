//
//  DetailLink.swift
//  MovieTracker
//

import SwiftUI

enum DetailRoot: Hashable, Identifiable {
    case movie(Movie)
    case show(Show)
    case episode(Episode)
    case person(Person)
    case people(PeopleList)

    var id: String {
        switch self {
        case .movie(let movie): return "movie-\(movie.id)"
        case .show(let show): return "show-\(show.id)"
        case .episode(let episode): return "episode-\(episode.id)"
        case .person(let person): return "person-\(person.id)"
        case .people(let list): return "people-\(list.title)"
        }
    }
}

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

/// Pushes within a `NavigationStack`, or opens the detail modal when `openDetail` is set.
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
