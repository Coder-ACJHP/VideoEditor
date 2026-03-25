//
//  LocalThumbnailService.swift
//  VideoEditor
//
//  Concrete ThumbnailGenerating implementation for locally stored assets.
//
//  Strategy
//  ────────
//  • Images  → UIImage(contentsOfFile:) on a background thread.
//  • Videos  → AVAssetImageGenerator at t=0, applying preferred track transform.
//  • PHAsset cases are not yet supported (return nil until PHImageManager integration).
//
//  Caching
//  ───────
//  NSCache is used keyed on "<assetKey>-<WxH>" so the same asset at different
//  sizes gets independent entries. The cache is per-instance, so callers that
//  share one instance across screens benefit from cross-screen reuse (e.g. the
//  same thumbnail shown in Landing and in the Editor timeline).
//
//  Thread Safety
//  ─────────────
//  NSCache is thread-safe. All heavy work is dispatched to a dedicated serial
//  queue to prevent saturating the UI thread.

import AVFoundation
import UIKit

final class LocalThumbnailService: ThumbnailGenerating {

    // MARK: - Private

    private let cache = NSCache<NSString, UIImage>()
    private let workQueue = DispatchQueue(label: "com.videoeditor.thumbnail", qos: .userInitiated)

    // MARK: - ThumbnailGenerating

    func thumbnail(for asset: AssetIdentifier, size: CGSize) async -> UIImage? {
        let key = cacheKey(for: asset, size: size) as NSString

        if let cached = cache.object(forKey: key) { return cached }

        let image: UIImage? = switch asset {
        case .image(let url):           await loadImage(from: url)
        case .video(let url):           await generateVideoThumbnail(from: url, size: size)
        case .audio:                    nil
        case .phAssetVideo, .phAssetImage: nil  // PHImageManager integration pending
        }

        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    // MARK: - Private Helpers

    private func cacheKey(for asset: AssetIdentifier, size: CGSize) -> String {
        let assetPart: String
        switch asset {
        case .image(let url), .video(let url), .audio(let url):
            assetPart = url.absoluteString
        case .phAssetVideo(let id), .phAssetImage(let id):
            assetPart = id
        }
        return "\(assetPart)@\(Int(size.width))x\(Int(size.height))"
    }

    private func loadImage(from url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            workQueue.async {
                continuation.resume(returning: UIImage(contentsOfFile: url.path))
            }
        }
    }

    private func generateVideoThumbnail(from url: URL, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            workQueue.async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = size

                do {
                    let cgImage = try generator.copyCGImage(
                        at: CMTime(seconds: 0, preferredTimescale: 600),
                        actualTime: nil
                    )
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
