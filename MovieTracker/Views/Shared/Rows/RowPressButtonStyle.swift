//
//  RowPressButtonStyle.swift
//  MovieTracker
//

import SwiftUI

/// Press feedback for rows that can't be `List` cells (the detail screens scroll one
/// container). A style only sees the press, so the highlight can't hold through the push.
struct RowPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(.systemGray5) : .clear)
            .contentShape(Rectangle())
            // Instant on press, fading on release, as a cell's highlight does.
            .animation(configuration.isPressed ? nil : .easeOut(duration: 0.25),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == RowPressButtonStyle {
    static var rowPress: RowPressButtonStyle { RowPressButtonStyle() }
}
