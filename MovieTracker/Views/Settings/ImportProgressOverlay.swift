//
//  ImportProgressOverlay.swift
//  MovieTracker
//

import SwiftUI

/// The scrim + determinate progress shown while a backup import runs.
struct ImportProgressOverlay: View {
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                Text("Importing \(done) of \(total)…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview("Import progress") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        ImportProgressOverlay(done: 37, total: 120)
    }
    .preferredColorScheme(.dark)
}
