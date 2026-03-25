//
//  RelativeDateFormatter.swift
//  VideoEditor
//
//  Lightweight stateless helper that converts a past `Date` into a
//  human-readable relative string such as "2h ago" or "3d ago".
//
//  Design decisions
//  ────────────────
//  • Implemented as a caseless `enum` to prevent instantiation; all surface
//    area is static, making it behave like a namespace.
//  • `DateComponentsFormatter` is cached as a static let because initialisation
//    is expensive and the formatter is thread-safe for reading.
//  • `maximumUnitCount = 1` intentionally shows only the dominant unit (hours,
//    not "2h 14m") to match common short-form UX patterns (iOS Photos, Notion…).

import Foundation

enum RelativeDateFormatter {

    private static let formatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 1
        f.allowedUnits = [.second, .minute, .hour, .day, .weekOfMonth, .month, .year]
        return f
    }()

    /// Returns a string like `"2h ago"`, `"3d ago"`, `"just now"` (< 1 s).
    ///
    /// - Parameters:
    ///   - date:      The past date to measure from.
    ///   - reference: The "now" reference (defaults to `Date()`).  Exposed for
    ///                unit-test determinism.
    static func string(from date: Date, relativeTo reference: Date = Date()) -> String {
        let elapsed = max(0, reference.timeIntervalSince(date))
        guard elapsed >= 1, let abbr = formatter.string(from: elapsed) else {
            return "just now"
        }
        return "\(abbr) ago"
    }
}
