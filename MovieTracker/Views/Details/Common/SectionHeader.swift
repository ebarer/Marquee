//
//  SectionHeader.swift
//  MovieTracker
//

import SwiftUI

/// A left-aligned section title used across the detail screens.
struct SectionHeader: View {
    let title: String
    var color: Color = .white

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}

extension View {
    /// The glass circle a detail section header puts its controls in.
    func sectionHeaderControl() -> some View {
        frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .glassEffect(.regular.interactive(), in: .circle)
    }
}

#Preview {
    VStack(spacing: 0) {
        SectionHeader(title: "Cast & Crew")
        SectionHeader(title: "2026", color: .appAccent)
    }
    .background(Color.appBackground)
}
