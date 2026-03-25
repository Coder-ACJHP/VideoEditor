//
//  SpeedEffect.swift
//  VideoEditor
//
//  Clip oynatma hızı çarpanı.
//
//  Engine işleyişi:
//  - rate != 1.0 olduğunda clip'in timelineRange ile sourceRange bilinten
//    ayrılır: sourceRange sabit tutulurken timelineRange,
//    (sourceRange.duration / rate) formulüyle yeniden hesaplanır.
//  - AVFoundation'da bu, AVCompositionTrackSegment.timeMapping ile ifade edilir.
//
//  Örnek:
//  rate = 0.5  →  4 saniyelik kaynak, 8 saniyelik timeline alanı kaplar (yavaş çekim)
//  rate = 2.0  →  4 saniyelik kaynak, 2 saniyelik timeline alanı kaplar (hızlı çekim)

import Foundation

nonisolated struct SpeedEffect: Codable, Equatable {

    /// Oynatma hız çarpanı.
    /// Geçerli aralık: 0.1 ... 4.0
    /// 0.25 = 4x yavaş çekim, 1.0 = normal hız, 2.0 = 2x hızlı.
    var rate: Float

    static let normal = SpeedEffect(rate: 1.0)
}
