//
// AssetIdentifier
// VideoEditor
// Created by Coder ACJHP on 27.03.2026.

//  Where media comes from and what kind it is, in one enum.
//  The engine switches on this to choose the pipeline (AVURLAsset, PHAsset fetch, CALayer, etc.).

import Foundation

nonisolated enum AssetIdentifier: Codable, Hashable {

    /// Local video file in the app sandbox.
    case video(URL)
    /// Local audio file in the app sandbox.
    case audio(URL)
    /// Local image file in the app sandbox. The engine treats this as a still; `sourceRange` is ignored.
    case image(URL)

    /// Text overlay: no raster file; content is `TextOverlayDescriptor` + `MediaClip.transform`.
    case text(TextOverlayDescriptor)

    /// Video from the Photos library (`localIdentifier`).
    case phAssetVideo(String)
    /// Photo from the Photos library (`localIdentifier`).
    case phAssetImage(String)

    // MARK: - Derived

    var mediaType: MediaType {
        switch self {
        case .video, .phAssetVideo: return .video
        case .audio:                return .audio
        case .image, .phAssetImage: return .image
        case .text:                 return .text
        }
    }

    enum MediaType: String, Codable {
        /// Playable video; both `sourceRange` and `timelineRange` apply in full.
        case video
        /// Audio only; not placed on a video track.
        case audio
        /// Still frame; the engine ignores `sourceRange`; visible duration comes from `timelineRange.durationSeconds`.
        case image
        /// Text overlay; duration from `timelineRange`, layout from `MediaClip.transform`.
        case text
    }
}
