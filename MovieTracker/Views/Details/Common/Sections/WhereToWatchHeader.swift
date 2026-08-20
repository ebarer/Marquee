//
//  WhereToWatchHeader.swift
//  MovieTracker
//

import SwiftUI

/// The header row of `WhereToWatchSection`: title, services info button, expand chevron, in-theaters note.
struct WhereToWatchHeader: View {
    let available: Bool
    let inTheatres: Bool
    let tint: Color
    var isLoading: Bool = false
    @Binding var expanded: Bool
    let onInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            // Nothing here is knowable yet: not the verdict, not the theaters note, not whether there is
            // anything to expand. The whole row stands in as one bar.
            if isLoading {
                titlePlaceholder
            } else {
                HStack(spacing: 8) {
                    // Only present once availability is known, so its existence is the signal
                    // the UI tests assert on.
                    titleView
                        .accessibilityIdentifier("whereToWatch-verdict")
                    infoButton
                    if available {
                        Button(action: toggle) {
                            Image(systemName: "chevron.down")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(tint)
                                .rotationEffect(.degrees(expanded ? 0 : -90))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                if inTheatres {
                    Text("Watch in Theaters")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .sectionHeaderInsets()
    }

    private var titlePlaceholder: some View {
        Text("Available to Stream")
            .font(.headline)
            .redacted(reason: .placeholder)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var titleView: some View {
        if available {
            Button(action: toggle) {
                Text("Available to Stream")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text("Unavailable to Stream")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var infoButton: some View {
        Button(action: onInfo) {
            Image(systemName: "info.circle")
                .font(.subheadline)
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose your services")
    }

    private func toggle() {
        withAnimation(.easeInOut) { expanded.toggle() }
    }
}

#Preview {
    VStack(spacing: 24) {
        WhereToWatchHeader(available: true, inTheatres: false, tint: .appAccent,
                           expanded: .constant(true), onInfo: {})
        WhereToWatchHeader(available: false, inTheatres: true, tint: .appAccent,
                           expanded: .constant(false), onInfo: {})
        WhereToWatchHeader(available: false, inTheatres: false, tint: .appAccent,
                           isLoading: true, expanded: .constant(false), onInfo: {})
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
