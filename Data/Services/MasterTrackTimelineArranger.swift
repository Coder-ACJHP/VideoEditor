//
//  MasterTrackTimelineArranger.swift
//  VideoEditor
//
//  Pure domain logic for “push” / packed layout after trim, add, or delete on the master track.
//

import Foundation

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
