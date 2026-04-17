//
// TransformEffect
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Normalized 0…1 placement of a clip on the canvas / composition.
//  Text typography stays in `TextOverlayDescriptor`; geometry is owned here.

import CoreGraphics
import Foundation

nonisolated struct TransformEffect: Codable, Equatable, Hashable, Sendable {

    /// Normalized center (0,0 top-left — 1,1 bottom-right).
    var normalizedCenter: CGPoint

    /// Normalized width and height as fractions of the canvas size.
    var normalizedSize: CGSize
    
    /// Extra scale multiplier (1.0 = default).
    var normalizedScale: CGFloat

    /// Counter-clockwise rotation in radians (matches Core Animation).
    var rotationAngle: CGFloat

    static let identity = TransformEffect(
        normalizedCenter: CGPoint(x: 0.5, y: 0.5),
        normalizedSize: CGSize(width: 0.72, height: 0.12),
        normalizedScale: 1.0,
        rotationAngle: 0
    )

    /// Default placement for raster stickers on the overlay track (square box; user can resize on canvas).
    static let overlayStickerDefault = TransformEffect(
        normalizedCenter: CGPoint(x: 0.5, y: 0.5),
        normalizedSize: CGSize(width: 0.32, height: 0.32),
        normalizedScale: 1.0,
        rotationAngle: 0
    )

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case centerX
        case centerY
        case width
        case height
        case normalizedScale
        case rotationAngle
    }

    init(normalizedCenter: CGPoint, normalizedSize: CGSize, normalizedScale: CGFloat, rotationAngle: CGFloat) {
        self.normalizedCenter = normalizedCenter
        self.normalizedSize = normalizedSize
        self.normalizedScale = normalizedScale
        self.rotationAngle = rotationAngle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let cx = try c.decode(Double.self, forKey: .centerX)
        let cy = try c.decode(Double.self, forKey: .centerY)
        let w = try c.decode(Double.self, forKey: .width)
        let h = try c.decode(Double.self, forKey: .height)
        normalizedCenter = CGPoint(x: cx, y: cy)
        normalizedSize = CGSize(width: w, height: h)
        normalizedScale = CGFloat(try c.decode(Double.self, forKey: .normalizedScale))
        rotationAngle = CGFloat(try c.decode(Double.self, forKey: .rotationAngle))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Double(normalizedCenter.x), forKey: .centerX)
        try c.encode(Double(normalizedCenter.y), forKey: .centerY)
        try c.encode(Double(normalizedSize.width), forKey: .width)
        try c.encode(Double(normalizedSize.height), forKey: .height)
        try c.encode(Double(normalizedScale), forKey: .normalizedScale)
        try c.encode(Double(rotationAngle), forKey: .rotationAngle)
    }
}
