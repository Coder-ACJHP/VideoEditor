//
// EditorCanvasOverlayBindings
// VideoEditor
//
//  Presentation DTOs: what `EditorRenderView` needs to bind pooled overlay views.

import Foundation

struct TextCanvasBinding: Sendable {
    let clipId: UUID
    var descriptor: TextOverlayDescriptor
    var transform: TransformEffect
    var allowsTransformGestures: Bool
    var showsSelectionChrome: Bool
}

struct StickerCanvasBinding: Sendable {
    let clipId: UUID
    var imageURL: URL
    var transform: TransformEffect
    var allowsTransformGestures: Bool
    var showsSelectionChrome: Bool
}
