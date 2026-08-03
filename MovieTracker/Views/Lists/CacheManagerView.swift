//
//  CacheManagerView.swift
//  MovieTracker
//

import SwiftUI

/// Shows how much space the offline caches use and lets the user clear them. The
/// detail cache is on-disk JSON (`MediaCacheStore`); images live in the shared
/// `URLCache`. Cleared content is re-downloaded automatically when next viewed online.
struct CacheManagerView: View {
    @State private var detail: MediaCacheStore.Usage?
    @State private var imageBytes: Int = 0
    @State private var clearing = false

    var body: some View {
        List {
            Section("Movie Details") {
                LabeledContent("Cached Titles", value: detail.map { "\($0.count)" } ?? "—")
                LabeledContent("Size", value: sizeText(detail?.bytes))
                Button("Clear Movie Details", role: .destructive) { clearDetails() }
                    .disabled(clearing || (detail?.bytes ?? 0) == 0)
            }

            Section {
                LabeledContent("Size", value: sizeText(Int64(imageBytes)))
                Button("Clear Images", role: .destructive) { clearImages() }
                    .disabled(clearing || imageBytes == 0)
            } header: {
                Text("Images")
            } footer: {
                Text("Cleared content is re-downloaded automatically the next time you open it online.")
            }
        }
        .navigationTitle("Cache")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
    }

    private func refresh() async {
        detail = await MediaCacheStore.shared.usage()
        imageBytes = URLCache.shared.currentDiskUsage
    }

    private func clearDetails() {
        clearing = true
        Task {
            await MediaCacheStore.shared.clear()
            await refresh()
            clearing = false
        }
    }

    private func clearImages() {
        clearing = true
        Task {
            URLCache.shared.removeAllCachedResponses()
            RemoteImageCache.shared.removeAll()
            await refresh()
            clearing = false
        }
    }

    private func sizeText(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview {
    NavigationStack {
        CacheManagerView()
    }
    .preferredColorScheme(.dark)
}
