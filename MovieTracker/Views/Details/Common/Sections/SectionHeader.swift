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
            .sectionHeaderInsets()
    }
}

/// `UIListContentConfiguration.plainHeader()`: 17pt semibold, 10pt above and below, text 16pt in.
enum SectionHeaderMetrics {
    static let horizontal: CGFloat = 16
    static let top: CGFloat = 10
    static let bottom: CGFloat = 10

    static var listRowInsets: EdgeInsets {
        EdgeInsets(top: top, leading: horizontal, bottom: bottom, trailing: horizontal)
    }
}

enum SectionHeaderControl {
    static let diameter: CGFloat = 32
    static let fill = CGSize(width: diameter - 8, height: diameter - 8)
}

extension View {
    func sectionHeaderInsets(horizontal: CGFloat = SectionHeaderMetrics.horizontal,
                             top: CGFloat = SectionHeaderMetrics.top,
                             bottom: CGFloat = SectionHeaderMetrics.bottom) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontal)
            .padding(.top, top)
            .padding(.bottom, bottom)
    }

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
