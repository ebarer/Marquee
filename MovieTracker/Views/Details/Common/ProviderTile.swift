//
//  ProviderTile.swift
//  MovieTracker
//

import SwiftUI

/// A streaming-provider logo tile that opens the provider's app/page (or the JustWatch
/// fallback link). Used in ``WhereToWatchSection``.
struct ProviderTile: View {
    let group: ProviderGroup
    let fallback: URL?
    var size: CGFloat = 56

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = group.appURL ?? fallback {
                openURL(url)
            }
        } label: {
            RemoteImage(url: group.logoURL(size: "w154")) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appSeparator)
                    .overlay {
                        Text(group.name.prefix(1))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.name)
    }
}

#Preview {
    let groups = ProviderCatalog.grouped(Movie.preview.watchByRegion?.values.first?.providers ?? [])
    return HStack(spacing: 12) {
        ForEach(groups.prefix(3)) { group in
            ProviderTile(group: group, fallback: nil)
        }
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
