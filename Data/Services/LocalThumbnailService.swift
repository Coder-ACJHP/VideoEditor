//
//  LocalThumbnailService.swift
//  VideoEditor
//
//  Concrete ThumbnailGenerating implementation for locally stored assets.
//
//  Strategy
//  ────────
//  • Images  → CGImageSource downsample (avoids full-res decode).
//  • Videos  → AVAssetImageGenerator, applying preferred track transform.
//  • PHAsset cases are not yet supported (return nil until PHImageManager integration).
//
//  Caching
//  ───────
//  NSCache keyed on "<assetKey>@<WxH>" (representative) or
//  "<assetKey>@<t>s-<WxH>" (time-based) so identical requests are served
//  from memory. The cache is per-instance; sharing one instance across
//  screens gives cross-screen reuse.
//
//  Thread Safety
//  ─────────────
//  NSCache is thread-safe. All heavy work is dispatched to a dedicated
//  serial queue to prevent saturating the UI thread.

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
        case .image(let url):              await loadDownsampledImage(from: url, targetSize: size)
        case .video(let url):              await generateVideoFrame(from: url, at: 0, size: size)
        case .audio:                       nil
        case .phAssetVideo, .phAssetImage: nil
        }

        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    func videoFrame(for asset: AssetIdentifier, at seconds: Double, size: CGSize) async -> UIImage? {
        guard case .video(let url) = asset else { return nil }

        let key = frameCacheKey(for: asset, seconds: seconds, size: size) as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let image = await generateVideoFrame(from: url, at: seconds, size: size)
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    // MARK: - Private Helpers

    private func assetKeyPart(_ asset: AssetIdentifier) -> String {
        switch asset {
        case .image(let url), .video(let url), .audio(let url):
            return url.absoluteString
        case .phAssetVideo(let id), .phAssetImage(let id):
            return id
        }
    }

    private func cacheKey(for asset: AssetIdentifier, size: CGSize) -> String {
        "\(assetKeyPart(asset))@\(Int(size.width))x\(Int(size.height))"
    }

    private func frameCacheKey(for asset: AssetIdentifier, seconds: Double, size: CGSize) -> String {
        "\(assetKeyPart(asset))@\(String(format: "%.1f", seconds))s-\(Int(size.width))x\(Int(size.height))"
    }

    private func loadDownsampledImage(from url: URL, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            workQueue.async { [self] in
                guard let data = try? Data(contentsOf: url) else {
                    continuation.resume(returning: nil)
                    return
                }
                let scale = UIScreen.main.scale
                let result = downsample(data: data, targetSize: targetSize, scale: scale)
                continuation.resume(returning: result)
            }
        }
    }

    private func generateVideoFrame(from url: URL, at seconds: Double, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            workQueue.async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = size

                let time = CMTime(seconds: seconds, preferredTimescale: 600)
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Creates a thumbnail-sized `UIImage` from raw data using `CGImageSource`,
    /// avoiding a full-resolution decode.
    private nonisolated func downsample(data: Data, targetSize: CGSize, scale: CGFloat) -> UIImage? {
        
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        
        let maxDimension = max(targetSize.width, targetSize.height) * scale
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, downsampleOptions as CFDictionary
        ) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
