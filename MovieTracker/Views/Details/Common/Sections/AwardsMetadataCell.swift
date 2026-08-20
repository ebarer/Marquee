//
//  AwardsMetadataCell.swift
//  MovieTracker
//

import SwiftUI

/// A cell appended inside a metadata strip's `HStack`.
struct AwardsMetadataCell: View {
    let awards: AwardsDigest
    // Until Wikidata answers, "None" would claim the title won nothing and flip to a count a beat later.
    var isResolved: Bool = true
    var tint: Color = .appAccent
    var onTap: () -> Void

    var body: some View {
        MetadataDivider()
        MetadataCell(header: "AWARDS", minWidth: 70) {
            if let summary = awards.summary {
                Button(action: onTap) {
                    Text(summary).foregroundStyle(tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityHint("Shows every win and nomination")
            } else if isResolved {
                Text("None").foregroundStyle(.secondary)
                    .accessibilityLabel("Awards, none")
            } else {
                MetadataPlaceholder(width: 40)
            }
        }
    }

    private var label: String {
        let parts = [
            awards.wins > 0 ? "\(awards.wins) \(awards.wins == 1 ? "win" : "wins")" : nil,
            awards.nominations > 0
                ? "\(awards.nominations) \(awards.nominations == 1 ? "nomination" : "nominations")"
                : nil,
        ].compactMap { $0 }
        return "Awards, \(parts.joined(separator: ", "))"
    }
}

// Counted, none, and still pending. All three must be the same height: the cell sits in a strip
// under the header and can't resize it as Wikidata answers.
#Preview {
    let states: [(AwardsDigest, Bool)] = [(.preview, true), (AwardsDigest(), true),
                                          (AwardsDigest(), false)]

    // The cell's divider is vertically greedy, so this needs a ScrollView to size naturally.
    return ScrollView {
        VStack(spacing: 24) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                VStack(spacing: 0) {
                    MetadataHairline()
                    HStack(alignment: .top, spacing: 0) {
                        MetadataCell(header: "TMDB.org") { tmdbScoreText(8.4) }
                        AwardsMetadataCell(awards: state.0, isResolved: state.1,
                                           tint: .orange, onTap: {})
                    }
                    MetadataHairline()
                }
            }
        }
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
