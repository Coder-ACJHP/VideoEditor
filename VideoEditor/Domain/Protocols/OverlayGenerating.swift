//
// OverlayGenerating
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Contract for text-overlay preview images (bitmap) and export layers (`CALayer`).

import QuartzCore
import UIKit

/// Concrete types are expected to run on `MainActor` at the app layer.
protocol OverlayGenerating: AnyObject, Sendable {

    /// Low-latency canvas preview; `canvasSize` is in points.
    func generatePreviewImage(
        for descriptor: TextOverlayDescriptor,
        transform: TransformEffect,
        canvasSize: CGSize
    ) async -> UIImage?

    /// Layer tree positioned in composition pixel space for the export pipeline.
    func generateExportLayer(
        for descriptor: TextOverlayDescriptor,
        transform: TransformEffect,
        compositionSize: CGSize
    ) async -> CALayer?
}
