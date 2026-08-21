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

    // Beside a 17pt title rather than at the row's trailing edge, where a full-size circle crowds the text.
    static let inlineDiameter: CGFloat = 26
}

/// The filter control that sits beside a section title: tinted, and filled while it is filtering.
struct SectionHeaderFilterGlyph: View {
    let isOn: Bool
    var tint: Color = .appAccent

    var body: some View {
        Image(systemName: "line.3.horizontal.decrease")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isOn ? .black : tint)
            .frame(width: SectionHeaderControl.inlineDiameter,
                   height: SectionHeaderControl.inlineDiameter)
            // The whole control fills; the inset capsule is the bar's treatment.
            .background { if isOn { Circle().fill(tint) } }
            .contentShape(Circle())
            .glassEffect(.regular.interactive(), in: .circle)
    }
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

    func sectionHeaderControl(diameter: CGFloat = SectionHeaderControl.diameter) -> some View {
        frame(width: diameter, height: diameter)
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
