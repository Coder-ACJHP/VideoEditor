//
//  TransformEffect.swift
//  VideoEditor
//
//  Clip'in geometrik dönüşümü: ölçek, döndürme ve taşıma.
//  Engine bu değerleri CGAffineTransform veya AVVideoCompositionLayerInstruction
//  transform'una dönüştürür.

import CoreGraphics
import Foundation

struct TransformEffect: Codable, Equatable {

    /// Ölçek çarpanı. 1.0 = orijinal boyut, 2.0 = 2x büyütülmüş.
    var scale: CGFloat

    /// Döndürme açısı (derece). Pozitif değer = saat yönünde döndürme.
    var rotationDegrees: Double

    /// Yatay kaydırma (point cinsinden, ekran koordinatlarında).
    var translationX: CGFloat

    /// Dikey kaydırma (point cinsinden, ekran koordinatlarında).
    var translationY: CGFloat

    /// Hiçbir dönüştürme uygulanmamış referans değeri.
    static let identity = TransformEffect(
        scale: 1.0,
        rotationDegrees: 0,
        translationX: 0,
        translationY: 0
    )
}
