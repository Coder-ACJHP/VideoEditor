//
// TransformEffect+Extension
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.


import Foundation
import CoreGraphics

extension TransformEffect {
    /// Builds an absolute affine transform for the given output size (e.g. 1080×1920).
    /// - Parameters:
    ///   - renderSize: Full video composition size in pixels.
    ///   - assetSize: Native pixel size of the clip’s video or image.
    func absoluteTransform(relativeTo renderSize: CGSize, assetSize: CGSize) -> CGAffineTransform {
        // 1. Target center in pixels
        let targetCenterX = normalizedCenter.x * renderSize.width
        let targetCenterY = normalizedCenter.y * renderSize.height
        
        // 2. Base scale to fit the asset inside the render rect (aspect fit)
        let widthRatio = renderSize.width / assetSize.width
        let heightRatio = renderSize.height / assetSize.height
        let baseScale = min(widthRatio, heightRatio)
        
        let finalScale = baseScale * normalizedScale
        
        // 3. Compose transforms
        var transform = CGAffineTransform.identity
        
        // Move to the desired center
        transform = transform.translatedBy(x: targetCenterX, y: targetCenterY)
        
        // Rotate
        transform = transform.rotated(by: rotationAngle)
        
        // Scale
        transform = transform.scaledBy(x: finalScale, y: finalScale)
        
        // AVFoundation draws from the asset’s top-left; offset by half the asset size to pivot around the center.
        transform = transform.translatedBy(x: -assetSize.width / 2, y: -assetSize.height / 2)
        
        return transform
    }
}
