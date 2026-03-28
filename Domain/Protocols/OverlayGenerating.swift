//
//  OverlayGenerating.swift
//  VideoEditor
//
//  Metin overlay için UI önizlemesi (bitmap) ve export (CALayer) üretim sözleşmesi.

import QuartzCore
import UIKit

/// Uygulama katmanında `MainActor` üzerinde çalışan somut servis beklenir.
protocol OverlayGenerating: AnyObject, Sendable {

    /// Düşük gecikmeli canvas önizlemesi; `canvasSize` point cinsinden.
    func generatePreviewImage(
        for descriptor: TextOverlayDescriptor,
        transform: TransformEffect,
        canvasSize: CGSize
    ) async -> UIImage?

    /// Export motoru için composition piksel alanında konumlandırılmış katman ağacı.
    func generateExportLayer(
        for descriptor: TextOverlayDescriptor,
        transform: TransformEffect,
        compositionSize: CGSize
    ) async -> CALayer?
}
