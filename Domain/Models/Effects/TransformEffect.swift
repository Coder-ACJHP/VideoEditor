//
//  TransformEffect.swift
//  VideoEditor
//
//  Klibin canvas / composition üzerindeki yerleşimi (normalize 0…1 alan).
//  Metin tipografisi `TextOverlayDescriptor` içinde kalır; geometri burada tek kaynak.

import CoreGraphics
import Foundation

nonisolated struct TransformEffect: Codable, Equatable, Hashable, Sendable {

    /// Normalize merkez (0,0 sol üst — 1,1 sağ alt).
    var normalizedCenter: CGPoint

    /// Normalize genişlik ve yükseklik (canvas genişliği ve yüksekliğine göre oran).
    var normalizedSize: CGSize

    /// Saat yönünün tersine radyan (Core Animation ile uyumlu).
    var rotationAngle: CGFloat

    static let identity = TransformEffect(
        normalizedCenter: CGPoint(x: 0.5, y: 0.5),
        normalizedSize: CGSize(width: 0.72, height: 0.12),
        rotationAngle: 0
    )

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case centerX
        case centerY
        case width
        case height
        case rotationAngle
    }

    init(normalizedCenter: CGPoint, normalizedSize: CGSize, rotationAngle: CGFloat) {
        self.normalizedCenter = normalizedCenter
        self.normalizedSize = normalizedSize
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
        rotationAngle = CGFloat(try c.decode(Double.self, forKey: .rotationAngle))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Double(normalizedCenter.x), forKey: .centerX)
        try c.encode(Double(normalizedCenter.y), forKey: .centerY)
        try c.encode(Double(normalizedSize.width), forKey: .width)
        try c.encode(Double(normalizedSize.height), forKey: .height)
        try c.encode(Double(rotationAngle), forKey: .rotationAngle)
    }
}
