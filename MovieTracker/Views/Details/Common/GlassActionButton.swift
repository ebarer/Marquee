//
//  GlassActionButton.swift
//  MovieTracker
//

import SwiftUI

enum ActionBarMetrics {
    static let size: CGFloat = 52
    static let spacing: CGFloat = 12
}

/// The `.fill` variant of a symbol when one exists, else the base name.
func filledSymbol(_ base: String) -> String {
    let candidate = base + ".fill"
    return UIImage(systemName: candidate) != nil ? candidate : base
}

/// A single Liquid Glass control shared by the detail action bars. Callers attach
/// `.glassEffectID`/`.glassEffectTransition` to the returned view when needed.
struct GlassActionButton<S: Shape>: View {
    let systemName: String
    let isOn: Bool
    var width: CGFloat = ActionBarMetrics.size
    let shape: S
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isOn ? .appBackground : tint)
                .frame(width: width, height: ActionBarMetrics.size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(tint).interactive() : .regular.interactive(), in: shape)
    }
}

#Preview {
    GlassEffectContainer(spacing: ActionBarMetrics.spacing) {
        HStack(spacing: ActionBarMetrics.spacing) {
            GlassActionButton(systemName: "bookmark", isOn: false, shape: Circle(),
                              tint: .appAccent) {}
            GlassActionButton(systemName: "checkmark", isOn: true, shape: Circle(),
                              tint: .appAccent) {}
        }
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
