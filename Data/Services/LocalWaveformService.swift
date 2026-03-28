//
//  LocalWaveformService.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 28.03.2026.
//

import Foundation
import UIKit

final class LocalWaveformService: WaveformGenerating {
    
    func waveform(for asset: AssetIdentifier, size: CGSize) async -> UIImage? {
        nil
    }
    
    func stableWaveformSeed(for id: UUID) -> UInt64 {
        withUnsafePointer(to: id.uuid) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 16) { bytes in
                var s: UInt64 = 1469598103934665603 // FNV offset
                for i in 0..<16 {
                    s ^= UInt64(bytes[i])
                    s &*= 1099511628211
                }
                return s
            }
        }
    }

    /// Waveform fill: visibly darker than the clip background tint.
    func waveformColor(on background: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard background.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return UIColor.black.withAlphaComponent(0.45)
        }
        let factor: CGFloat = 0.42
        return UIColor(
            red: max(r * factor, 0),
            green: max(g * factor, 0),
            blue: max(b * factor, 0),
            alpha: min(a + 0.2, 1)
        )
    }
    
    func displayName(for clip: MediaClip) -> String {
        switch clip.asset {
            case .audio(let url):
                let title = url.deletingPathExtension().lastPathComponent
                let duration = clip.timelineRange.durationSeconds.rounded()
                let name = "\(title) - \(TimelineClockFormatter.string(fromSeconds: duration))"
                return name.isEmpty ? String(localized: "Audio") : name
            default:
                return String(localized: "Audio")
        }
    }
    
}
