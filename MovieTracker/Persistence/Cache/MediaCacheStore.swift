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
/// Each entry carries a `MediaCachePriority` that ranks it for eviction ahead of recency.
actor MediaCacheStore {
    static let shared = MediaCacheStore()

    private let maxEntries: Int
    private let directoryName: String
    private let fileManager = FileManager.default

    init(directoryName: String = "MediaCache", maxEntries: Int = 400) {
        self.directoryName = directoryName
        self.maxEntries = maxEntries
    }

    private lazy var directory: URL = {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
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

    /// Shows use a `show-` prefix so movie/TV ids can't collide.
    private func fileName(id: Int, mediaType: MediaType) -> String {
        mediaType == .tv ? "show-\(id).json" : "media-\(id).json"
    }

    private func fileURL(id: Int, mediaType: MediaType = .movie) -> URL {
        directory.appendingPathComponent(fileName(id: id, mediaType: mediaType))
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

    func save(_ movie: Movie, tint: Color?, priority: MediaCachePriority = .browsed) {
        let entry = CachedMedia(movie: movie, tint: tint.flatMap(Self.rgba(from:)),
                                cachedAt: Date())
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: fileURL(id: movie.id), options: .atomic)
        retain(fileName(id: movie.id, mediaType: .movie), at: priority)
        evictIfNeeded()
    }

    func loadShow(id: Int) -> CachedShow? {
        guard let data = try? Data(contentsOf: fileURL(id: id, mediaType: .tv)) else { return nil }
        return try? decoder.decode(CachedShow.self, from: data)
    }

    func isShowFresh(id: Int, ttl: TimeInterval) -> Bool {
        guard let cached = loadShow(id: id) else { return false }
        return Date().timeIntervalSince(cached.cachedAt) < ttl
    }

    func save(_ show: Show, tint: Color?, priority: MediaCachePriority = .browsed) {
        // The /tv/{id} payload behind `show` carries only the season list, not episodes —
        // preserve any per-season episodes already cached so a refresh doesn't wipe them.
        let entry = CachedShow(show: mergingCachedEpisodes(into: show),
                               tint: tint.flatMap(Self.rgba(from:)), cachedAt: Date())
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: fileURL(id: show.id, mediaType: .tv), options: .atomic)
        retain(fileName(id: show.id, mediaType: .tv), at: priority)
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
        try? data.write(to: fileURL(id: showID, mediaType: .tv), options: .atomic)
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
        let files = entryURLs(keys: [.fileSizeKey])
        let bytes = files.reduce(Int64(0)) {
            $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return Usage(count: files.count, bytes: bytes)
    }

    func clear() {
        let files = (try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files { try? fileManager.removeItem(at: file) }
        index = [:]
    }

    // MARK: - Priority index

    /// Retention tier per entry file name, held beside the entries rather than inside them so
    /// eviction can rank the whole cache without decoding every payload.
    private static let indexFileName = "priorities.json"
    private var index: [String: Int]?

    private func priorityIndex() -> [String: Int] {
        if let index { return index }
        let url = directory.appendingPathComponent(Self.indexFileName)
        let loaded = (try? Data(contentsOf: url))
            .flatMap { try? decoder.decode([String: Int].self, from: $0) } ?? [:]
        index = loaded
        return loaded
    }

    private func writeIndex(_ next: [String: Int]) {
        index = next
        guard let data = try? encoder.encode(next) else { return }
        try? data.write(to: directory.appendingPathComponent(Self.indexFileName), options: .atomic)
    }

    /// A tier only ever improves here: opening a Watch List title mustn't demote it to `.browsed`.
    private func retain(_ fileName: String, at priority: MediaCachePriority) {
        var next = priorityIndex()
        let best = min(next[fileName] ?? MediaCachePriority.browsed.rawValue, priority.rawValue)
        guard next[fileName] != best else { return }
        next[fileName] = best
        writeIndex(next)
    }

    /// Re-ranks the cache against a fresh plan: planned titles take their tier, everything else
    /// falls to `.browsed` — so a title that left the Watch List stops squatting on its claim.
    func applyPriorities(_ targets: [MediaCacheTarget]) {
        var next: [String: Int] = [:]
        for target in targets {
            next[fileName(id: target.tmdbID, mediaType: target.mediaType)] = target.priority.rawValue
        }
        writeIndex(next)
    }

    func priority(id: Int, mediaType: MediaType = .movie) -> MediaCachePriority {
        priorityIndex()[fileName(id: id, mediaType: mediaType)]
            .flatMap(MediaCachePriority.init(rawValue:)) ?? .browsed
    }

    // MARK: - Eviction

    private func entryURLs(keys: [URLResourceKey]) -> [URL] {
        let files = (try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys)) ?? []
        return files.filter { $0.lastPathComponent != Self.indexFileName }
    }

    private func evictIfNeeded() {
        let key: URLResourceKey = .contentModificationDateKey
        let files = entryURLs(keys: [key])
        guard files.count > maxEntries else { return }

        let tiers = priorityIndex()
        let ranked = files.map { url in
            (url: url,
             tier: tiers[url.lastPathComponent] ?? MediaCachePriority.browsed.rawValue,
             modified: (try? url.resourceValues(forKeys: [key]))?.contentModificationDate ?? .distantPast)
        }
        // Most expendable first: worst tier, and oldest within a tier.
        let doomed = ranked.sorted { lhs, rhs in
            lhs.tier == rhs.tier ? lhs.modified < rhs.modified : lhs.tier > rhs.tier
        }

        var next = tiers
        for entry in doomed.prefix(files.count - maxEntries) {
            try? fileManager.removeItem(at: entry.url)
            next.removeValue(forKey: entry.url.lastPathComponent)
        }
        writeIndex(next)
    }

    private static func rgba(from color: Color) -> [Double]? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return [Double(r), Double(g), Double(b), Double(a)]
    }
}
