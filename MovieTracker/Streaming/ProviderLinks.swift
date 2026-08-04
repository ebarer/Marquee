//
//  ProviderLinks.swift
//  MovieTracker
//

import Foundation

/// Universal links that open a service's app or website. TMDB has no per-title
/// provider links, so these land on the service's home.
enum ProviderLinks {
    static func appURL(for providerID: Int) -> URL? {
        links[providerID].flatMap { URL(string: $0) }
    }

    private static let links: [Int: String] = [
        8: "https://www.netflix.com",           // Netflix
        1796: "https://www.netflix.com",        // Netflix Standard with Ads
        9: "https://www.primevideo.com",        // Amazon Prime Video
        10: "https://www.primevideo.com",       // Amazon Video
        2100: "https://www.primevideo.com",     // Amazon Prime Video with Ads
        337: "https://www.disneyplus.com",      // Disney+
        1899: "https://play.max.com",           // Max
        384: "https://play.max.com",            // HBO Max
        15: "https://www.hulu.com",             // Hulu
        350: "https://tv.apple.com",            // Apple TV+
        2: "https://tv.apple.com",              // Apple TV
        531: "https://www.paramountplus.com",   // Paramount+
        1853: "https://www.paramountplus.com",  // Paramount+ with Showtime
        386: "https://www.peacocktv.com",       // Peacock Premium
        387: "https://www.peacocktv.com",       // Peacock Premium Plus
        43: "https://www.starz.com",            // Starz
        37: "https://www.sho.com",              // Showtime
        283: "https://www.crunchyroll.com",     // Crunchyroll
        73: "https://tubitv.com",               // Tubi
        300: "https://pluto.tv",                // Pluto TV
        538: "https://watch.plex.tv",           // Plex
        613: "https://www.amazon.com/freevee",  // Amazon Freevee
        207: "https://therokuchannel.roku.com", // The Roku Channel
        257: "https://www.fubo.tv",             // Fubo
        192: "https://www.youtube.com",         // YouTube
    ]
}
