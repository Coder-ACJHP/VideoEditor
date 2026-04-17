//
// ClipTransition+EditorPresentation
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Editor-only display strings and preview visuals for transition pickers.
//  Optional catalog images: `TransitionPreview_<rawValue>` in Assets (e.g. `TransitionPreview_crossDissolve`).
//

import UIKit

extension ClipTransition.TransitionType {

    var editorDisplayName: String {
        switch self {
        case .crossDissolve: String(localized: "Cross dissolve")
        case .fadeToBlack: String(localized: "Fade to black")
        case .push: String(localized: "Push")
        case .swipe: String(localized: "Swipe")
        case .slide: String(localized: "Slide")
        case .ripple: String(localized: "Ripple")
        case .barsSwipe: String(localized: "Bars swipe")
        case .copyMachine: String(localized: "Copy machine")
        case .flash: String(localized: "Flash")
        case .mod: String(localized: "Mod")
        case .pageCurl: String(localized: "Page curl")
        case .accordionFold: String(localized: "Accordion fold")
        case .disintegrate: String(localized: "Disintegrate")
        case .disintegrateHeart: String(localized: "Turn to heart")
        case .disintegrateTiles: String(localized: "Pixelate")
        }
    }

    /// SF Symbol fallback when no asset is named `TransitionPreview_<rawValue>`.
    var editorPreviewSymbolName: String {
        switch self {
        case .crossDissolve: "circle.lefthalf.filled"
        case .fadeToBlack: "moonphase.last.quarter"
        case .push: "arrow.right.square"
        case .swipe: "hand.draw"
        case .slide: "rectangle.stack"
        case .ripple: "dot.radiowaves.left.and.right"
        case .barsSwipe: "cellularbars"
        case .copyMachine: "doc.on.doc"
        case .flash: "bolt.fill"
        case .mod: "waveform.path"
        case .pageCurl: "book.pages"
        case .accordionFold: "rectangle.compress.vertical"
        case .disintegrate: "sparkles"
        case .disintegrateHeart: "heart.fill"
        case .disintegrateTiles: "app.background.dotted"
        }
    }

    var editorPreviewAssetImage: UIImage? {
        UIImage(named: "TransitionPreview_\(rawValue)")
    }
}
