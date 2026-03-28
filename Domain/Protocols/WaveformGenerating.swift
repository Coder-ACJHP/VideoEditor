//
//  WaveformGenerating.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 28.03.2026.
//

import Foundation
import UIKit

protocol WaveformGenerating: AnyObject, Sendable {
    func stableWaveformSeed(for id: UUID) -> UInt64
    func waveformColor(on background: UIColor) -> UIColor
    func waveform(for asset: AssetIdentifier, size: CGSize) async -> UIImage?
    func displayName(for asset: MediaClip) -> String
}
