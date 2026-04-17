//
// SpeedEffect
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Playback speed multiplier for a clip.
//
//  Engine behavior:
//  - When rate != 1.0, timelineRange and sourceRange diverge by design: sourceRange stays fixed
//    while timelineRange is recomputed as (sourceRange.duration / rate).
//  - In AVFoundation this is expressed with AVCompositionTrackSegment.timeMapping.
//
//  Examples:
//  - rate = 0.5 → 4s of source occupies 8s on the timeline (slow motion).
//  - rate = 2.0 → 4s of source occupies 2s on the timeline (fast motion).

import Foundation

nonisolated struct SpeedEffect: Codable, Equatable {

    /// Playback rate multiplier. Typical range: 0.1 ... 4.0
    /// e.g. 0.25 = quarter speed, 1.0 = normal, 2.0 = double speed.
    var rate: Float

    static let normal = SpeedEffect(rate: 1.0)
}
