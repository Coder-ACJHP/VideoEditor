//
// VideoPreviewProtocolsAndStyle
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Protocols for preview `AVMutableComposition` + custom video compositor, plus per-clip CI visual style.
//

import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation

// MARK: - Timeline & composition source

/// Start time and duration of a video segment on the timeline.
protocol PreviewTimelineTiming: AnyObject {
    var startTime: CMTime { get set }
    var duration: CMTime { get }
}

extension PreviewTimelineTiming {
    var timeRange: CMTimeRange {
        CMTimeRange(start: startTime, duration: duration)
    }
}

/// Applies per-clip transform, opacity, and aspect-fit to a single frame.
protocol PreviewVideoFrameEffect: AnyObject {
    func applyEffect(to sourceImage: CIImage, at time: CMTime, renderSize: CGSize) -> CIImage
}

/// Source that inserts a video track into `AVMutableComposition` and may supply a transition into the next clip.
protocol PreviewCompositionVideoSource: PreviewTimelineTiming, PreviewVideoFrameEffect {
    /// Mirrors `MediaClip.transitionOut`; overlap with the next clip is read from here.
    var transitionOut: ClipTransition? { get }
    func numberOfVideoTracks() async -> Int
    @MainActor
    func videoCompositionTrack(
        for composition: AVMutableComposition,
        at index: Int,
        preferredTrackID: Int32
    ) async -> AVCompositionTrack?
}

// MARK: - Visual style (aspect-fit, opacity)

/// Context passed into style / `applyEffect` helpers.
struct PreviewFrameEffectContext {
    var time = CMTime.zero
    var renderSize = CGSize.zero
    var timeRange = CMTimeRange.zero
}

/// NSObject + NSCopying so video-composition layer instructions can copy style safely.
final class PreviewClipVisualStyle: NSObject, NSCopying {

    enum ContentMode {
        case aspectFit
    }

    var contentMode: ContentMode = .aspectFit
    var frame: CGRect?
    var transform: CGAffineTransform?
    var opacity: Float = 1

    override init() { super.init() }

    func copy(with zone: NSZone? = nil) -> Any {
        let copy = PreviewClipVisualStyle()
        copy.contentMode = contentMode
        copy.frame = frame
        copy.transform = transform
        copy.opacity = opacity
        return copy
    }

    func applyEffect(to sourceImage: CIImage, info: PreviewFrameEffectContext) -> CIImage {
        var finalImage = sourceImage
        if let userTransform = transform {
            var t = CGAffineTransform.identity
            let cx = finalImage.extent.origin.x + finalImage.extent.width / 2
            let cy = finalImage.extent.origin.y + finalImage.extent.height / 2
            t = t.concatenating(CGAffineTransform(translationX: -cx, y: -cy))
            t = t.concatenating(userTransform)
            t = t.concatenating(CGAffineTransform(translationX: cx, y: cy))
            finalImage = finalImage.transformed(by: t)
        }
        let targetFrame = frame ?? CGRect(origin: .zero, size: info.renderSize)
        switch contentMode {
        case .aspectFit:
            let t = PreviewVideoLayout.aspectFitTransform(sourceRect: finalImage.extent, in: targetFrame)
            finalImage = finalImage.transformed(by: t).cropped(to: targetFrame)
        }
        if opacity < 1 {
            finalImage = finalImage.applyingPreviewVideoAlpha(CGFloat(opacity))
        }
        return finalImage
    }
}

// MARK: - Layout (file-local helpers; avoids polluting global CGSize/CGRect extensions)

private enum PreviewVideoLayout {

    static func aspectFitTransform(sourceRect: CGRect, in targetRect: CGRect) -> CGAffineTransform {
        let fitRect = sourceRect.aspectFit(in: targetRect)
        let xRatio = fitRect.size.width / sourceRect.size.width
        let yRatio = fitRect.size.height / sourceRect.size.height
        return CGAffineTransform(
            translationX: fitRect.origin.x - sourceRect.origin.x * xRatio,
            y: fitRect.origin.y - sourceRect.origin.y * yRatio
        ).scaledBy(x: xRatio, y: yRatio)
    }
}

private extension CGSize {
    func aspectFit(in target: CGSize) -> CGSize {
        guard width > 0, height > 0 else { return target }
        let widthRatio = target.width / width
        let heightRatio = target.height / height
        if heightRatio < widthRatio {
            return CGSize(width: (heightRatio * width).rounded(), height: (heightRatio * height).rounded())
        }
        if widthRatio < heightRatio {
            return CGSize(width: (widthRatio * width).rounded(), height: (widthRatio * height).rounded())
        }
        return CGSize(width: (widthRatio * width).rounded(), height: (widthRatio * height).rounded())
    }
}

private extension CGRect {
    func aspectFit(in rect: CGRect) -> CGRect {
        let newSize = size.aspectFit(in: rect.size)
        let x = rect.origin.x + (rect.size.width - newSize.width) / 2
        let y = rect.origin.y + (rect.size.height - newSize.height) / 2
        return CGRect(x: x, y: y, width: newSize.width, height: newSize.height)
    }
}
