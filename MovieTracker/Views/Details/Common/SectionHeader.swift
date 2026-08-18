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

enum SectionHeaderControl {
    static let diameter: CGFloat = 32
    /// The circle a control draws inside itself to show it is doing something, inset 4pt.
    static let fill = CGSize(width: diameter - 8, height: diameter - 8)
}

extension View {
    /// The glass circle a detail section header puts its controls in.
    func sectionHeaderControl() -> some View {
        frame(width: SectionHeaderControl.diameter, height: SectionHeaderControl.diameter)
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
