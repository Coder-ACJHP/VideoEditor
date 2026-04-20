//
// ClipTransition+PreviewRendering
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Preview compositor: `ClipTransition` is the single source of truth; CI blending lives here.
//

import CoreGraphics
import CoreImage
import Foundation

extension ClipTransition {

    /// One output frame for the overlap window between two clips. `tween` runs 0…1 across the transition.
    func renderImage(
        foregroundImage: CIImage,
        backgroundImage: CIImage,
        forTweenFactor tween: Float64,
        renderSize: CGSize
    ) -> CIImage {
        let rect = CGRect(origin: .zero, size: renderSize)
        let t = CGFloat(max(0, min(1, tween)))

        switch type {
            case .crossDissolve:
                return foregroundImage
                    .applyingPreviewVideoAlpha(t)
                    .composited(over: backgroundImage)
                    .cropped(to: rect)

            case .fadeToBlack:
                let black = CIImage(color: .black).cropped(to: rect)
                if t <= 0.5 {
                    let u = t * 2
                    return backgroundImage
                        .applyingPreviewVideoAlpha(1 - u)
                        .composited(over: black)
                        .cropped(to: rect)
                } else {
                    let u = (t - 0.5) * 2
                    return foregroundImage
                        .applyingPreviewVideoAlpha(u)
                        .composited(over: black)
                        .cropped(to: rect)
                }

            case .push:
                let w = renderSize.width
                let bgShift = -t * w
                let fgShift = (1 - t) * w
                let bg = backgroundImage.transformed(by: CGAffineTransform(translationX: bgShift, y: 0))
                let fg = foregroundImage.transformed(by: CGAffineTransform(translationX: fgShift, y: 0))
                return fg.composited(over: bg).cropped(to: rect)

            case .swipe:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)

                guard let filter = CIFilter.swipeTransitionFilter(
                    inputImage: bg,
                    inputTargetImage: fg,
                    inputExtent: CIVector(cgRect: rect),
                    inputColor: .white,
                    inputTime: NSNumber(value: Double(t))
                ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out

            case .slide:
                let w = renderSize.width
                let fgShift = (1 - t) * w
                let fg = foregroundImage.transformed(by: CGAffineTransform(translationX: fgShift, y: 0))
                return fg.composited(over: backgroundImage).cropped(to: rect)

            case .ripple:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                // UIKit top-left origin → Core Image bottom-left origin (matches reference project).
                let refHeight = fg.extent.height
                let atLocation = CGPoint(x: rect.midX, y: rect.midY)
                let ciCenter = CIVector(x: atLocation.x, y: refHeight - atLocation.y)
                let ciExtent = CIVector(x: 0, y: 0, z: renderSize.width, w: renderSize.height)
                guard let filter = CIFilter.rippleTransitionFilter(
                    inputImage: bg,
                    inputTargetImage: fg,
                    inputShadingImage: CIImage(),
                    inputCenter: ciCenter,
                    inputExtent: ciExtent,
                    inputTime: NSNumber(value: Double(t)),
                    inputWidth: NSNumber(value: 100),
                    inputScale: NSNumber(value: 50)
                ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out

            case .barsSwipe:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                // Same as presenting: from = outgoing, to = incoming; angle π; width/offset as in `animateTransition`.
                guard let filter = CIFilter.barsSwipeTransitionFilter(
                    inputImage: bg,
                    inputTargetImage: fg,
                    inputAngle: NSNumber(value: Double.pi),
                    inputWidth: NSNumber(value: 80),
                    inputBarOffset: NSNumber(value: 10),
                    inputTime: NSNumber(value: Double(t))
                ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out

            case .copyMachine:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                let ciExtent = CIVector(x: 0, y: 0, z: fg.extent.width, w: fg.extent.height)
                let stripeWidth = max(renderSize.width, renderSize.height)
                guard let filter = CIFilter.copyMachineTransitionFilter(
                    inputImage: bg,
                    inputTargetImage: fg,
                    inputExtent: ciExtent,
                    inputColor: .white,
                    inputTime: NSNumber(value: Double(t)),
                    inputAngle: NSNumber(value: Double.pi),
                    inputWidth: NSNumber(value: Double(stripeWidth)),
                    inputOpacity: NSNumber(value: 1.0)
                ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out

            case .flash:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                let ciCenter = CIVector(x: fg.extent.width / 2, y: fg.extent.height / 2)
                let ciExtent = CIVector(x: 0, y: 0, z: fg.extent.width, w: fg.extent.height)
                guard let filter = CIFilter.flashTransitionFilter(
                    inputImage: bg,
                    inputTargetImage: fg,
                    inputCenter: ciCenter,
                    inputExtent: ciExtent,
                    inputColor: .white,
                    inputTime: NSNumber(value: Double(t))
                ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out

            case .mod:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                let ciCenter = CIVector(x: fg.extent.width / 2, y: fg.extent.height / 2)
                let radius = min(renderSize.width / 2, renderSize.height / 2)
                guard let filter = CIFilter.modTransitionFilter(
                    inputImage: bg,
                    inputTargetImage: fg,
                    inputCenter: ciCenter,
                    inputTime: NSNumber(value: Double(t)),
                    inputAngle: NSNumber(value: Double.pi),
                    inputRadius: NSNumber(value: Double(radius)),
                    inputCompression: NSNumber(value: 300)
                ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out

            case .pageCurl:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                // Visible “back” of the curling sheet — slightly muted outgoing frame.
                let backside = bg
                    .applyingFilter("CIColorControls", parameters: [
                        kCIInputSaturationKey: 0.7,
                        kCIInputBrightnessKey: -0.1
                    ])
                    .cropped(to: rect)
                let minDim = min(renderSize.width, renderSize.height)
                let radius = Float(minDim * (100.0 / 300.0))
                let shadowScale: CGFloat = 400.0 / 300.0
                let shadowW = renderSize.width * shadowScale
                let shadowH = renderSize.height * shadowScale
                let shadowRect = CGRect(
                    x: (renderSize.width - shadowW) / 2,
                    y: (renderSize.height - shadowH) / 2,
                    width: shadowW,
                    height: shadowH
                )
                guard let filter = CIFilter.pageCurlWithShadowTransitionFilter(
                    inputImage: bg,
                    targetImage: fg,
                    backsideImage: backside,
                    extent: rect,
                    time: Float(t),
                    radius: radius,
                    shadowExtent: shadowRect
                ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out

            case .accordionFold:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                guard let filter = CIFilter.accordionFoldTransitionFilter(
                    inputImage: bg,
                    targetImage: fg,
                    time: Float(t)
                ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out
            case .disintegrate:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                guard let url = Bundle.main.url(forResource: "disintegrate", withExtension: "jpg"),
                      let mask = CIImage(contentsOf: url),
                      let maskFill = mask.resizeAndCenterCrop(to: rect),
                      let filter = CIFilter.disintergrateTransitionFilter(
                        inputImage: bg,
                        targetImage: fg,
                        maskImage: maskFill,
                        time: Float(t)
                      ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out
            case .disintegrateHeart:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                guard let url = Bundle.main.url(forResource: "heart-mask", withExtension: "jpg"),
                      let mask = CIImage(contentsOf: url),
                      let maskFill = mask.resizeAndCenterCrop(to: rect),
                      let filter = CIFilter.disintergrateTransitionFilter(
                        inputImage: bg,
                        targetImage: fg,
                        maskImage: maskFill,
                        time: Float(t)
                      ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out
            case .disintegrateTiles:
                let bg = backgroundImage.cropped(to: rect)
                let fg = foregroundImage.cropped(to: rect)
                guard let url = Bundle.main.url(forResource: "tiles-mask", withExtension: "jpg"),
                      let mask = CIImage(contentsOf: url),
                      let maskFill = mask.resizeAndCenterCrop(to: rect),
                      let filter = CIFilter.disintergrateTransitionFilter(
                        inputImage: bg,
                        targetImage: fg,
                        maskImage: maskFill,
                        time: Float(t)
                      ),
                      let out = filter.outputImage?.cropped(to: rect)
                else {
                    return fg.applyingPreviewVideoAlpha(t).composited(over: bg).cropped(to: rect)
                }
                return out
        }
    }
}
