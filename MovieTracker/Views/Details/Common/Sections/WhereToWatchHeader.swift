//
//  WhereToWatchHeader.swift
//  MovieTracker
//

import SwiftUI

/// The header row of `WhereToWatchSection`: verdict, scope menu, expand chevron, in-theaters note.
struct WhereToWatchHeader: View {
    let verdict: StreamingVerdict
    let inTheatres: Bool
    let tint: Color
    var isLoading: Bool = false
    // Whether the current scope has tiles to show, which is what the row opens onto.
    var expandable: Bool = false
    // False when the title streams nowhere in the region, so neither scope has anything to show.
    var canChangeScope: Bool = true
    @Binding var expanded: Bool
    @Binding var scope: StreamingScope
    let onChooseServices: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Nothing here is knowable yet: not the verdict, not the theaters note, not whether there is
            // anything to expand. The whole row stands in as one bar.
            if isLoading {
                titlePlaceholder
            } else {
                // The note sits in its own row, indented past the control, so the control centres on
                // the verdict rather than on the pair.
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        scopeMenu

                        HStack(spacing: 3) {
                            // Only present once availability is known, so its existence is the signal
                            // the UI tests assert on.
                            titleView
                                .accessibilityIdentifier("whereToWatch-verdict")
                            if expandable {
                                Button(action: toggle) {
                                    Image(systemName: "chevron.down")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(tint)
                                        .rotationEffect(.degrees(expanded ? 0 : -90))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if inTheatres {
                        Text("Watch in Theaters")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, SectionHeaderControl.inlineDiameter + 8)
                    }
                }
            }
        }
        .sectionHeaderInsets()
    }

    private var titlePlaceholder: some View {
        Text(StreamingVerdict.available.title)
            .font(.headline)
            .redacted(reason: .placeholder)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var titleView: some View {
        if expandable {
            Button(action: toggle) {
                Text(verdict.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text(verdict.title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
    }

    private var scopeMenu: some View {
        Menu {
            Picker("Availability", selection: $scope) {
                ForEach(StreamingScope.allCases, id: \.self) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
            Section {
                Button("Choose Services…", systemImage: "checklist", action: onChooseServices)
            }
        } label: {
            // The symbol is the state: no fill, since scope is a choice rather than a filter.
            Image(systemName: scope.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(canChangeScope ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
                .sectionHeaderControl(diameter: SectionHeaderControl.inlineDiameter)
                // The control swaps outright; only the section it governs animates.
                .animation(nil, value: scope)
        } primaryAction: {
            // Widening is a request to see what's out there, so the tiles come with it.
            withAnimation(.easeInOut) {
                let widening = scope == .mine
                scope = widening ? .all : .mine
                if widening { expanded = true }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canChangeScope)
        .accessibilityLabel(canChangeScope
                            ? (scope == .mine ? "Show all services" : "Show my services only")
                            : "No streaming services")
        .accessibilityHint(canChangeScope ? "Touch and hold to choose your services" : "")
    }

    private func toggle() {
        withAnimation(.easeInOut) { expanded.toggle() }
    }
}

#Preview {
    VStack(spacing: 24) {
        WhereToWatchHeader(verdict: .available, inTheatres: false, tint: .appAccent,
                           expandable: true, expanded: .constant(true), scope: .constant(.mine),
                           onChooseServices: {})
        // Not on my services: greyed under my own scope, live once widened to all of them.
        WhereToWatchHeader(verdict: .offMyServices, inTheatres: false, tint: .appAccent,
                           expanded: .constant(false), scope: .constant(.mine),
                           onChooseServices: {})
        WhereToWatchHeader(verdict: .offMyServices, inTheatres: false, tint: .appAccent,
                           expandable: true, expanded: .constant(false), scope: .constant(.all),
                           onChooseServices: {})
        // Streams nowhere, so the scope control is dead: in theaters, then a show with no providers.
        WhereToWatchHeader(verdict: .unavailable, inTheatres: true, tint: .appAccent,
                           canChangeScope: false, expanded: .constant(false),
                           scope: .constant(.mine), onChooseServices: {})
        WhereToWatchHeader(verdict: .unavailable, inTheatres: false, tint: .appAccent,
                           canChangeScope: false, expanded: .constant(false),
                           scope: .constant(.mine), onChooseServices: {})
        WhereToWatchHeader(verdict: .unavailable, inTheatres: false, tint: .appAccent,
                           isLoading: true, expanded: .constant(false), scope: .constant(.mine),
                           onChooseServices: {})
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
