//
// FilterEffect
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Color / image filter configuration.
//  The engine picks the matching CIFilter from `filterType` and maps `intensity` to the right input key.

import Foundation

nonisolated struct FilterEffect: Codable, Equatable {

    var filterType: FilterType

    /// Effect strength. 0.0 = no effect (pass-through), 1.0 = full strength.
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
