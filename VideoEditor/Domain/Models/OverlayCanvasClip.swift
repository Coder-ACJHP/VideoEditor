//
// OverlayCanvasClip
// VideoEditor
//
//  Domain DTO: one overlay-lane clip shown on the editor preview canvas (UIKit), not AVComposition layout.

import CoreMedia
import Foundation

nonisolated enum OverlayCanvasClipKind: Equatable, Sendable {
    case text(TextOverlayDescriptor)
    case sticker(URL)
}

nonisolated struct OverlayCanvasClip: Equatable, Sendable {
    let id: UUID
    var timelineRange: ClipTimeRange
    var transform: TransformEffect
    var opacity: Float
    var kind: OverlayCanvasClipKind

    func containsPlayhead(_ time: CMTime) -> Bool {
        guard time.isValid, !time.isIndefinite else { return false }
        let s = time.seconds
        guard s.isFinite else { return false }
        return s >= timelineRange.startSeconds && s < timelineRange.endSeconds
    }
}
