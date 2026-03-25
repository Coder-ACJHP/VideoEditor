//
//  ThumbnailGenerating.swift
//  VideoEditor
//
//  Domain-layer protocol that decouples thumbnail generation from its
//  concrete transport (AVFoundation, PHImageManager, etc.).
//  Conforming types own caching and cancellation strategies internally,
//  so callers stay unaware of those details.
//
//  Adopted by:
//  - LocalThumbnailService   (Data layer – local file / AVURLAsset)
//  - Future: PHAssetThumbnailService  (Photos library assets)
//  Used by:
//  - ProjectCell             (Landing screen)
//  - TimelineThumbnailView   (Editor – future)

import UIKit

protocol ThumbnailGenerating: AnyObject, Sendable {

    /// Returns a thumbnail for the given `AssetIdentifier` at the requested pixel `size`.
    /// - Returns: A `UIImage` on success, `nil` if the asset is unsupported or an error occurs.
    /// - Note: Implementations are expected to cache results and serve them synchronously
    ///   on cache hit to avoid visible flicker during cell reuse.
    func thumbnail(for asset: AssetIdentifier, size: CGSize) async -> UIImage?
}
