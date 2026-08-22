//
//  CSVParser.swift
//  MovieTracker
//

import Foundation

/// A minimal RFC 4180 CSV reader: quoted fields, embedded commas and newlines, doubled quotes.
enum CSVParser {
    // Scalars, not Characters: Swift treats CRLF as one grapheme, so a Character scan matched neither
    // "\r" nor "\n" and read a whole Windows or Excel file as a single row.
    static func rows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = String.UnicodeScalarView()
        var row: [String] = []
        var inQuotes = false
        var iterator = text.unicodeScalars.makeIterator()
        var pending: Unicode.Scalar?

        func nextScalar() -> Unicode.Scalar? {
            if let queued = pending { pending = nil; return queued }
            return iterator.next()
        }

        func endField() { row.append(String(field)); field = String.UnicodeScalarView() }
        func endRow() {
            endField()
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while let scalar = nextScalar() {
            if inQuotes {
                if scalar == "\"" {
                    if let peek = nextScalar() {
                        if peek == "\"" { field.append("\"") }
                        else { inQuotes = false; pending = peek }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else {
                switch scalar {
                case "\"": inQuotes = true
                case ",": endField()
                case "\n": endRow()
                case "\r":
                    // Swallow the \n of a CRLF pair.
                    if let peek = nextScalar(), peek != "\n" { pending = peek }
                    endRow()
                default: field.append(scalar)
                }
            }
        }

        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }
}
