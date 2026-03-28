//
//  AssetDurationResolver.swift
//  VideoEditor
//
//  Centralizes AVFoundation-based duration reads so presentation layer
//  stays free from framework-specific media probing logic.
//

import Foundation
import AVFoundation

enum AssetDurationResolver {

    /// Returns source duration in seconds for URL-backed audio/video assets.
    /// Returns nil for image/PHAsset cases or invalid durations.
    static func sourceDuration(for asset: AssetIdentifier) async -> Double? {
        switch asset {
        case .audio(let url), .video(let url):
            let seconds = try? await AVURLAsset(url: url).load(.duration).seconds
            guard let seconds, seconds.isFinite, seconds > 0 else { return nil }
            return seconds
        case .image, .phAssetImage, .phAssetVideo, .text:
            return nil
        }
    }
}
