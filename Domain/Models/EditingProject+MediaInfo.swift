//
//  EditingProject+MediaInfo.swift
//  VideoEditor
//
//  Read-only domain queries that derive media information from an EditingProject's
//  tracks and clips. Kept in a separate file so EditingProject.swift stays focused
//  on the model's identity and structure.

import Foundation

extension EditingProject {

    /// The `AssetIdentifier` of the first clip in the primary (video) track.
    /// Used by the UI to request a representative thumbnail for the project card.
    var firstAssetIdentifier: AssetIdentifier? {
        tracks.flatMap(\.clips).first?.asset
    }

    /// All unique local-file URLs referenced across all clips in the project.
    /// Excludes PHAsset-backed identifiers because those have no on-disk URL.
    /// Used for total-size calculation and for future cache warm-up.
    var allMediaURLs: [URL] {
        var seen = Set<URL>()
        for clip in tracks.flatMap(\.clips) {
            switch clip.asset {
            case .image(let url), .video(let url), .audio(let url):
                seen.insert(url)
            case .phAssetVideo, .phAssetImage, .text:
                break
            }
        }
        return Array(seen)
    }

    /// Combined byte size of all local media files referenced by this project.
    /// Delegates to `FileSizeFormatter` so no FileManager logic lives here.
    var totalByteSize: Int64 {
        FileSizeFormatter.totalBytes(of: allMediaURLs)
    }
}
