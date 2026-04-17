//
// CoreImage+VideoPreview
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  CIImage helpers for the preview video compositor.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

extension CIImage {
    
    /// Alpha multiplier via CIColorMatrix for opacity in 0...1.
    func applyingPreviewVideoAlpha(_ alpha: CGFloat) -> CIImage {
        return self.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)
        ])
    }
    
    /// Applies `preferredTransform` in video-buffer coordinates; double vertical flip aligns Core Image with UIKit’s Y axis.
    func applyingPreviewPreferredTransform(_ transform: CGAffineTransform) -> CIImage {
        flippedVerticallyForVideoBuffer()
            .transformed(by: transform)
            .flippedVerticallyForVideoBuffer()
    }
    
    private func flippedVerticallyForVideoBuffer() -> CIImage {
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: extent.origin.y * 2 + extent.height)
        return transformed(by: flip)
    }
    
    
    /// Scales (aspect-fill) and centers the image so it fully covers `rect`, then crops to `rect`.
    func scaledToFill(rect: CGRect) -> CIImage? {
        let src = extent
        guard src.width > 0, src.height > 0, rect.width > 0, rect.height > 0 else { return nil }
        
        let scale = max(rect.width / src.width, rect.height / src.height)
        let scaledW = src.width * scale
        let scaledH = src.height * scale
        let tx = rect.midX - (src.midX * scale) - (scaledW - rect.width) / 2
        let ty = rect.midY - (src.midY * scale) - (scaledH - rect.height) / 2
        
        return transformed(by: CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: tx, y: ty)))
            .cropped(to: rect)
    }
    
    /// Resizes and center-crops the image to exactly fit the target CGRect using Lanczos interpolation.
    func resizeAndCenterCrop(to rect: CGRect) -> CIImage? {
        let originalSize = self.extent.size
        
        // Ensure valid dimensions to avoid division by zero or rendering crashes
        guard originalSize.width > 0, originalSize.height > 0,
              rect.width > 0, rect.height > 0 else {
            return nil
        }
        
        // 1. Calculate Aspect Fill Scale
        let scaleX = rect.width / originalSize.width
        let scaleY = rect.height / originalSize.height
        let scale = max(scaleX, scaleY)
        
        // 2. Apply High-Quality Lanczos Scale Transform
        // Using modern strongly-typed API instead of KVC strings
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = self
        filter.scale = Float(scale)
        filter.aspectRatio = 1.0
        
        guard let scaledImage = filter.outputImage else { return nil }
        
        // 3. Calculate Center Crop Rect
        let scaledExtent = scaledImage.extent
        let cropX = scaledExtent.origin.x + (scaledExtent.width - rect.width) / 2.0
        let cropY = scaledExtent.origin.y + (scaledExtent.height - rect.height) / 2.0
        
        let cropRect = CGRect(x: cropX, y: cropY, width: rect.width, height: rect.height)
        
        // 4. Crop and align coordinates to the target rect's origin
        let finalImage = scaledImage
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: rect.origin.x - cropX,
                                               y: rect.origin.y - cropY))
        
        return finalImage
    }
}
