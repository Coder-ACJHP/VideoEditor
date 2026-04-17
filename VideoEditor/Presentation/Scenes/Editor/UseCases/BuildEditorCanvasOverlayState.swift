//
// BuildEditorCanvasOverlayState
// VideoEditor
//
//  Thin use case: playhead + selection + draft → canvas row bindings and paint order.

import CoreMedia
import Foundation

nonisolated struct EditorCanvasTextDraft: Sendable {
    let clipId: UUID
    let descriptor: TextOverlayDescriptor
    let transform: TransformEffect
}

nonisolated struct EditorCanvasOverlayRefreshInput: Sendable {
    var clips: [OverlayCanvasClip]
    var playhead: CMTime
    var timelineSelectedClipId: UUID?
    var canvasActiveClipId: UUID?
    var sheetFocusedClipIds: Set<UUID>
    var textDraft: EditorCanvasTextDraft?
}

nonisolated struct CanvasOverlayBindResult: Sendable {
    var textRows: [TextCanvasBinding]
    var stickerRows: [StickerCanvasBinding]
    var paintOrderClipIds: [UUID]
}

enum BuildEditorCanvasOverlayState {

    nonisolated static func make(input: EditorCanvasOverlayRefreshInput) -> CanvasOverlayBindResult {
        let visibleAtPlayhead = Set(input.clips.filter { $0.containsPlayhead(input.playhead) }.map(\.id))
        let highlightId = input.canvasActiveClipId

        var paintOrder: [UUID] = []
        var textRows: [TextCanvasBinding] = []
        var stickerRows: [StickerCanvasBinding] = []

        for clip in input.clips {
            let forcedBySheet = input.sheetFocusedClipIds.contains(clip.id)
            let forcedByTimeline = input.timelineSelectedClipId == clip.id
            guard visibleAtPlayhead.contains(clip.id) || forcedBySheet || forcedByTimeline else { continue }

            paintOrder.append(clip.id)
            let isActive = clip.id == highlightId

            switch clip.kind {
            case .text(let descriptor):
                textRows.append(
                    TextCanvasBinding(
                        clipId: clip.id,
                        descriptor: descriptor,
                        transform: clip.transform,
                        allowsTransformGestures: isActive,
                        showsSelectionChrome: isActive
                    )
                )
            case .sticker(let url):
                stickerRows.append(
                    StickerCanvasBinding(
                        clipId: clip.id,
                        imageURL: url,
                        transform: clip.transform,
                        allowsTransformGestures: isActive,
                        showsSelectionChrome: isActive
                    )
                )
            }
        }

        if let draft = input.textDraft {
            let isActive = draft.clipId == highlightId
            paintOrder.append(draft.clipId)
            textRows.append(
                TextCanvasBinding(
                    clipId: draft.clipId,
                    descriptor: draft.descriptor,
                    transform: draft.transform,
                    allowsTransformGestures: isActive,
                    showsSelectionChrome: isActive
                )
            )
        }

        return CanvasOverlayBindResult(
            textRows: textRows,
            stickerRows: stickerRows,
            paintOrderClipIds: paintOrder
        )
    }
}
