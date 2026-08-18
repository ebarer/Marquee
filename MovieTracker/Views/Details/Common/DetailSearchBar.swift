//
//  DetailSearchBar.swift
//  MovieTracker
//

import SwiftUI

/// The search field for a detail search. Hand-built because `.searchable` installs its field in the
/// navigation bar, where this view can neither place it nor dismiss it.
struct DetailSearchBar: View {
    @Binding var text: String
    let prompt: String
    var tint: Color = .appAccent
    var autofocus = false
    /// False while the field is still button-sized, where the prompt shows as a stray letter.
    var showsPrompt = true

    @FocusState private var isFocused: Bool

    // Measured off the system search bar on iOS 27; don't tidy these into round numbers.
    static let capsuleHeight: CGFloat = 43
    static let rowHeight: CGFloat = 44
    static let cancelGap: CGFloat = 11
    static let barMargin: CGFloat = 16
    // A sheet's bar insets its items tighter than a compact one. Only a first search leans on this;
    // after that the cancel button's own frame is known.
    static func barItemInset(compact: Bool) -> CGFloat { compact ? barMargin : 11 }
    // The bar is taller than the row its items sit on, which is the top `rowHeight` of it. Measured
    // on iOS 27 and the same on both idioms, so the row can't be assumed to meet the content.
    static let barHeight: CGFloat = 54
    // A fill marking a bar item as active: wider than tall, so it echoes the group it sits in rather
    // than reading as a circle crammed into the end. Sized to clear the glass by 4pt all round.
    static let barItemFill = CGSize(width: 40, height: rowHeight - 8)
    // Where the magnifying glass sits: 12pt of padding plus half of a 20.3pt glyph. The flight
    // lines this up with the button's glyph.
    static let glyphCenter: CGFloat = 22
    // The system's placeholder grey; `.secondary` is much brighter.
    static let promptColor = Color.white.opacity(0.33)

    /// A toolbar item's frame is its glyph's; the bar draws a `rowHeight` glass circle around it,
    /// and that circle is what the field is placed from.
    static func barCircle(around glyph: CGRect) -> CGRect {
        CGRect(x: glyph.midX - rowHeight / 2, y: glyph.midY - rowHeight / 2,
               width: rowHeight, height: rowHeight)
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(.white)

            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Self.promptColor))
                .opacity(showsPrompt ? 1 : 0)
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
        // Raising the keyboard stalls the main thread, so the caller holds it off until the field
        // has landed and the rows are up.
        .onChange(of: autofocus, initial: true) {
            guard autofocus else { return }
            isFocused = true
        }
    }
}

extension View {
    /// Sizes and places the field as the control it came from while `collapsed`, so animating that
    /// flag widens it out of that control.
    func flying(from source: CGRect?, to target: CGRect, collapsed: Bool) -> some View {
        modifier(FieldFlight(source: source, target: target, collapsed: collapsed))
    }
}

private struct FieldFlight: ViewModifier {
    let source: CGRect?
    let target: CGRect
    let collapsed: Bool

    func body(content: Content) -> some View {
        content
            // Masked rather than resized: squeezing the field's own layout to the button's width
            // proposes a negative width to its text field, which SwiftUI faults on every pass.
            .mask(alignment: .leading) {
                Capsule()
                    .frame(width: window.width, height: window.height)
                    .offset(x: windowInset)
            }
            .offset(x: offset.width, y: offset.height)
    }

    private var start: CGRect? { collapsed ? source : nil }

    /// The pill of the field that is visible, which grows from the button's circle to the whole bar.
    private var window: CGSize {
        guard let start else {
            return CGSize(width: target.width, height: DetailSearchBar.capsuleHeight)
        }
        return CGSize(width: min(start.width, target.width),
                      height: min(start.height, DetailSearchBar.capsuleHeight))
    }

    /// Keeps that pill centred on the magnifying glass rather than on the field's leading edge.
    private var windowInset: CGFloat {
        guard start != nil else { return 0 }
        return max(0, DetailSearchBar.glyphCenter - window.width / 2)
    }

    private var offset: CGSize {
        guard let start else { return .zero }
        // The whole field slides, so its magnifying glass travels from the button's glyph rather
        // than standing still while the capsule grows past it.
        return CGSize(width: start.midX - DetailSearchBar.glyphCenter - target.minX,
                      height: start.midY - target.midY)
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

#Preview("Flight start") {
    DetailSearchBarFlightPreview()
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

/// The field where its flight begins, standing in for a trailing navigation bar button.
private struct DetailSearchBarFlightPreview: View {
    @State private var text = ""

    var body: some View {
        GeometryReader { proxy in
            let container = proxy.frame(in: .global)
            let top: CGFloat = 60
            let target = CGRect(x: container.minX + DetailSearchBar.barMargin, y: container.minY + top,
                                width: container.width - DetailSearchBar.barMargin * 2,
                                height: DetailSearchBar.capsuleHeight)
            DetailSearchBar(text: $text, prompt: "Search Cast & Crew")
                .flying(from: CGRect(x: target.maxX - DetailSearchBar.rowHeight, y: target.midY - 22,
                                     width: DetailSearchBar.rowHeight,
                                     height: DetailSearchBar.rowHeight),
                        to: target, collapsed: true)
                .padding(.horizontal, DetailSearchBar.barMargin)
                .padding(.top, top)
        }
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
    }
}
