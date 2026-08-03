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
