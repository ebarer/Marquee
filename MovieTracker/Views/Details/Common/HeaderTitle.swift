//
//  HeaderTitle.swift
//  MovieTracker
//

import SwiftUI

/// A detail-header title that breaks at the colon of a "Main: Subtitle" shape when it
/// can't fit on one line. Callers apply font/line-limit/scale modifiers around it.
struct HeaderTitle: View {
    let title: String

    var body: some View {
        if let colon = title.range(of: ": ") {
            let broken = title.replacingCharacters(in: colon, with: ":\n")
            ViewThatFits(in: .horizontal) {
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(broken)
            }
        } else {
            Text(title)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HeaderTitle(title: "Dune")
        HeaderTitle(title: "Mission: Impossible — The Final Reckoning")
    }
    .font(.title.bold())
    .foregroundStyle(.white)
    .lineLimit(2)
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
