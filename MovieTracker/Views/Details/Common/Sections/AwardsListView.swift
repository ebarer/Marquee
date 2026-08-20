//
//  AwardsListView.swift
//  MovieTracker
//

import SwiftUI

/// The wins and nominations behind the metadata strip's awards cell, grouped by award series.
struct AwardsListView: View {
    let title: String
    let digest: AwardsDigest
    var tint: Color = .appAccent

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(digest.series) { series in
                    Section {
                        ForEach(series.awards) { award in
                            AwardRow(award: award, tint: tint)
                        }
                    } header: {
                        Text(series.name)
                    } footer: {
                        Text(tally(for: series))
                    }
                }

                Section {
                } footer: {
                    Text("Awards data from Wikidata. Coverage varies by title.")
                }
            }
            .navigationTitle("Awards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Awards").font(.headline)
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(tint)
    }

    private func tally(for series: AwardSeries) -> String {
        let parts = [
            series.wins > 0 ? "\(series.wins) won" : nil,
            series.nominations > 0 ? "\(series.nominations) nominated" : nil,
        ].compactMap { $0 }
        return parts.joined(separator: ", ")
    }
}

private struct AwardRow: View {
    let award: Award
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: award.isWin ? "trophy.fill" : "trophy")
                .font(.system(size: 14))
                .foregroundStyle(award.isWin ? tint : Color.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(award.shortCategory)
                Text(award.isWin ? "Won" : "Nominated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let year = award.year {
                Text(String(year))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(award.shortCategory), \(award.isWin ? "won" : "nominated")"
                            + (award.year.map { ", \($0)" } ?? ""))
    }
}

// MARK: - Previews

extension AwardsDigest {
    static var preview: AwardsDigest {
        AwardsDigest(awards: [
            Award(category: "Academy Award for Best Cinematography",
                  series: "Academy Awards", year: 2011, isWin: true),
            Award(category: "Academy Award for Best Sound", series: "Academy Awards",
                  year: 2011, isWin: true),
            Award(category: "Academy Award for Best Visual Effects",
                  series: "Academy Awards", year: 2011, isWin: true),
            Award(category: "Academy Award for Best Picture", series: "Academy Awards",
                  year: 2011, isWin: false),
            Award(category: "Academy Award for Best Writing, Original Screenplay",
                  series: "Academy Awards", year: 2011, isWin: false),
            Award(category: "Academy Award for Best Original Score",
                  series: "Academy Awards", year: 2011, isWin: false),
            Award(category: "Hugo Award for Best Dramatic Presentation, Long Form",
                  series: "Hugo Award", year: 2011, isWin: true),
            Award(category: "Saturn Award for Best Science Fiction Film",
                  series: "Saturn Awards", year: 2011, isWin: true),
            Award(category: "National Board of Review: Top Ten Films",
                  series: nil, year: nil, isWin: true),
        ])
    }
}

#Preview {
    AwardsListView(title: "Inception", digest: .preview, tint: .orange)
        .preferredColorScheme(.dark)
}

#Preview("Sparse") {
    AwardsListView(
        title: "The Brutalist",
        digest: AwardsDigest(awards: [
            Award(category: "Academy Award for Best Actor", series: "Academy Awards",
                  year: 2025, isWin: true),
        ]),
        tint: .teal
    )
    .preferredColorScheme(.dark)
}
