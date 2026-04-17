//
// ClipTimeRange
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  `CMTimeRange` is not Codable; this struct stores timeline and source ranges on disk
//  and converts to/from `CMTimeRange`.
//  Timescale 600 is a common multiple of 24/25/30/60 fps and gives sub-frame precision.

import CoreMedia
import Foundation

nonisolated struct ClipTimeRange: Codable, Equatable, Hashable, Sendable {

    var startSeconds: Double
    var durationSeconds: Double

    /// End of the range (`startSeconds + durationSeconds`).
    var endSeconds: Double { startSeconds + durationSeconds }

    /// Bridge from the Swift model to AVFoundation.
    var cmTimeRange: CMTimeRange {
        CMTimeRange(
            start: CMTime(seconds: startSeconds, preferredTimescale: 600),
            duration: CMTime(seconds: durationSeconds, preferredTimescale: 600)
        )
    }

    // MARK: - Init

    init(startSeconds: Double, durationSeconds: Double) {
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
    }

    /// Convenience initializer from `CMTimeRange`.
    init(cmTimeRange: CMTimeRange) {
        self.startSeconds = cmTimeRange.start.seconds
        self.durationSeconds = cmTimeRange.duration.seconds
    }

    // MARK: - Static Helpers

    static let zero = ClipTimeRange(startSeconds: 0, durationSeconds: 0)
}
