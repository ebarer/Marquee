//
//  HeaderTitle.swift
//  MovieTracker
//

import SwiftUI

/// A detail-header title that breaks at the colon of a "Main: Subtitle" shape when it can't fit one line.
struct HeaderTitle: View {
    let title: String

    var body: some View {
        if let colon = title.range(of: ": ") {
            let broken = title.replacingCharacters(in: colon, with: ":\n")
            ViewThatFits(in: .horizontal) {
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                // `fixedSize` makes this candidate measure as its WIDEST line, so the colon
                // break is only taken when both halves fit unwrapped.
                Text(broken)
                    .fixedSize(horizontal: true, vertical: false)
                // Last resort: plain word wrapping across the caller's line limit.
                Text(title)
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
        HeaderTitle(title: "Anchorman: The Legend of Ron Burgundy")
    }
    .font(.title.bold())
    .foregroundStyle(.white)
    .lineLimit(2)
    .minimumScaleFactor(0.7)
    .frame(width: 249, alignment: .leading)
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
