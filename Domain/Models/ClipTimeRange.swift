//
//  ClipTimeRange.swift
//  VideoEditor
//
//  CMTimeRange, Codable-uyumlu değil; bu struct timeline ve source
//  zaman aralıklarını diskte saklamak ve CMTimeRange'e dönüştürmek için kullanılır.
//  Timescale olarak 600 seçildi: hem 24/25/30/60 fps'in ortak katıdır hem de
//  sub-frame hassasiyeti sağlar.

import CoreMedia
import Foundation

struct ClipTimeRange: Codable, Equatable, Hashable {

    var startSeconds: Double
    var durationSeconds: Double

    /// Aralığın bitiş noktası (startSeconds + durationSeconds).
    var endSeconds: Double { startSeconds + durationSeconds }

    /// Swift model'inden AVFoundation'a dönüşüm noktası.
    var cmTimeRange: CMTimeRange {
        CMTimeRange(
            start: CMTime(seconds: startSeconds, preferredTimescale: 600),
            duration: CMTime(seconds: durationSeconds, preferredTimescale: 600)
        )
    }

    // MARK: - Init

    init(startSeconds: Double, durationSeconds: Double) {
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
    }

    /// CMTimeRange'den doğrudan oluşturmak için kolaylık init'i.
    init(cmTimeRange: CMTimeRange) {
        self.startSeconds = cmTimeRange.start.seconds
        self.durationSeconds = cmTimeRange.duration.seconds
    }

    // MARK: - Static Helpers

    static let zero = ClipTimeRange(startSeconds: 0, durationSeconds: 0)
}
