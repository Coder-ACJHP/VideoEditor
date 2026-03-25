//
//  FileSizeFormatter.swift
//  VideoEditor
//
//  Stateless helpers for converting raw byte counts to human-readable strings
//  (KB / MB / GB) and for summing the on-disk size of a set of local file URLs.
//
//  Design decisions
//  ────────────────
//  • Implemented as a caseless `enum` – same pattern as `RelativeDateFormatter`.
//  • `ByteCountFormatter` is cached; it is thread-safe for reading after init.
//  • `countStyle = .file` matches the convention used by Finder / iOS Files app.
//  • `totalBytes(of:)` silently skips files it cannot stat, which is the correct
//    graceful-degradation behaviour when a file has been deleted externally.

import Foundation

enum FileSizeFormatter {

    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f
    }()

    /// Formats a raw byte count as a locale-aware string, e.g. `"2.4 MB"`.
    static func string(fromByteCount bytes: Int64) -> String {
        formatter.string(fromByteCount: max(0, bytes))
    }

    /// Returns the combined on-disk size of all provided local file `URL`s.
    /// Files that cannot be stat'd (deleted, inaccessible) contribute 0 bytes.
    static func totalBytes(of urls: [URL]) -> Int64 {
        urls.reduce(into: Int64(0)) { total, url in
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
    }
}
