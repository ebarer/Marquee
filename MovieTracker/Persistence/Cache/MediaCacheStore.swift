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

struct CachedShow: Codable {
    var show: Show
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

    /// Shows use a separate `show-` prefix so movie/TV ids can't collide.
    private func showFileURL(id: Int) -> URL {
        directory.appendingPathComponent("show-\(id).json")
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

    func loadShow(id: Int) -> CachedShow? {
        guard let data = try? Data(contentsOf: showFileURL(id: id)) else { return nil }
        return try? decoder.decode(CachedShow.self, from: data)
    }

    func isShowFresh(id: Int, ttl: TimeInterval) -> Bool {
        guard let cached = loadShow(id: id) else { return false }
        return Date().timeIntervalSince(cached.cachedAt) < ttl
    }

    func save(_ show: Show, tint: Color?) {
        // The /tv/{id} payload behind `show` carries only the season list, not episodes —
        // preserve any per-season episodes already cached so a refresh doesn't wipe them.
        let entry = CachedShow(show: mergingCachedEpisodes(into: show),
                               tint: tint.flatMap(Self.rgba(from:)), cachedAt: Date())
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: showFileURL(id: show.id), options: .atomic)
        evictIfNeeded()
    }

    /// Patch one season's fetched episodes + cast into the cached show so they render
    /// offline and needn't be re-fetched. No-op until the show itself is cached.
    func cacheSeason(showID: Int, _ season: Season) {
        guard var cached = loadShow(id: showID),
              let index = cached.show.seasons.firstIndex(where: {
                  $0.seasonNumber == season.seasonNumber
              }) else { return }
        cached.show.seasons[index].episodes = season.episodes
        if !season.cast.isEmpty { cached.show.seasons[index].cast = season.cast }
        guard let data = try? encoder.encode(cached) else { return }
        try? data.write(to: showFileURL(id: showID), options: .atomic)
    }

    /// Carry cached episodes/cast forward onto a freshly-fetched show, per season, whenever
    /// the incoming season lacks them (the show payload never includes episodes).
    private func mergingCachedEpisodes(into show: Show) -> Show {
        guard let existing = loadShow(id: show.id)?.show else { return show }
        let bySeason = Dictionary(existing.seasons.map { ($0.seasonNumber, $0) },
                                  uniquingKeysWith: { first, _ in first })
        var show = show
        show.seasons = show.seasons.map { season in
            guard season.episodes.isEmpty,
                  let cached = bySeason[season.seasonNumber], !cached.episodes.isEmpty
            else { return season }
            var merged = season
            merged.episodes = cached.episodes
            if merged.cast.isEmpty { merged.cast = cached.cast }
            return merged
        }
        return show
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
