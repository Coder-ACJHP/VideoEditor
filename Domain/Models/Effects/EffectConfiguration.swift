//
//  EffectConfiguration.swift
//  VideoEditor
//
//  Bir clip'e uygulanabilecek tüm efekt tiplerini kapsıyor.
//  Efektler VideoClip.effects dizisinde sıralanmış tutulur;
//  sıra, render sonucunu etkiler (örn. transform'dan önce filter uygulamak
//  ile sonra uygulamak farklı çıktı verir).
//
//  Codable notu: Swift'te associated value taşıyan enum'lar için
//  sentezlenmiş Codable çalışmaz; aşağıda discriminator (type tag) pattern
//  ile manuel olarak implement edildi.

import Foundation

enum EffectConfiguration: Equatable {
    case filter(FilterEffect)
    case transform(TransformEffect)
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
        case transform
        case speed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .filter(let effect):
            try container.encode(EffectType.filter, forKey: .type)
            try container.encode(effect, forKey: .payload)
        case .transform(let effect):
            try container.encode(EffectType.transform, forKey: .type)
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
        case .transform:
            self = .transform(try container.decode(TransformEffect.self, forKey: .payload))
        case .speed:
            self = .speed(try container.decode(SpeedEffect.self, forKey: .payload))
        }
    }
}
