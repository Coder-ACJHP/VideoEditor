//
//  MediaTrack.swift
//  VideoEditor
//
//  Composition timeline'daki tek bir şerit (lane).
//  TrackType, engine'in doğru pipeline'ı seçmesini sağlar:
//  - video / image  →  AVCompositionTrack (video media type)
//  - audio          →  AVCompositionTrack (audio media type)
//  - overlay        →  ikincil video track; AVVideoComposition instruction'da
//                      opacity / blendMode uygulanır.

import Foundation

nonisolated struct MediaTrack: Identifiable, Codable, Sendable {

    let id: UUID
    var trackType: TrackType
    var clips: [MediaClip]

    /// Ses kanallarına özgü: true olduğunda engine bu track'i mixe katmaz.
    var isMuted: Bool

    /// Ses seviyesi çarpanı (0.0 = sessiz, 1.0 = tam ses).
    /// Yalnızca .audio track'lerde anlam taşır.
    var volume: Float

    enum TrackType: String, Codable {
        /// Birincil video ve fotoğraf parçaları.
        case video
        /// Bağımsız ses katmanı (müzik, ses efekti, dublaj).
        case audio
        /// Üst katman: PiP, metin, grafik veya watermark.
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
