//
//  TimelineLayoutProvider.swift
//  VideoEditor
//
//  Single place for horizontal time ↔ points mapping. Changing `pointsPerSecond`
//  (e.g. timeline zoom) updates all derived layout without scattered * / math.
//

import CoreGraphics
import CoreMedia

struct TimelineLayoutProvider: Equatable, Sendable {

    /// Horizontal scale: how many points represent one second (same as legacy `pixelsPerSecond`).
    let pointsPerSecond: CGFloat

    init(pointsPerSecond: CGFloat) {
        self.pointsPerSecond = max(pointsPerSecond, .leastNonzeroMagnitude)
    }

    // MARK: - Time → position / width

    func xPosition(forSeconds seconds: Double) -> CGFloat {
        CGFloat(seconds) * pointsPerSecond
    }

    func xPosition(for time: CMTime) -> CGFloat {
        xPosition(forSeconds: time.seconds)
    }

    /// Clip width in points for a duration in seconds.
    func width(forDurationSeconds seconds: Double) -> CGFloat {
        xPosition(forSeconds: seconds)
    }

    // MARK: - Position → time

    func seconds(forXPosition x: CGFloat) -> Double {
        Double(x / pointsPerSecond)
    }

    func time(forXPosition x: CGFloat) -> CMTime {
        CMTime(seconds: seconds(forXPosition: x), preferredTimescale: 600)
    }

    /// Visible timeline duration (seconds) for a content width in points.
    func durationSeconds(forContentWidth width: CGFloat) -> Double {
        seconds(forXPosition: width)
    }
}

extension TimelineConfiguration {

    /// Layout math for the current horizontal zoom / scale.
    var timelineLayout: TimelineLayoutProvider {
        TimelineLayoutProvider(pointsPerSecond: pixelsPerSecond)
    }
}
