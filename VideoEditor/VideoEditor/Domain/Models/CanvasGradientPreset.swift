//
// CanvasGradientPreset
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Catalog of named two-color gradients for canvas background. Kept in Domain so the
//  sheet and any future export UI share one source of truth.
//

import Foundation

nonisolated struct CanvasGradientPreset: Equatable, Hashable, Sendable {

    /// Stable id for analytics or persistence if needed later.
    let id: String
    /// String table key for `String(localized:)`.
    let titleKey: String
    let startHex: String
    let endHex: String

    /// Built-in presets (vertical top → bottom in the compositor).
    static let catalog: [CanvasGradientPreset] = [
        CanvasGradientPreset(id: "ocean", titleKey: "Ocean", startHex: "#0077B6", endHex: "#90E0EF"),
        CanvasGradientPreset(id: "sunset", titleKey: "Sunset", startHex: "#FF6B6B", endHex: "#FFD93D"),
        CanvasGradientPreset(id: "forest", titleKey: "Forest", startHex: "#2D5016", endHex: "#7CB342"),
        CanvasGradientPreset(id: "purple_haze", titleKey: "Purple haze", startHex: "#667EEA", endHex: "#764BA2"),
        CanvasGradientPreset(id: "midnight", titleKey: "Midnight", startHex: "#0F2027", endHex: "#2C5364"),
        CanvasGradientPreset(id: "coral", titleKey: "Coral", startHex: "#FFAFBD", endHex: "#FFC3A0"),
        CanvasGradientPreset(id: "slate", titleKey: "Slate", startHex: "#606C88", endHex: "#3F4C6B"),
    ]
}

extension CanvasGradientPreset {

    var localizedTitle: String {
        String(localized: LocalizedStringResource(stringLiteral: titleKey))
    }
}
