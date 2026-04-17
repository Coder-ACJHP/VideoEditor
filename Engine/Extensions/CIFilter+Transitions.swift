//
// CIFilter+Transitions
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.


import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

extension CIFilter {

    // MARK: - Disintegrate transition (`CIDisintegrateWithMaskTransition`)
    
    static func disintergrateTransitionFilter(
        inputImage: CIImage,
        targetImage: CIImage,
        maskImage: CIImage,
        time: Float
    ) -> CIFilter? {
        let disintergrateTransition = CIFilter.disintegrateWithMaskTransition()
        disintergrateTransition.setDefaults()
        disintergrateTransition.inputImage = inputImage
        disintergrateTransition.targetImage = targetImage
        disintergrateTransition.maskImage = maskImage
        disintergrateTransition.time = time
        disintergrateTransition.shadowRadius = 5.0
        disintergrateTransition.shadowDensity = 1.0
        disintergrateTransition.shadowOffset = CGPoint(x: 0.5, y: 0.5)
        return disintergrateTransition
    }
    
    // MARK: - Accordion fold (`CIAccordionFoldTransition`)

    static func accordionFoldTransitionFilter(
        inputImage: CIImage,
        targetImage: CIImage,
        time: Float
    ) -> CIFilter? {
        
        let accordionFoldTransition = CIFilter.accordionFoldTransition()
        accordionFoldTransition.setDefaults()
        accordionFoldTransition.inputImage = inputImage
        accordionFoldTransition.targetImage = targetImage
        accordionFoldTransition.time = time
        accordionFoldTransition.bottomHeight = .zero
        accordionFoldTransition.numberOfFolds = 6.0
        accordionFoldTransition.foldShadowAmount = 1.0
        return accordionFoldTransition
    }

    // MARK: - Page curl with shadow (`CIPageCurlWithShadowTransition`)

    static func pageCurlWithShadowTransitionFilter(
        inputImage: CIImage,
        targetImage: CIImage,
        backsideImage: CIImage,
        extent: CGRect,
        time: Float,
        radius: Float,
        shadowExtent: CGRect
    ) -> CIFilter? {
        let pageCurlTransition = CIFilter.pageCurlWithShadowTransition()
        pageCurlTransition.setDefaults()
        pageCurlTransition.inputImage = inputImage
        pageCurlTransition.targetImage = targetImage
        pageCurlTransition.backsideImage = backsideImage
        pageCurlTransition.extent = extent
        pageCurlTransition.time = time
        pageCurlTransition.angle = 4.0
        pageCurlTransition.radius = radius
        pageCurlTransition.shadowAmount = 10.0
        pageCurlTransition.shadowSize = 6.0
        pageCurlTransition.shadowExtent = shadowExtent
        return pageCurlTransition
    }

    // MARK: - Mod (`CIModTransition`)

    static func modTransitionFilter(
        inputImage: CIImage,
        inputTargetImage: CIImage,
        inputCenter: CIVector = CIVector(x: 150, y: 150),
        inputTime: NSNumber = 0,
        inputAngle: NSNumber = 2,
        inputRadius: NSNumber = 150,
        inputCompression: NSNumber = 300
    ) -> CIFilter? {
        let filter = CIFilter.modTransition()
        filter.setDefaults()
        filter.inputImage = inputImage
        filter.targetImage = inputTargetImage
        filter.center = CGPoint(x: inputCenter.x, y: inputCenter.y)
        filter.time = inputTime.floatValue
        filter.angle = inputAngle.floatValue
        filter.radius = inputRadius.floatValue
        filter.compression = inputCompression.floatValue
        return filter
    }

    // MARK: - Flash (`CIFlashTransition`)

    static func flashTransitionFilter(
        inputImage: CIImage,
        inputTargetImage: CIImage,
        inputCenter: CIVector = CIVector(x: 150, y: 150),
        inputExtent: CIVector = CIVector(x: 0, y: 0, z: 300, w: 300),
        inputColor: CIColor,
        inputTime: NSNumber = 0,
        inputMaxStriationRadius: NSNumber = 2.58,
        inputStriationStrength: NSNumber = 0.5,
        inputStriationContrast: NSNumber = 1.375,
        inputFadeThreshold: NSNumber = 0.85
    ) -> CIFilter? {
        let filter = CIFilter.flashTransition()
        filter.setDefaults()
        filter.inputImage = inputImage
        filter.targetImage = inputTargetImage
        filter.center = CGPoint(x: inputCenter.x, y: inputCenter.y)
        filter.extent = CGRect(
            x: inputExtent.x,
            y: inputExtent.y,
            width: inputExtent.z,
            height: inputExtent.w
        )
        filter.color = inputColor
        filter.time = inputTime.floatValue
        filter.maxStriationRadius = inputMaxStriationRadius.floatValue
        filter.striationStrength = inputStriationStrength.floatValue
        filter.striationContrast = inputStriationContrast.floatValue
        filter.fadeThreshold = inputFadeThreshold.floatValue
        return filter
    }

    // MARK: - Copy machine (`CICopyMachineTransition`)

    static func copyMachineTransitionFilter(
        inputImage: CIImage,
        inputTargetImage: CIImage,
        inputExtent: CIVector = CIVector(x: 0, y: 0, z: 300, w: 300),
        inputColor: CIColor,
        inputTime: NSNumber = 0,
        inputAngle: NSNumber = 0,
        inputWidth: NSNumber = 200,
        inputOpacity: NSNumber = 1.3
    ) -> CIFilter? {
        let filter = CIFilter.copyMachineTransition()
        filter.setDefaults()
        filter.inputImage = inputImage
        filter.targetImage = inputTargetImage
        filter.extent = CGRect(
            x: inputExtent.x,
            y: inputExtent.y,
            width: inputExtent.z,
            height: inputExtent.w
        )
        filter.color = inputColor
        filter.time = inputTime.floatValue
        filter.angle = inputAngle.floatValue
        filter.width = inputWidth.floatValue
        filter.opacity = inputOpacity.floatValue
        return filter
    }

    // MARK: - Bars swipe (`CIBarsSwipeTransition`)

    static func barsSwipeTransitionFilter(
        inputImage: CIImage,
        inputTargetImage: CIImage,
        inputAngle: NSNumber = NSNumber(value: Double.pi),
        inputWidth: NSNumber = NSNumber(value: 30),
        inputBarOffset: NSNumber = NSNumber(value: 10),
        inputTime: NSNumber = 0
    ) -> CIFilter? {
        let filter = CIFilter.barsSwipeTransition()
        filter.setDefaults()
        filter.inputImage = inputImage
        filter.targetImage = inputTargetImage
        filter.time = inputTime.floatValue
        filter.angle = inputAngle.floatValue
        filter.width = inputWidth.floatValue
        filter.barOffset = inputBarOffset.floatValue
        return filter
    }

    // MARK: - Ripple (`CIRippleTransition`) — same setup as reference project

    static func rippleTransitionFilter(
        inputImage: CIImage,
        inputTargetImage: CIImage,
        inputShadingImage: CIImage,
        inputCenter: CIVector,
        inputExtent: CIVector,
        inputTime: NSNumber = 0,
        inputWidth: NSNumber = 100,
        inputScale: NSNumber = 50
    ) -> CIFilter? {
        let filter = CIFilter.rippleTransition()
        filter.setDefaults()
        filter.inputImage = inputImage
        filter.targetImage = inputTargetImage
        filter.shadingImage = inputShadingImage
        filter.center = CGPoint(x: inputCenter.x, y: inputCenter.y)
        filter.extent = CGRect(
            x: inputExtent.x,
            y: inputExtent.y,
            width: inputExtent.z,
            height: inputExtent.w
        )
        filter.width = inputWidth.floatValue
        filter.scale = inputScale.floatValue
        filter.time = inputTime.floatValue
        return filter
    }

    // MARK: - Swipe (`CISwipeTransition`) — same setup as reference project

    static func swipeTransitionFilter(
        inputImage: CIImage,
        inputTargetImage: CIImage,
        inputExtent: CIVector = CIVector(x: 0.0, y: 0.0, z: 300.0, w: 300.0),
        inputColor: CIColor,
        inputTime: NSNumber = 0,
        inputAngle: NSNumber = 0,
        inputWidth: NSNumber = 300,
        inputOpacity: NSNumber = 0
    ) -> CIFilter? {
        let filter = CIFilter.swipeTransition()
        filter.setDefaults()
        filter.inputImage = inputImage
        filter.targetImage = inputTargetImage
        filter.extent = CGRect(
            x: inputExtent.x,
            y: inputExtent.y,
            width: inputExtent.z,
            height: inputExtent.w
        )
        filter.color = inputColor
        filter.time = inputTime.floatValue
        filter.angle = inputAngle.floatValue
        filter.width = inputWidth.floatValue
        filter.opacity = inputOpacity.floatValue
        return filter
    }
}
