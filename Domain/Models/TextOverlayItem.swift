//
// TextOverlayItem
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Domain view of a text clip for the editor: content (`TextOverlayDescriptor`) plus placement
//  and timeline span. Preview draws text in UIKit; export will read the same model later.

import CoreMedia
import Foundation

nonisolated struct TextOverlayItem: Identifiable, Equatable, Sendable {

    let id: UUID
    var descriptor: TextOverlayDescriptor
    var transform: TransformEffect
    var timelineRange: ClipTimeRange
    var opacity: Float

    init(clip: MediaClip, descriptor: TextOverlayDescriptor) {
        id = clip.id
        self.descriptor = descriptor
        transform = clip.transform
        timelineRange = clip.timelineRange
        opacity = clip.opacity
    }

    /// Half-open in composition seconds: [start, end).
    func isActive(at time: CMTime) -> Bool {
        guard time.isValid, !time.isIndefinite else { return false }
        let s = time.seconds
        guard s.isFinite else { return false }
        return s >= timelineRange.startSeconds && s < timelineRange.endSeconds
    }
}
