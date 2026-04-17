//
// CanvasBackgroundSettings
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Composition canvas fill: flat color or vertical linear gradient for preview / export.
//

import Foundation

nonisolated struct CanvasBackgroundSettings: Codable, Equatable, Hashable, Sendable {

    enum Style: String, Codable, Sendable {
        case solid
        case linearGradient
    }

    /// Flat fill, or gradient top color (start).
    var style: Style
    /// `#RRGGBB`; `nil` treats as black for solid / gradient start.
    var primaryHex: String?
    /// Gradient bottom color; ignored when `style == .solid`. `nil` uses white.
    var secondaryHex: String?

    static let `default` = CanvasBackgroundSettings(style: .solid, primaryHex: nil, secondaryHex: nil)
}
