//
// TimelineClockFormatter
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Presentation-friendly mm:ss strings for toolbar / clip labels.
//

import Foundation

enum TimelineClockFormatter {

    /// Whole seconds, clamped at zero — matches legacy editor toolbar formatting.
    static func string(fromSeconds seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
