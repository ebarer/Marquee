//
//  DetailSearchBar.swift
//  MovieTracker
//

import SwiftUI

/// The search field for a detail search. Hand-built because `.searchable` installs its field in
/// the navigation bar, which can't be a morph target and won't dismiss this view.
struct DetailSearchBar: View {
    @Binding var text: String
    let prompt: String
    var tint: Color = .appAccent
    var autofocus = false

    @FocusState private var isFocused: Bool

    // Measured off the system search bar on iOS 27; don't tidy these into round numbers.
    static let capsuleHeight: CGFloat = 43
    static let rowHeight: CGFloat = 44
    static let cancelGap: CGFloat = 11
    // The system's placeholder grey; `.secondary` is much brighter.
    static let promptColor = Color.white.opacity(0.33)

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(.white)

            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Self.promptColor))
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .tint(tint)
                .focused($isFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { isFocused = false }

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Self.promptColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .frame(height: Self.capsuleHeight)
        .glassEffect(.regular.interactive(), in: .capsule)
        .onAppear { if autofocus { isFocused = true } }
    }
}

/// Stands in for a list whose search matched nothing.
struct DetailSearchNoResults: View {
    let query: String

    var body: some View {
        Text("No matches for “\(query)”")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }
}

#Preview("Empty") {
    DetailSearchBarPreview(text: "")
}

#Preview("Typed") {
    DetailSearchBarPreview(text: "zen")
}

private struct DetailSearchBarPreview: View {
    @State var text: String

    var body: some View {
        VStack(spacing: 24) {
            DetailSearchBar(text: $text, prompt: "Search Cast & Crew")
            DetailSearchNoResults(query: text)
        }
        .padding(16)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
    }
}
