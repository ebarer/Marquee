//
//  String+Extension.swift
//  MovieTracker
//
//  Created by Elliot Barer on 11/12/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import UIKit

extension String {
    func toDate(format: DateFormatter.DateFormats) -> Date? {
        switch format {
        case .iso8601DAw:
            return DateFormatter.iso8601DAw.date(from: self)
        case .iso8601DTw:
            return DateFormatter.iso8601DTw.date(from: self)
        }
    }
    
    func matches(query: String) -> Bool {
        func fold(_ text: String) -> String {
            text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
        let folded = fold(self)
        if folded.contains(fold(query)) { return true }
        // "SNL" is how people type Saturday Night Live, and the initialism is not in the title.
        guard let expansion = SearchMatching.initialismExpansion(of: query) else { return false }
        return folded.contains(fold(expansion))
    }

    func shorten() -> String {
        switch self {
        case "Science Fiction":
            return "Sci-Fi"
        case "Documentary":
            return "Docu."
        default:
            return self
        }
    }
}
