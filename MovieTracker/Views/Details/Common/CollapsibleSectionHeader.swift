//
//  CollapsibleSectionHeader.swift
//  MovieTracker
//

import SwiftUI

/// A section header that toggles its content: title plus a chevron that points down when
/// expanded and rotates to -90° when collapsed. Shared by the Related/Recommendations strips.
struct CollapsibleSectionHeader: View {
    let title: String
    let tint: Color
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        CollapsibleSectionHeader(title: "Recommendations", tint: .appAccent,
                                 isExpanded: true, onToggle: {})
        CollapsibleSectionHeader(title: "Recommendations", tint: .appAccent,
                                 isExpanded: false, onToggle: {})
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
