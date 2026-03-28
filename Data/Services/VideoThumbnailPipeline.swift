//
//  VideoThumbnailPipeline.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 28.03.2026.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Per-URL serial decode

/// `AVAssetImageGenerator` is not safe for concurrent use. One actor per file serializes all
/// `image(at:)` work for that URL so parallel `Task`s cannot overlap on the same generator.
actor VideoThumbnailPipeline {

    private let url: URL
    private var generator: AVAssetImageGenerator?

    init(url: URL) {
        self.url = url
    }

    func decodeFrame(
        at seconds: Double,
        sizePoints: CGSize,
        screenScale: CGFloat,
        maxPixelLongEdge: CGFloat
    ) async -> UIImage? {
        let gen: AVAssetImageGenerator
        if let existing = generator {
            gen = existing
        } else {
            let asset = AVURLAsset(url: url)
            let g = AVAssetImageGenerator(asset: asset)
            g.appliesPreferredTrackTransform = true
            generator = g
            gen = g
        }

        // Keyframe-aligned: much lower CPU than sample-accurate seeks.
        gen.requestedTimeToleranceBefore = .positiveInfinity
        gen.requestedTimeToleranceAfter = .positiveInfinity

        var w = max(1, sizePoints.width * screenScale)
        var h = max(1, sizePoints.height * screenScale)
        let longEdge = max(w, h)
        let cap = max(32, maxPixelLongEdge)
        if longEdge > cap {
            let r = cap / longEdge
            w = max(1, floor(w * r))
            h = max(1, floor(h * r))
        }
        gen.maximumSize = CGSize(width: w, height: h)

        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await gen.image(at: time)
            return autoreleasepool {
                UIImage(cgImage: cgImage)
            }
        } catch {
            return nil
        }
    }
}
