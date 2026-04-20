//
// CGFloat+Extension
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import Foundation
import UIKit

/// Reference layout width (points) the design was authored against.
private let DESIGN_WIDTH: CGFloat = 393.0

extension CGFloat {
    /// Responsive scale from the reference width to the current screen (capped at 500pt).
    var resp: CGFloat {
        let deviceScreenWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.width ?? DESIGN_WIDTH
        // Protect max width with magic number
        let screenWidth = Swift.min(deviceScreenWidth, 500.0)
        return self * (screenWidth / DESIGN_WIDTH)
    }
}

extension Double {
    var resp: CGFloat {
        return CGFloat(self).resp
    }
}

extension Int {
    var resp: CGFloat {
        return CGFloat(self).resp
    }
}
