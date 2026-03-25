//
//  ClipTransition.swift
//  VideoEditor
//
//  İki ardışık clip arasındaki geçiş efektini tanımlar.
//  clip[i].transitionOut → clip[i] ile clip[i+1] arasında uygulanır.
//
//  Engine işleyişi:
//  transitionOut != nil  →  iki clip timeline'da `durationSeconds` kadar örtüştürülür
//                           ve AVVideoCompositionInstruction ile geçiş render edilir.
//  transitionOut == nil  →  zero-overlap; hard cut (kesim).

import Foundation

nonisolated struct ClipTransition: Codable, Equatable {

    var type: TransitionType

    /// Her iki clip'in timeline üzerinde örtüşeceği süre (saniye).
    /// Bu değer her iki clip'in de en az bu kadar uzun olmasını gerektirir;
    /// engine, kısa clip'te durationSeconds'ı otomatik olarak kırpar.
    var durationSeconds: Double

    enum TransitionType: String, Codable, CaseIterable {
        /// Çapraz geçirgenlik: başlangıç için en kolay implement edilen tip.
        case crossDissolve
        /// Siyaha fade, ardından yeni clip açılır.
        case fadeToBlack
        /// Yeni clip, mevcut clip'i soldan sağa iterek geçer.
        case push
        /// Yeni clip, mevcut clip'in üzerine kaydırılarak gelir.
        case slide
    }

    // MARK: - Defaults

    /// Varsayılan geçiş: 0.5 saniyelik crossDissolve.
    static let `default` = ClipTransition(type: .crossDissolve, durationSeconds: 0.5)
}
