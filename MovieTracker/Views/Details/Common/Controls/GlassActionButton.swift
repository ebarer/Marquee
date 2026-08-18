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
            GlassActionLabel(systemName: systemName, isOn: isOn, width: width, tint: tint)
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(tint).interactive() : .regular.interactive(), in: shape)
    }
}

/// ``GlassActionButton`` that opens a menu instead of firing an action. Shares the button's
/// styling exactly — the two sit side by side in an action bar and must be indistinguishable.
struct GlassActionMenu<S: Shape, Content: View>: View {
    let systemName: String
    let isOn: Bool
    var width: CGFloat = ActionBarMetrics.size
    let shape: S
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            GlassActionLabel(systemName: systemName, isOn: isOn, width: width, tint: tint)
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(tint).interactive() : .regular.interactive(), in: shape)
    }
}

private struct GlassActionLabel: View {
    let systemName: String
    let isOn: Bool
    let width: CGFloat
    let tint: Color

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isOn ? .appBackground : tint)
            // A disabled control keeps its slot in the bar, dimmed — `.plain` styling won't
            // show the state on its own.
            .opacity(isEnabled ? 1 : 0.3)
            .frame(width: width, height: ActionBarMetrics.size)
            .contentShape(Rectangle())
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
