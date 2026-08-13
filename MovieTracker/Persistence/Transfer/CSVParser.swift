//
//  CSVParser.swift
//  MovieTracker
//

import Foundation

/// A minimal RFC 4180 CSV reader: handles quoted fields, embedded commas and
/// newlines, and doubled quotes as an escaped quote.
enum CSVParser {
    static func rows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character?

        func nextChar() -> Character? {
            if let queued = pending { pending = nil; return queued }
            return iterator.next()
        }

        func endField() { row.append(field); field = "" }
        func endRow() {
            endField()
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while let char = nextChar() {
            if inQuotes {
                if char == "\"" {
                    if let peek = nextChar() {
                        if peek == "\"" { field.append("\"") }
                        else { inQuotes = false; pending = peek }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"": inQuotes = true
                case ",": endField()
                case "\n": endRow()
                case "\r":
                    // Swallow the \n of a CRLF pair.
                    if let peek = nextChar(), peek != "\n" { pending = peek }
                    endRow()
                default: field.append(char)
                }
            }
        }

        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }
}
