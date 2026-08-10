//
//  DetailLoadingView.swift
//  MovieTracker
//

import SwiftUI

/// The centered spinner + title shown while a detail screen's payload loads.
struct DetailLoadingView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DetailLoadingView(title: "The Odyssey")
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
