//
// EffectConfiguration
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  All effect kinds that can be attached to a clip.
//  Geometry lives on `MediaClip.transform`; this enum holds filter / speed / etc. only.
//
//  Codable: Swift cannot synthesize Codable for enums with associated values here;
//  a manual discriminator (type tag) implementation follows below.

import Foundation

nonisolated enum EffectConfiguration: Equatable, Sendable {
    case filter(FilterEffect)
    case speed(SpeedEffect)
}

// MARK: - Codable

extension EffectConfiguration: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum EffectType: String, Codable {
        case filter
        case speed
        /// Legacy projects; ignored after decode (geometry now lives on `MediaClip.transform`).
        case transform
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .filter(let effect):
            try container.encode(EffectType.filter, forKey: .type)
            try container.encode(effect, forKey: .payload)
        case .speed(let effect):
            try container.encode(EffectType.speed, forKey: .type)
            try container.encode(effect, forKey: .payload)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let effectType = try container.decode(EffectType.self, forKey: .type)
        switch effectType {
        case .filter:
            self = .filter(try container.decode(FilterEffect.self, forKey: .payload))
        case .speed:
            self = .speed(try container.decode(SpeedEffect.self, forKey: .payload))
        case .transform:
            // Legacy payload; geometry is on `MediaClip.transform` now — discard here.
            _ = try container.decode(TransformEffect.self, forKey: .payload)
            self = .filter(FilterEffect(filterType: .grayscale, intensity: 0))
        }
    }
}
