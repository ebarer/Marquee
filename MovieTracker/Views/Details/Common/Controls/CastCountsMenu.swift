//
//  CastCountsMenu.swift
//  MovieTracker
//

import SwiftUI

/// The episode-count switch a cast list carries: a tap toggles counts, a long press opens a checklist.
struct CastCountsMenu: View {
    @Binding var showsCounts: Bool
    var style: Style = .sectionHeader
    var tint: Color = .appAccent

    enum Style {
        case sectionHeader
        case bar
    }

    var body: some View {
        Menu {
            Toggle("Episode Counts", isOn: $showsCounts)
        } label: {
            label
        } primaryAction: {
            showsCounts.toggle()
        }
        .modifier(StyleChrome(style: style, showsCounts: showsCounts, tint: tint))
        .accessibilityLabel(showsCounts ? "Hide episode counts" : "Show episode counts")
        .accessibilityHint("Touch and hold to choose what a cast row shows")
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .sectionHeader:
            SectionHeaderFilterGlyph(isOn: !showsCounts, tint: tint)
        case .bar:
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(showsCounts ? Color.white : .black)
        }
    }
}

/// The bar's fill goes on the menu rather than its label, so it centres on the item the bar lays out.
private struct StyleChrome: ViewModifier {
    let style: CastCountsMenu.Style
    let showsCounts: Bool
    let tint: Color

    func body(content: Content) -> some View {
        switch style {
        case .sectionHeader:
            content.buttonStyle(.plain)
        case .bar:
            content
                .filterOnBadge(!showsCounts, size: DetailSearchBar.barItemFill, color: tint)
                .tint(.white)
        }
    }
}

#Preview {
    @Previewable @State var showsCounts = true

    NavigationStack {
        VStack(spacing: 24) {
            CastCountsMenu(showsCounts: $showsCounts)
            Text(showsCounts ? "Counts shown" : "Counts hidden")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .navigationTitle("Top Cast")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CastCountsMenu(showsCounts: $showsCounts, style: .bar)
            }
        }
    }
    .preferredColorScheme(.dark)
}
