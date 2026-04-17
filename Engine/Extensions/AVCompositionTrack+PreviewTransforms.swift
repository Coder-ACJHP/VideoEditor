//
// AVCompositionTrack+PreviewTransforms
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Associated dictionary storing per-segment `preferredTransform` when multiple timeline segments
//  share one physical composition track (matches video-composition instruction data).
//

import AVFoundation
import CoreGraphics
import Foundation
import ObjectiveC
import UIKit

extension AVCompositionTrack {

    private static var previewTransformStorageKey: UInt8 = 0

    private var previewTransformStorage: NSMutableDictionary {
        if let existing = objc_getAssociatedObject(self, &Self.previewTransformStorageKey) as? NSMutableDictionary {
            return existing
        }
        let dictionary = NSMutableDictionary()
        objc_setAssociatedObject(
            self,
            &Self.previewTransformStorageKey,
            dictionary,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return dictionary
    }

    func storedPreferredTransform(forKey key: String) -> CGAffineTransform? {
        guard let value = previewTransformStorage[key] as? NSValue else { return nil }
        return value.cgAffineTransformValue
    }

    func setStoredPreferredTransform(_ transform: CGAffineTransform, forKey key: String) {
        previewTransformStorage[key] = NSValue(cgAffineTransform: transform)
    }
}
