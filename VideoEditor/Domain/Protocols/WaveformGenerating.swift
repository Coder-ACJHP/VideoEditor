//
// WaveformGenerating
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import Foundation
import UIKit

protocol WaveformGenerating: AnyObject, Sendable {
    func waveform(for asset: AssetIdentifier, size: CGSize) async -> UIImage?
    func displayName(for asset: MediaClip) -> String
}
