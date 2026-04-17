//
// TimelineArranging
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Master-track timeline geometry lives in Domain — not in UIKit view controllers.
//  Default implementation: `MasterTrackTimelineArranger` (same module).
//

import Foundation

/// Reorders / normalizes clip **timeline** placement for the primary (video) track.
protocol TimelineArranging: Sendable {

    /// Returns clips in the same order with `timelineRange` adjusted so that:
    /// - the first clip starts at `t == 0`;
    /// - each following clip starts exactly where the previous one ends (no gaps; transitions do not shift timeline positions).
    ///
    /// Each clip keeps its current `durationSeconds` and all other fields (`sourceRange`, `transitionOut`, etc.).
    func enforceMasterTrackContiguity(clips: [MediaClip]) -> [MediaClip]
}
