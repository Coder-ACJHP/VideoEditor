//
//  TextOverlayDescriptor.swift
//  VideoEditor
//
//  Metin overlay'inin düzenlenebilir içeriği (konum/ölçek/dönüşüm `MediaClip.transform`).
//  `fontSize`, 1080p dikey referans çözünürlüğüne göre tanımlanır; preview/export
//  gerçek canvas yüksekliği ile ölçeklenir.

import CoreGraphics
import Foundation

nonisolated struct TextOverlayDescriptor: Codable, Equatable, Hashable, Sendable {

    var text: String
    var fontName: String
    /// Point size at the 1080p-tall reference frame (see `TextOverlayRenderingService`).
    var fontSize: CGFloat
    var textColorHex: String
    var backgroundColorHex: String?

    // MARK: - Codable (CGFloat / iOS 16–safe)

    enum CodingKeys: String, CodingKey {
        case text
        case fontName
        case fontSize
        case textColorHex
        case backgroundColorHex
    }

    init(
        text: String,
        fontName: String,
        fontSize: CGFloat,
        textColorHex: String,
        backgroundColorHex: String? = nil
    ) {
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        fontName = try c.decode(String.self, forKey: .fontName)
        fontSize = CGFloat(try c.decode(Double.self, forKey: .fontSize))
        textColorHex = try c.decode(String.self, forKey: .textColorHex)
        backgroundColorHex = try c.decodeIfPresent(String.self, forKey: .backgroundColorHex)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(text, forKey: .text)
        try c.encode(fontName, forKey: .fontName)
        try c.encode(Double(fontSize), forKey: .fontSize)
        try c.encode(textColorHex, forKey: .textColorHex)
        try c.encodeIfPresent(backgroundColorHex, forKey: .backgroundColorHex)
    }

    /// Varsayılan yeni metin klibi (editor / önizleme).
    static func defaultNew(text: String = "Sample Text") -> TextOverlayDescriptor {
        TextOverlayDescriptor(
            text: text,
            fontName: "HelveticaNeue-Bold",
            fontSize: 48,
            textColorHex: "#FFFFFF",
            backgroundColorHex: nil
        )
    }
}
