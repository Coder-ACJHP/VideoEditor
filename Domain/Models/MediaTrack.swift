//
// MediaTrack
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  A single lane on the composition timeline.
//  `TrackType` lets the engine pick the correct pipeline:
//  - video / image  →  AVCompositionTrack (video media type)
//  - audio          →  AVCompositionTrack (audio media type)
//  - overlay        →  secondary video track; opacity / blendMode applied in AVVideoComposition instructions.

import Foundation

nonisolated struct MediaTrack: Identifiable, Codable, Sendable {
    
    let id: UUID
    var trackType: TrackType
    var clips: [MediaClip]
    
    /// Audio-only: when true, the engine omits this track from the mix.
    var isMuted: Bool
    
    /// Volume multiplier (0.0 = silent, 1.0 = full level). Meaningful only for `.audio` tracks.
    var volume: Float
    
    enum TrackType: String, Codable {
        /// Primary visual track (video + image clips share this lane).
        case video
        /// Independent audio layer (music, SFX, voice-over).
        case audio
        /// Top layer: PiP, text, graphics, or watermark.
        case overlay
    }
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        trackType: TrackType,
        clips: [MediaClip] = [],
        isMuted: Bool = false,
        volume: Float = 1.0
    ) {
        self.id = id
        self.trackType = trackType
        self.clips = clips
        self.isMuted = isMuted
        self.volume = volume
    }
}

extension MediaTrack: Equatable {}

extension MediaTrack.TrackType {
    var timelineLaneHeight: CGFloat {
        switch self {
            case .video:
                return 60
            case .audio, .overlay:
                return 36
        }
    }
}
