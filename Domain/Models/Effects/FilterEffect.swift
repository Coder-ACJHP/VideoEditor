//
//  FilterEffect.swift
//  VideoEditor
//
//  Renk ve görüntü filtresi konfigürasyonu.
//  Engine, filterType'a göre uygun CIFilter'i seçer ve intensity'yi
//  ilgili inputKey'e haritalar.

import Foundation

struct FilterEffect: Codable, Equatable {

    var filterType: FilterType

    /// Efektin yoğunluğu. 0.0 = efekt yok (pass-through), 1.0 = tam yoğunluk.
    var intensity: Float

    enum FilterType: String, Codable, CaseIterable {
        case grayscale
        case sepia
        case vibrance
        case sharpen
        case vignette
    }

    static func `default`(type: FilterType) -> FilterEffect {
        FilterEffect(filterType: type, intensity: 1.0)
    }
}
