//
//  ThumbnailGenerating.swift
//  VideoEditor
//
//  Domain-layer protocol that decouples thumbnail generation from its
//  concrete transport (AVFoundation, PHImageManager, etc.).
//  Conforming types own caching and cancellation strategies internally,
//  so callers stay unaware of those details.

import UIKit

protocol ThumbnailGenerating: AnyObject, Sendable {

    /// Returns a single representative thumbnail (typically at t=0) for the asset.
    func thumbnail(for asset: AssetIdentifier, size: CGSize) async -> UIImage?

    /// Returns a video frame at a specific time offset (seconds).
    /// For non-video assets the implementation should return `nil`.
    func videoFrame(for asset: AssetIdentifier, at seconds: Double, size: CGSize) async -> UIImage?
}
