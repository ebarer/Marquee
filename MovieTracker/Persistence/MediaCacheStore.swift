//
//  MediaCacheStore.swift
//  MovieTracker
//

import SwiftUI
import UIKit

struct CachedMedia: Codable {
    var movie: Movie
    var tint: [Double]?
    var cachedAt: Date

    var color: Color? {
        guard let c = tint, c.count == 4 else { return nil }
        return Color(.sRGB, red: c[0], green: c[1], blue: c[2], opacity: c[3])
    }
}

/// Bounded on-disk JSON cache of fetched media, keyed by TMDB id, so detail renders offline.
actor MediaCacheStore {
    static let shared = MediaCacheStore()

    private let maxEntries = 300
    private let fileManager = FileManager.default

    private lazy var directory: URL = {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MediaCache", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func fileURL(id: Int) -> URL {
        directory.appendingPathComponent("media-\(id).json")
    }

    /// Stale entries are still returned (usable offline); freshness only gates re-fetch.
    func load(id: Int) -> CachedMedia? {
        guard let data = try? Data(contentsOf: fileURL(id: id)) else { return nil }
        return try? decoder.decode(CachedMedia.self, from: data)
    }

    func isFresh(id: Int, ttl: TimeInterval) -> Bool {
        guard let cached = load(id: id) else { return false }
        return Date().timeIntervalSince(cached.cachedAt) < ttl
    }

    func save(_ movie: Movie, tint: Color?) {
        let entry = CachedMedia(movie: movie, tint: tint.flatMap(Self.rgba(from:)),
                                cachedAt: Date())
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: fileURL(id: movie.id), options: .atomic)
        evictIfNeeded()
    }

    struct Usage: Sendable {
        var count: Int
        var bytes: Int64
    }

    func usage() -> Usage {
        let files = (try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let bytes = files.reduce(Int64(0)) {
            $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return Usage(count: files.count, bytes: bytes)
    }

    func clear() {
        let files = (try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files { try? fileManager.removeItem(at: file) }
    }

    private func evictIfNeeded() {
        let key: URLResourceKey = .contentModificationDateKey
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [key]),
              files.count > maxEntries else { return }

        let sorted = files.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [key]))?.contentModificationDate ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [key]))?.contentModificationDate ?? .distantPast
            return l < r
        }
        for file in sorted.prefix(files.count - maxEntries) {
            try? fileManager.removeItem(at: file)
        }
    }

    private static func rgba(from color: Color) -> [Double]? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return [Double(r), Double(g), Double(b), Double(a)]
    }
}
