//
// MasterTrackTimelineArranger
// VideoEditor
//

import Foundation

/// Default `TimelineArranging` implementation (pure geometry on `MediaClip` timelines).
struct MasterTrackTimelineArranger: TimelineArranging {

    func enforceMasterTrackContiguity(clips: [MediaClip]) -> [MediaClip] {
        guard !clips.isEmpty else { return clips }

        var cursor = 0.0
        return clips.map { clip in
            var updated = clip
            let duration = clip.timelineRange.durationSeconds
            updated.timelineRange = ClipTimeRange(startSeconds: cursor, durationSeconds: duration)
            cursor += duration
            return updated
        }
    }
}
