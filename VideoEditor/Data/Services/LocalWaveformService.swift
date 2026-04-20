//
// LocalWaveformService
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import Foundation
import UIKit

final class LocalWaveformService: WaveformGenerating {

    func waveform(for asset: AssetIdentifier, size: CGSize) async -> UIImage? {
        let drawer = WaveformImageDrawer()
        if case .audio(let audioURL) = asset {
            // Keep waveform tint in the data layer; matches timeline `audioTrackColor` (system purple) without depending on Presentation.
            let color1 = UIColor.systemPurple.darker() ?? .systemPurple
            let color2 = color1.withAlphaComponent(0.35)
            let config = Waveform.Configuration(size: size, style: .gradient([color1, color2]), verticalScalingFactor: 1.0)
            return try? await drawer.waveformImage(fromAudioAt: audioURL, with: config, position: .bottom)
        }
        return nil
    }

    func displayName(for clip: MediaClip) -> String {
        if case .audio(let url) = clip.asset { return url.deletingPathExtension().lastPathComponent }
        return String(localized: "Audio")
    }
}
