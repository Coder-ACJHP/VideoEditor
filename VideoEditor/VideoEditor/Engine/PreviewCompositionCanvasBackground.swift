//
// PreviewCompositionCanvasBackground
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Maps `CanvasBackgroundSettings` to Core Image fills for the preview compositor.
//

import CoreImage
import CoreGraphics
import Foundation

enum PreviewCompositionCanvasBackground {

    /// Full-frame background image for the current render size (solid or vertical gradient).
    nonisolated static func ciImage(renderSize: CGSize, settings: CanvasBackgroundSettings) -> CIImage {
        let rect = CGRect(origin: .zero, size: renderSize)
        switch settings.style {
        case .solid:
            let color = ciColor(canvasBackgroundColorHex: settings.primaryHex)
            return CIImage(color: color).cropped(to: rect)
        case .linearGradient:
            let top = ciColor(canvasBackgroundColorHex: settings.primaryHex)
            let bottom = ciColor(canvasBackgroundColorHex: settings.secondaryHex ?? "#FFFFFF")
            return linearGradient(in: rect, top: top, bottom: bottom)
        }
    }

    private nonisolated static func linearGradient(in rect: CGRect, top: CIColor, bottom: CIColor) -> CIImage {
        guard let filter = CIFilter(name: "CILinearGradient") else {
            return CIImage(color: top).cropped(to: rect)
        }
        filter.setValue(CIVector(x: rect.midX, y: rect.maxY), forKey: "inputPoint0")
        filter.setValue(CIVector(x: rect.midX, y: rect.minY), forKey: "inputPoint1")
        filter.setValue(top, forKey: "inputColor0")
        filter.setValue(bottom, forKey: "inputColor1")
        guard let image = filter.outputImage?.cropped(to: rect) else {
            return CIImage(color: top).cropped(to: rect)
        }
        return image
    }

    /// `nil` or empty → opaque black (matches previous default).
    nonisolated static func ciColor(canvasBackgroundColorHex: String?) -> CIColor {
        guard let raw = canvasBackgroundColorHex?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        }
        let hex = raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else {
            return CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        }
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat
        switch hex.count {
        case 3:
            a = 1
            r = CGFloat((int >> 8) * 17) / 255
            g = CGFloat((int >> 4 & 0xF) * 17) / 255
            b = CGFloat((int & 0xF) * 17) / 255
        case 6:
            a = 1
            r = CGFloat(int >> 16) / 255
            g = CGFloat(int >> 8 & 0xFF) / 255
            b = CGFloat(int & 0xFF) / 255
        case 8:
            a = CGFloat(int >> 24) / 255
            r = CGFloat(int >> 16 & 0xFF) / 255
            g = CGFloat(int >> 8 & 0xFF) / 255
            b = CGFloat(int & 0xFF) / 255
        default:
            return CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        }
        return CIColor(red: r, green: g, blue: b, alpha: a)
    }
}
