//
//  TextOverlayRenderingService.swift
//  VideoEditor
//
//  `TextOverlayDescriptor` + `TransformEffect` → UIKit önizleme görüntüsü veya
//  export için `CALayer` (CATextLayer). Font boyutu 1080p yükseklik referansına göre ölçeklenir.

import CoreGraphics
import CoreText
import QuartzCore
import UIKit

final class TextOverlayRenderingService: OverlayGenerating, @unchecked Sendable {

    /// Dikey referans; `descriptor.fontSize` bu yükseklikteki nokta boyutudur.
    private static let referenceCompositionHeight: CGFloat = 1080

    /// Bu yüksekliğin altındaki canvas’lar timeline şeridi kabul edilir; normalize kutu yerine tüm karo kullanılır.
    private static let timelineStripPreviewHeightThreshold: CGFloat = 56

    init() {}

    func generatePreviewImage(
        for descriptor: TextOverlayDescriptor,
        transform: TransformEffect,
        canvasSize: CGSize
    ) async -> UIImage? {
        await MainActor.run {
            renderPreviewImage(for: descriptor, transform: transform, canvasSize: canvasSize)
        }
    }

    func generateExportLayer(
        for descriptor: TextOverlayDescriptor,
        transform: TransformEffect,
        compositionSize: CGSize
    ) async -> CALayer? {
        await MainActor.run {
            buildExportLayerTree(for: descriptor, transform: transform, compositionSize: compositionSize)
        }
    }

    // MARK: - Preview (UIKit)

    private func renderPreviewImage(
        for descriptor: TextOverlayDescriptor,
        transform: TransformEffect,
        canvasSize: CGSize
    ) -> UIImage? {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return nil }

        if canvasSize.height <= Self.timelineStripPreviewHeightThreshold {
            return renderTimelineStripPreview(for: descriptor, canvasSize: canvasSize)
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.clear(CGRect(origin: .zero, size: canvasSize))

            let box = pixelRect(transform: transform, in: canvasSize)
            cg.saveGState()
            cg.translateBy(x: box.midX, y: box.midY)
            cg.rotate(by: transform.rotationAngle)
            cg.translateBy(x: -box.midX, y: -box.midY)

            if let bgHexColor = descriptor.backgroundColorHex {
                let bg = UIColor(hexString: bgHexColor)
                cg.setFillColor(bg.cgColor)
                cg.fill(box)
            }

            let textColor = UIColor(hexString: descriptor.textColorHex)
            let scaledFont = Self.scaledFont(from: descriptor, compositionHeight: canvasSize.height)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: scaledFont,
                .foregroundColor: textColor,
                .paragraphStyle: paragraph,
            ]
            let inset = box.insetBy(dx: 6, dy: 4)
            (descriptor.text as NSString).draw(with: inset, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
            cg.restoreGState()
        }
    }

    /// Timeline overlay şeridi (~36 pt yükseklik): `identity` transform ile kutu neredeyse sıfır kalırdı; metni tüm karoda çizeriz.
    private func renderTimelineStripPreview(for descriptor: TextOverlayDescriptor, canvasSize: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { _ in
            let bg = descriptor.backgroundColorHex.map { UIColor(hexString: $0) }
            if let bg {
                bg.setFill()
                UIBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()
            }

            let insetH: CGFloat = 4
            let insetV: CGFloat = 2
            let drawRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: insetH, dy: insetV)
            guard drawRect.width > 4, drawRect.height > 4 else { return }

            let textColor = UIColor(hexString: descriptor.textColorHex)
            let stripFontSize = Self.timelineStripFontSize(canvasSize: canvasSize)
            let baseFont = UIFont(name: descriptor.fontName, size: stripFontSize)
                ?? .systemFont(ofSize: stripFontSize, weight: .semibold)

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingTail

            let attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: textColor,
                .paragraphStyle: paragraph,
            ]

            (descriptor.text as NSString).draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
                attributes: attrs,
                context: nil
            )
        }
    }

    private static func timelineStripFontSize(canvasSize: CGSize) -> CGFloat {
        let h = canvasSize.height
        let w = canvasSize.width
        let fromHeight = h * 0.52
        let fromWidth = w * 0.14
        return max(12, min(max(fromHeight, fromWidth), min(h * 0.72, 20)))
    }

    // MARK: - Export (Core Animation)

    private func buildExportLayerTree(
        for descriptor: TextOverlayDescriptor,
        transform: TransformEffect,
        compositionSize: CGSize
    ) -> CALayer? {
        guard compositionSize.width > 1, compositionSize.height > 1 else { return nil }

        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: compositionSize)
        root.masksToBounds = true

        let box = pixelRect(transform: transform, in: compositionSize)
        let container = CALayer()
        container.bounds = CGRect(x: 0, y: 0, width: box.width, height: box.height)
        container.position = CGPoint(x: box.midX, y: box.midY)
        container.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        container.transform = CATransform3DMakeRotation(transform.rotationAngle, 0, 0, 1)

        if let bgColorHex = descriptor.backgroundColorHex {
            let bg = UIColor(hexString: bgColorHex).cgColor
            let backgroundLayer = CALayer()
            backgroundLayer.frame = container.bounds
            backgroundLayer.backgroundColor = bg
            container.addSublayer(backgroundLayer)
        }

        let textLayer = CATextLayer()
        textLayer.frame = container.bounds.insetBy(dx: 6, dy: 4)
        let renderScale = max(2, UIScreen.main.scale)
        textLayer.contentsScale = renderScale
        textLayer.alignmentMode = .center
        textLayer.isWrapped = true
        textLayer.truncationMode = .end

        let scaledSize = Self.scaledPointSize(from: descriptor, compositionHeight: compositionSize.height)
        let ctFont = CTFontCreateWithName(descriptor.fontName as CFString, scaledSize, nil)
        textLayer.font = ctFont
        textLayer.fontSize = scaledSize
        textLayer.string = descriptor.text
        textLayer.foregroundColor = (UIColor(hexString: descriptor.textColorHex)).cgColor

        container.addSublayer(textLayer)
        root.addSublayer(container)
        return root
    }

    // MARK: - Layout

    private func pixelRect(transform: TransformEffect, in size: CGSize) -> CGRect {
        let w = max(transform.normalizedSize.width * size.width, 1)
        let h = max(transform.normalizedSize.height * size.height, 1)
        let cx = transform.normalizedCenter.x * size.width
        let cy = transform.normalizedCenter.y * size.height
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    private static func scaledPointSize(from descriptor: TextOverlayDescriptor, compositionHeight: CGFloat) -> CGFloat {
        let scale = compositionHeight / referenceCompositionHeight
        return max(1, descriptor.fontSize * scale)
    }

    private static func scaledFont(from descriptor: TextOverlayDescriptor, compositionHeight: CGFloat) -> UIFont {
        let size = scaledPointSize(from: descriptor, compositionHeight: compositionHeight)
        return UIFont(name: descriptor.fontName, size: size)
            ?? .systemFont(ofSize: size, weight: .bold)
    }
}
