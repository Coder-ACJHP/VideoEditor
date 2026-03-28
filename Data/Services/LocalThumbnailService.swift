//
//  LocalThumbnailService.swift
//  VideoEditor
//

import AVFoundation
import UIKit
import ImageIO

// MARK: - Service Uses `VideoThumbnailPipeline`

final actor LocalThumbnailService: ThumbnailGenerating {

    // MARK: - Private Properties

    private let overlayGenerating: OverlayGenerating

    /// `NSCache` is thread-safe. With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, keeping this
    /// actor-isolated would make UIImage-backed cache access cross isolation incorrectly; `unsafe`
    /// documents that we rely on NSCache’s own synchronization instead of the actor for this field.
    nonisolated(unsafe) private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    private var pipelines: [URL: VideoThumbnailPipeline] = [:]

    init(overlayGenerating: OverlayGenerating = TextOverlayRenderingService()) {
        self.overlayGenerating = overlayGenerating
    }

    // MARK: - Public Interface

    func thumbnail(for asset: AssetIdentifier, size: CGSize) async -> UIImage? {
        let key = cacheKey(for: asset, size: size)

        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        let image: UIImage?
        switch asset {
        case .image(let url):
            image = await loadDownsampledImage(from: url, targetSize: size)
        case .video(let url):
            let scale = await MainActor.run { UIScreen.main.scale }
            let requested = max(size.width, size.height) * scale
            let cap = min(480, max(requested, 1))
            image = await pipeline(for: url).decodeFrame(
                at: 0,
                sizePoints: size,
                screenScale: scale,
                maxPixelLongEdge: cap
            )
        case .text(let descriptor):
            image = await overlayGenerating.generatePreviewImage(
                for: descriptor,
                transform: .identity,
                canvasSize: size
            )
        default:
            image = nil
        }

        if let image {
            storeInCache(image, key: key as NSString)
        }
        return image
    }

    func videoFrame(for asset: AssetIdentifier, at seconds: Double, size: CGSize) async -> UIImage? {
        guard case .video(let url) = asset else { return nil }

        let key = frameCacheKey(for: asset, seconds: seconds, size: size)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        let scale = await MainActor.run { UIScreen.main.scale }
        let image = await pipeline(for: url).decodeFrame(
            at: seconds,
            sizePoints: size,
            screenScale: scale,
            maxPixelLongEdge: 144
        )

        if let image {
            storeInCache(image, key: key as NSString)
        }
        return image
    }

    // MARK: - Private Logic

    private func pipeline(for url: URL) -> VideoThumbnailPipeline {
        if let existing = pipelines[url] {
            return existing
        }
        let pipe = VideoThumbnailPipeline(url: url)
        pipelines[url] = pipe
        return pipe
    }

    private nonisolated func approximateByteCost(for image: UIImage) -> Int {
        if let cg = image.cgImage {
            return max(cg.bytesPerRow * cg.height, 8192)
        }
        let w = max(Int(image.size.width * image.scale), 1)
        let h = max(Int(image.size.height * image.scale), 1)
        return w * h * 4
    }

    private nonisolated func storeInCache(_ image: UIImage, key: NSString) {
        cache.setObject(image, forKey: key, cost: approximateByteCost(for: image))
    }

    /// `targetSize` is in points; one scale hop for pixel budget.
    private func loadDownsampledImage(from url: URL, targetSize: CGSize) async -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let scale = await MainActor.run { UIScreen.main.scale }
        let maxDimension = max(targetSize.width, targetSize.height) * scale

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return autoreleasepool {
            UIImage(cgImage: cgImage)
        }
    }

    // MARK: - Key Helpers

    private func assetKeyPart(_ asset: AssetIdentifier) -> String {
        switch asset {
        case .image(let url), .video(let url), .audio(let url): return url.path
        case .phAssetVideo(let id), .phAssetImage(let id): return id
        case .text(let d):
            return "text:\(d.text.hashValue)_\(d.fontName)_\(d.fontSize)_\(d.textColorHex)_\(d.backgroundColorHex ?? "")"
        }
    }

    private func cacheKey(for asset: AssetIdentifier, size: CGSize) -> String {
        "\(assetKeyPart(asset))_\(Int(size.width))x\(Int(size.height))"
    }

    private func frameCacheKey(for asset: AssetIdentifier, seconds: Double, size: CGSize) -> String {
        "\(assetKeyPart(asset))_\(String(format: "%.2f", seconds))_\(Int(size.width))x\(Int(size.height))"
    }
}
