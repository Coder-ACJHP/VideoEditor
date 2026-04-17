//
// TextOverlayTextAlignment
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Text alignment; `.natural` follows the system line direction for RTL languages such as Arabic.
//  Mapping to UIKit / Core Animation lives in `TextOverlayRenderingService`.

import Foundation

nonisolated enum TextOverlayTextAlignment: String, Codable, Hashable, Sendable, CaseIterable {
    case natural
    case left
    case center
    case right
}
