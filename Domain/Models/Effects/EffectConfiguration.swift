//
//  EffectConfiguration.swift
//  VideoEditor
//
//  Bir clip'e uygulanabilecek tüm efekt tiplerini kapsıyor.
//  Geometri `MediaClip.transform` içindedir; burada yalnızca filtre / hız vb. kalır.
//
//  Codable notu: Swift'te associated value taşıyan enum'lar için
//  sentezlenmiş Codable çalışmaz; aşağıda discriminator (type tag) pattern
//  ile manuel olarak implement edildi.

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
        /// Eski projeler; decode sonrası yok sayılır (geometri artık `MediaClip.transform`).
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
            // Eski sürümler; geometri artık `MediaClip.transform` üzerinde, burada yok sayılır.
            _ = try container.decode(TransformEffect.self, forKey: .payload)
            self = .filter(FilterEffect(filterType: .grayscale, intensity: 0))
        }
    }
}
