//
// CMTimeRange+PreviewComposition
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Split / merge time ranges for multi-layer `AVVideoComposition` instructions.
//  Breaks overlapping clip ranges into disjoint slices (similar to a `calculateSlices` pass).
//

import CoreMedia

extension CMTimeRange {

    /// Stable key for mapping `preferredTransform` per segment on the same composition track.
    var transformStorageKey: String {
        "{\(String(format: "%.3f", start.seconds)), \(String(format: "%.3f", duration.seconds))}"
    }

    /// Whether `inner` lies fully inside this range.
    func containsTimeRangeFully(_ inner: CMTimeRange) -> Bool {
        CMTimeRangeContainsTimeRange(self, otherRange: inner)
    }

    /// Removes the intersection with `timeRange` and returns the remaining sub-ranges (may be empty).
    func rangesAfterRemoving(_ timeRange: CMTimeRange) -> [CMTimeRange] {
        let intersectionTimeRange = self.intersection(timeRange)
        guard intersectionTimeRange.duration.seconds > 0 else { return [self] }
        var ranges: [CMTimeRange] = []
        let left = CMTimeRange(start: start, end: intersectionTimeRange.start)
        if left.duration.seconds > 0 { ranges.append(left) }
        let right = CMTimeRange(start: intersectionTimeRange.end, end: end)
        if right.duration.seconds > 0 { ranges.append(right) }
        return ranges
    }

    /// Splits two overlapping timeline ranges into non-overlapping pieces for layered video instructions.
    static func splitPairForOverlappingInstructions(_ a: CMTimeRange, _ b: CMTimeRange) -> [CMTimeRange] {
        let intersection = a.intersection(b)
        guard intersection.duration.seconds > 0 else {
            return [a, b]
        }
        if b.containsTimeRangeFully(a)
            || (CMTimeCompare(a.start, b.start) < 0 && CMTimeCompare(a.end, b.end) < 0) {
            return mixRanges(minRange: a, intersection: intersection, maxRange: b)
        }
        return mixRanges(minRange: b, intersection: intersection, maxRange: a)
    }

    private static func mixRanges(
        minRange: CMTimeRange,
        intersection: CMTimeRange,
        maxRange: CMTimeRange
    ) -> [CMTimeRange] {
        if maxRange.containsTimeRangeFully(minRange) {
            var ranges: [CMTimeRange] = []
            let leftDur = CMTimeSubtract(intersection.start, maxRange.start)
            if leftDur.seconds > 0 {
                ranges.append(CMTimeRange(start: maxRange.start, duration: leftDur))
            }
            ranges.append(intersection)
            let rightDur = CMTimeSubtract(maxRange.end, intersection.end)
            if rightDur.seconds > 0 {
                ranges.append(CMTimeRange(start: intersection.end, duration: rightDur))
            }
            return ranges
        }
        if minRange == maxRange { return [intersection] }

        var ranges: [CMTimeRange] = []
        let d1 = CMTimeSubtract(minRange.duration, intersection.duration)
        let tr1 = CMTimeRange(start: minRange.start, duration: d1)
        if tr1.duration.seconds > 0 { ranges.append(tr1) }
        ranges.append(intersection)
        let d2 = CMTimeSubtract(maxRange.end, intersection.end)
        let tr2 = CMTimeRange(start: intersection.end, duration: d2)
        if tr2.duration.seconds > 0 { ranges.append(tr2) }
        return ranges
    }
}
