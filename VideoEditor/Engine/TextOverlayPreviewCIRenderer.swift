//
// TextOverlayPreviewCIRenderer
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Thread-safe rasterization of `TextOverlayDescriptor` + `TransformEffect` to full-frame
//  premultiplied `CIImage` for the preview compositor. Layout matches `TextOverlayRenderingService`
//  (1080p-tall font reference, same pixel box math). NSCache avoids redundant CoreGraphics work
//  while text/transform/opacity are unchanged.

import CoreGraphics
import CoreImage
import CoreMedia
import CoreText
import Foundation

// MARK: - Composition payload (read by custom video compositor)

struct PreviewTextOverlaySpec: Sendable {
    let visibleTimeRange: CMTimeRange
    let descriptor: TextOverlayDescriptor
    let transform: TransformEffect
    let opacity: Float
}

// MARK: - Renderer + cache

final class TextOverlayPreviewCIRenderer: @unchecked Sendable {

    static let shared = TextOverlayPreviewCIRenderer()

    private let cache = NSCache<NSString, CIImage>()
    private static let referenceCompositionHeight: CGFloat = 1080

    private init() {
        cache.countLimit = 48
    }

    func ciImageFullFrame(for spec: PreviewTextOverlaySpec, renderSize: CGSize) -> CIImage? {
        guard renderSize.width > 1, renderSize.height > 1 else { return nil }
        let key = Self.cacheKey(for: spec, renderSize: renderSize) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = Self.rasterize(spec: spec, renderSize: renderSize) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func invalidateAllCaches() {
        cache.removeAllObjects()
    }

    // MARK: - Raster (background thread safe; no UIKit)

    private static func rasterize(spec: PreviewTextOverlaySpec, renderSize: CGSize) -> CIImage? {
        let w = Int(max(1, renderSize.width.rounded(.down)))
        let h = Int(max(1, renderSize.height.rounded(.down)))
        let box = layoutBox(transform: spec.transform, renderSize: CGSize(width: w, height: h))
        guard box.width >= 1, box.height >= 1 else { return nil }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)

        ctx.saveGState()
        ctx.translateBy(x: box.midX, y: box.midY)
        ctx.rotate(by: spec.transform.rotationAngle)
        ctx.translateBy(x: -box.midX, y: -box.midY)

        if let bgHex = spec.descriptor.backgroundColorHex,
           let bg = rgbColor(fromHex: bgHex) {
            ctx.setFillColor(bg)
            ctx.fill(box)
        }

        let fontSize = scaledPointSize(from: spec.descriptor, compositionHeight: CGFloat(h))
        let ctFont = CTFontCreateWithName(spec.descriptor.fontName as CFString, fontSize, nil)

        let textColor = rgbColor(fromHex: spec.descriptor.textColorHex) ?? CGColor(gray: 1, alpha: 1)

        let paragraph = Self.makeParagraphStyle(alignment: spec.descriptor.alignmentMode.ctAlignment)

        let attrs: [NSAttributedString.Key: Any] = [
            kCTFontAttributeName as NSAttributedString.Key: ctFont,
            kCTForegroundColorAttributeName as NSAttributedString.Key: textColor,
            kCTParagraphStyleAttributeName as NSAttributedString.Key: paragraph,
        ]
        let attrString = NSAttributedString(string: spec.descriptor.text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
        let path = CGPath(rect: box.insetBy(dx: 6, dy: 4), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attrString.length), path, nil)
        CTFrameDraw(frame, ctx)

        ctx.restoreGState()

        guard let cgImage = ctx.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }

    private static func layoutBox(transform: TransformEffect, renderSize: CGSize) -> CGRect {
        let w = max(transform.normalizedSize.width * renderSize.width * transform.normalizedScale, 44)
        let h = max(transform.normalizedSize.height * renderSize.height * transform.normalizedScale, 1)
        let cx = transform.normalizedCenter.x * renderSize.width
        let cy = transform.normalizedCenter.y * renderSize.height
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    private static func makeParagraphStyle(alignment: CTTextAlignment) -> CTParagraphStyle {
        var align = alignment
        return withUnsafePointer(to: &align) { ptr in
            let setting = CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: UnsafeRawPointer(ptr)
            )
            return CTParagraphStyleCreate([setting], 1)
        }
    }

    private static func scaledPointSize(from descriptor: TextOverlayDescriptor, compositionHeight: CGFloat) -> CGFloat {
        let scale = compositionHeight / referenceCompositionHeight
        return max(1, descriptor.fontSize * scale)
    }

    private static func cacheKey(for spec: PreviewTextOverlaySpec, renderSize: CGSize) -> String {
        let d = spec.descriptor
        let t = spec.transform
        let w = Int(renderSize.width)
        let h = Int(renderSize.height)
        return """
        \(d.text)|\(d.fontName)|\(d.fontSize)|\(d.textColorHex)|\(d.backgroundColorHex ?? "")|\
        \(d.alignmentMode.rawValue)|\
        \(t.normalizedCenter.x),\(t.normalizedCenter.y)|\(t.normalizedSize.width),\(t.normalizedSize.height)|\
        \(t.normalizedScale)|\(t.rotationAngle)|\(spec.opacity)|\(w)x\(h)
        """
    }

    private static func rgbColor(fromHex hexString: String) -> CGColor? {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        return CGColor(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Alignment → Core Text

private extension TextOverlayTextAlignment {
    var ctAlignment: CTTextAlignment {
        switch self {
        case .natural: return .natural
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}

// MARK: - Compositor helper

enum PreviewTextOverlayCompositor {

    static func composite(
        specs: [PreviewTextOverlaySpec],
        onto base: CIImage?,
        at time: CMTime,
        renderSize: CGSize
    ) -> CIImage? {
        let rect = CGRect(origin: .zero, size: renderSize)
        var output = base
        for spec in specs where spec.visibleTimeRange.containsTime(time) {
            guard let textLayer = TextOverlayPreviewCIRenderer.shared.ciImageFullFrame(for: spec, renderSize: renderSize) else {
                continue
            }
            let faded: CIImage
            if spec.opacity < 1 {
                faded = textLayer.applyingPreviewVideoAlpha(CGFloat(spec.opacity))
            } else {
                faded = textLayer
            }
            if let prev = output {
                output = faded.composited(over: prev).cropped(to: rect)
            } else {
                output = faded.cropped(to: rect)
            }
        }
        return output
    }
}
